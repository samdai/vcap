maintainer       "VMWare"
maintainer_email "support@vmware.com"
license          "Apache 2.0"
description      "Installs/Configures DEA"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.0.1"
depends "ruby"
depends "cloudfoundry"
depends "deployment"

# not sure if we can write some ruby in here so we know what recipes we actually depend on.
depends "java"
depends "erlang"
depends "nodejs"
depends "php"
