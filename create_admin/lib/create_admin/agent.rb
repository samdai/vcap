require 'rubygems'
require 'json/pure'
require 'eventmachine'

require "create_admin/log"
require "create_admin/admin_instance"
require "common/pid_file"

Dir[File.dirname(__FILE__) + '/../jobs/*.rb'].each do |file| 
  require file
end

module CreateAdmin
  JOBS = {
    'upgrade' => 'Jobs::UpgradeJob',
    'backup' => 'Jobs::BackupJob',
    'dns_update' => 'Jobs::DNSUpdateJob',
    'update_license' => 'Jobs::UpdateLicenseJob',
    'ip_map' => 'Jobs::IPMapJob',
    'full_backup' => 'Jobs::FullBackupJob',
    'restore' => 'Jobs::RestoreJob',
    'full_restore' => 'Jobs::FullRestoreJob',
    'status' => 'Jobs::StatusJob'
  }
  
  def self.instance
    ::CreateAdmin::Log.info("go to get the instance right now.....")
    ::CreateAdmin::AdminInstance.instance
  end

  class Agent
  end
  class ConnectionHandler < EM::Connection
  end
end

class ::CreateAdmin::Agent
  include ::CreateAdmin::Log
  
  def initialize(options)
    @options = options

    begin
      pid_file = PidFile.new(@options['pid'])
      pid_file.unlink_at_exit
    rescue => e
      error "ERROR: Can't create create_admin pid file #{@options['pid']}"
      exit 1
    end

    start_server()
  end

  def start_server()
    port = @options['port'] || 58080
    EM.run do    
      EM.start_server('0.0.0.0', port, ::CreateAdmin::ConnectionHandler){|dispather|
        dispather.options = @options
      }
    end
  end
end

class ::CreateAdmin::ConnectionHandler
  include ::CreateAdmin::Log

  attr_accessor :options
  attr_reader :closed
  
  def initialize
    @closed = false
  end

  def receive_data(command)
    command.strip!

    info("Command is  >>>  #{command}")

    job = parse(command)
    if job.nil?
      error("Failed to parse the command: #{command}")
      close("Failed to parse the command: #{command}")
      return
    end

    job.requester = self
    job.admin_instance = CreateAdmin.instance
    job.run()
  rescue => e
    error("Failed to execute command #{command}")
    error(e)
    close("Failed to execute command #{command}, message: #{e.message}")
  end

  def message(status)
    send_data(status)
  end
  
  def close(message)    
    return if @closed
    @closed = true

    EM.next_tick do
      send_data(message)
      close_connection_after_writing
    end
  end
  
  private
  def parse(command)
    job_type, paras = command.split(':', 2)
    job = CreateAdmin::JOBS[job_type]
    return if job.nil?

    klass = job.split('::').inject(Object) {|o,c| o.const_get c}
    parsed_paras = if paras.nil? || paras.empty?
      nil
    else
      begin
        JSON.parse(paras)
      rescue
        nil
      end
    end

    klass.new(parsed_paras)
  end

end