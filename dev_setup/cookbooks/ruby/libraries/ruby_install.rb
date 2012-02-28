module RubyInstall
  def cf_ruby_install(ruby_version, ruby_source, ruby_path)
    rubygems_version = node[:rubygems][:version]
    bundler_version = node[:rubygems][:bundler][:version]
    rake_version = node[:rubygems][:rake][:version]
    ubuntu_version=`lsb_release -sr`
    if ubuntu_version =~ /^10\./
      package "libreadline5-dev"
    else
      package "libreadline6-dev"
      package "libffi-dev"
    end

    %w[ build-essential libssl-dev zlib1g-dev libxml2-dev libpq-dev].each do |pkg|
      package pkg
    end

    remote_file File.join("", "tmp", "ruby-#{ruby_version}.tar.gz") do
      retries 4
      owner node[:deployment][:user]
      source ruby_source
      not_if { ::File.exists?(File.join("", "tmp", "ruby-#{ruby_version}.tar.gz")) }
    end

    directory ruby_path do
      owner node[:deployment][:user]
      group node[:deployment][:group]
      mode "0755"
      recursive true
      action :create
    end

    bash "Install Ruby #{ruby_path}" do
      cwd File.join("", "tmp")
      #user node[:deployment][:user] #does not work: CHEF-2288
      code <<-EOH
      sudo -i -u #{node[:deployment][:user]}
      if [ ! -d "ruby-#{ruby_version}" ]; then
        echo "Unzipping the ruby-#{ruby_version}"
        tar xzf ruby-#{ruby_version}.tar.gz
      fi
      cd ruby-#{ruby_version}
      # disable SSLv2: it is not present in modern linux distrib as it is insecure.
      sed -e -i 's/^[[:space:]]*OSSL_SSL_METHOD_ENTRY(SSLv2)/\/\/    OSSL_SSL_METHOD_ENTRY(SSLv2)/g' ext/openssl/ossl_ssl.c
      sed -e -i 's/^[[:space:]]*OSSL_SSL_METHOD_ENTRY(SSLv2_/\/\/    OSSL_SSL_METHOD_ENTRY(SSLv2_/g' ext/openssl/ossl_ssl.c
      ./configure --disable-pthread --prefix=#{ruby_path}
      make
      make install
      EOH
      not_if do
        ::File.exists?(File.join(ruby_path, "bin", "ruby"))
      end
    end

    remote_file File.join("", "tmp", "rubygems-#{rubygems_version}.tgz") do
      owner node[:deployment][:user]
      source "http://production.cf.rubygems.org/rubygems/rubygems-#{rubygems_version}.tgz"
      not_if { ::File.exists?(File.join("", "tmp", "rubygems-#{rubygems_version}.tgz")) }
    end

    bash "Install RubyGems #{ruby_path}" do
      cwd File.join("", "tmp")
      #user node[:deployment][:user] #does not work: CHEF-2288
      code <<-EOH
      sudo -i -u #{node[:deployment][:user]}
      tar xzf rubygems-#{rubygems_version}.tgz
      cd rubygems-#{rubygems_version}
      #{File.join(ruby_path, "bin", "ruby")} setup.rb
      EOH
      not_if do
        ::File.exists?(File.join(ruby_path, "bin", "gem")) &&
            system("#{File.join(ruby_path, "bin", "gem")} -v | grep -q '#{rubygems_version}$'")
      end
    end

    gem_package "bundler" do
      retries 4
      version bundler_version
      gem_binary File.join(ruby_path, "bin", "gem")
    end

    gem_package "rake" do
      retries 4
      version rake_version
      gem_binary File.join(ruby_path, "bin", "gem")
    end

    # The default chef installed with Ubuntu 10.04 does not support the "retries" option
    # for gem_package. It may be a good idea to add/use that option once the ubuntu
    # chef package gets updated.
    %w[ rack eventmachine thin sinatra mysql pg vmc ].each do |gem|
      gem_package gem do
        retries 4
        gem_binary File.join(ruby_path, "bin", "gem")
      end
    end
  end
end

class Chef::Recipe
  include RubyInstall
end

