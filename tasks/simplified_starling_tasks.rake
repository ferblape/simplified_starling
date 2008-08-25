require 'starling'
require "#{RAILS_ROOT}/vendor/plugins/simplified_starling/lib/simplified_starling"

namespace :simplified_starling do

  desc "Start starling server"
  task :start do
    config = YAML.load_file("#{RAILS_ROOT}/config/starling.yml")[RAILS_ENV]
    unless File.exist?(config['pid_file'])
      starling_binary = `which starling`.strip
      raise RuntimeError, "Cannot find starling" if starling_binary.blank?
      options = []
      options << "--queue_path #{config['queue_path']}"
      options << "--host #{config['host']}"
      options << "--port #{config['port']}"
      options << "-d" if config['daemonize']
      options << "--pid #{config['pid_file']}"
      options << "--syslog #{config['syslog_channel']}"
      options << "--timeout #{config['timeout']}"
      system "#{starling_binary} #{options.join(' ')}"
      Simplified::Starling.feedback("Starling successfully started")
    else
      Simplified::Starling.feedback("Starling is already running")
    end
  end

  desc "Stop starling server"
  task :stop do
    config = YAML.load_file("#{RAILS_ROOT}/config/starling.yml")[RAILS_ENV]
    pid_file = config['pid_file']
    if File.exist?(pid_file)
      system "kill -9 `cat #{pid_file}`"
      Simplified::Starling.feedback("Starling successfully stopped")
      File.delete(pid_file)
    else
      Simplified::Starling.feedback("Starling is not running")
    end
    puts pid_file
  end

  desc "Restart starling server"
  task :restart do
    config = YAML.load_file("#{RAILS_ROOT}/config/starling.yml")
    pid_file = config['pid_file']
    Rake::Task['simplified:starling:stop'].invoke if File.exist?(pid_file)
    Rake::Task['simplified:starling:start'].invoke
  end

  desc "Start processing jobs (process is daemonized)"
  task :start_processing_jobs => :environment do
    begin
      config = YAML.load_file("#{RAILS_ROOT}/config/starling.yml")[RAILS_ENV]
      pid_file = "#{RAILS_ROOT}/tmp/pids/starling_#{RAILS_ENV}.pid"
      unless File.exist?(pid_file)
        Simplified::Starling.stats
        Simplified::Starling.process(config['queue'])
        Simplified::Starling.feedback("Started processing jobs")
      else
        Simplified::Starling.feedback("Jobs are already being processed")
      end
    rescue Exception => error
      Simplified::Starling.feedback(error.message)
    end
  end

  desc "Stop processing jobs"
  task :stop_processing_jobs do
    pid_file = "#{RAILS_ROOT}/tmp/pids/starling_#{RAILS_ENV}.pid"
    if File.exist?(pid_file)
      system "kill -9 `cat #{pid_file}`"
      Simplified::Starling.feedback("Stopped processing jobs")
      File.delete(pid_file)
    else
      Simplified::Starling.feedback("Jobs are not being processed")
    end
  end

  desc "Start starling and process jobs"
  task :start_and_process_jobs do
    Rake::Task['simplified:starling:start'].invoke
    sleep 10
    Rake::Task['simplified:starling:start_processing_queue'].invoke
  end

  desc "Server stats"
  task :stats do
    begin
      queue, items = Simplified::Starling.stats
      Simplified::Starling.feedback("Queue has #{items} jobs")
    rescue Exception => error
      Simplified::Starling.feedback(error.message)
    end
  end

  desc "Copy config files to config/starling/*"
  task :setup do
    Simplified::Starling.setup
  end

end