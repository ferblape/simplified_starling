require 'starling'
require "#{RAILS_ROOT}/vendor/plugins/simplified_starling/init"

namespace :simplified_starling do

  desc "Start starling server"
  task :start do
    unless Simplified::Starling.running?
      starling_binary = `which starling`.strip
      raise RuntimeError, "Cannot find starling" if starling_binary.blank?
      options = []
      options << "--queue_path #{STARLING_CONFIG['queue_path']}"
      options << "--host #{STARLING_CONFIG['host']}"
      options << "--port #{STARLING_CONFIG['port']}"
      options << "-d" if STARLING_CONFIG['daemonize']
      options << "--pid #{STARLING_CONFIG['pid_file']}"
      options << "--syslog #{STARLING_CONFIG['syslog_channel']}" if STARLING_CONFIG['syslog_channel']
      options << "--timeout #{STARLING_CONFIG['timeout']}"
      system "#{starling_binary} #{options.join(' ')}"
      Simplified::Starling.feedback("Starling successfully started")
    else
      Simplified::Starling.feedback("Starling is already running")
    end
  end

  desc "Stop starling server"
  task :stop do
    pid_file = STARLING_CONFIG['pid_file']
    if File.exist?(pid_file)
      system "kill -9 `cat #{pid_file}`"
      Simplified::Starling.feedback("Starling successfully stopped")
      File.delete(pid_file)
    else
      Simplified::Starling.feedback("Starling is not running")
    end
  end

  desc "Restart starling server"
  task :restart do
    pid_file = STARLING_CONFIG['pid_file']
    Rake::Task['simplified_starling:stop'].invoke if File.exist?(pid_file)
    Rake::Task['simplified_starling:start'].invoke
  end

  desc "Start processing jobs (process is daemonized) in all queues (you can indicate a queue withe QUEUE=<queue_name>)"
  task :start_processing_jobs => :environment do
    begin
      config = STARLING_CONFIG
      queues = if ENV['QUEUE']
        [ENV['QUEUE']]
      else
        Simplified::Starling.queues
      end
      queues.each do |queue|
        queue_pid_file = Simplified::Starling.config(queue)['queue_pid_file']
        unless File.exist?(queue_pid_file)
          Simplified::Starling.stats(queue)
          Simplified::Starling.process(queue)
          Simplified::Starling.feedback("Started processing jobs for queue #{queue}")
        else
          Simplified::Starling.feedback("Jobs are already being processed in #{queue}")
        end
      end
    rescue Exception => error
      Simplified::Starling.feedback(error.message)
    end
  end

  desc "Stop processing jobs in all queues (you can indicate a queue withe QUEUE=<queue_name>)"
  task :stop_processing_jobs do
    config = STARLING_CONFIG
    queues = if ENV['QUEUE']
      [ENV['QUEUE']]
    else
      Simplified::Starling.queues
    end
    queues.each do |queue|
      queue_pid_file = Simplified::Starling.config(queue)['queue_pid_file']
      if File.exist?(queue_pid_file)
        system "kill -9 `cat #{queue_pid_file}`"
        Simplified::Starling.feedback("Stopped processing jobs for queue #{queue}")
        File.delete(queue_pid_file)
      else
        Simplified::Starling.feedback("Jobs are not being processed in #{queue}")
      end
    end
  end

  desc "Start starling and process jobs"
  task :start_and_process_jobs do
    Rake::Task['simplified_starling:start'].invoke
    sleep 10
    Rake::Task['simplified_starling:start_processing_jobs'].invoke
  end

  desc "Server stats"
  task :stats do
    begin
      Simplified::Starling.queues.each do |queue|
        queue, items = Simplified::Starling.stats(queue)
        Simplified::Starling.feedback("Queue #{queue} has #{items} jobs")
      end
    rescue Exception => error
      Simplified::Starling.feedback(error.message)
    end
  end

end

namespace :ss do
  desc "Start starling server"
  task :start => "simplified_starling:start"
  desc "Stop starling server"
  task :stop  => "simplified_starling:stop"
  desc "Restart starling server"
  task :restart => "simplified_starling:restart"
  desc "Start processing jobs (process is daemonized) in all queues (you can indicate a queue withe QUEUE=<queue_name>)"
  task :start_processing_jobs => "simplified_starling:start_processing_jobs"
  desc "Start processing jobs (process is daemonized) in all queues (you can indicate a queue withe QUEUE=<queue_name>)"
  task :start_pj => "simplified_starling:start_processing_jobs"
  desc "Stop processing jobs in all queues (you can indicate a queue withe QUEUE=<queue_name>)"
  task :stop_processing_jobs => "simplified_starling:stop_processing_jobs"
  desc "Stop processing jobs in all queues (you can indicate a queue withe QUEUE=<queue_name>)"
  task :stop_pj => "simplified_starling:stop_processing_jobs"
  desc "Start starling and process jobs"
  task :start_and_process_jobs => "simplified_starling:start_and_process_jobs"
  desc "Start starling and process jobs"
  task :start_and_pj => "simplified_starling:start_and_process_jobs"
  desc "Server stats"
  task :stats => "simplified_starling:stats"
end