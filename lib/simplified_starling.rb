module SimplifiedStarling
  def self.config(queue = nil)
    queue ? STARLING_CONFIG['queues'][queue] : STARLING_CONFIG['queues']
  end
  def self.queues
    self.config.keys.first
  end
  def self.default_queue
    self.queues.first
  end
end

module Simplified

  class Starling

    def self.autoload_missing_constants
      yield
    rescue ArgumentError, MemCache::MemCacheError => error
      lazy_load ||= Hash.new { |hash, key| hash[key] = true; false }
      retry if error.to_s.include?('undefined class') && 
        !lazy_load[error.to_s.split.last.constantize]
      raise error
    end

    def self.running?(queue)
      config = SimplifiedStarling.config(queue)
      if File.exist?(config['queue_pid_file'])
        Process.getpgid(File.read(config['queue_pid_file']).to_i) rescue return false
      else
        return false
      end
    end

    def self.process(queue, daemonize = true)
      config = SimplifiedStarling.config(queue)
      pid = fork do
        Signal.trap('HUP', 'IGNORE') # Don't die upon logout
        loop { pop(queue) }
      end

      if daemonize
        ##
        # Write pid file in pid folder
        #
        File.open(config['queue_pid_file'], "w") do |pid_file|
          pid_file.puts pid
        end

        ##
        # Detach process
        #
        Process.detach(pid)
      end
    end

    def self.pop(queue)
      ActiveRecord::Base.verify_active_connections!
      job = autoload_missing_constants { STARLING.get(queue) }
      args = [job[:task]] + job[:options] # what to send to the object
      if job[:id]
        job[:type].constantize.find(job[:id]).send(*args)
      else
        job[:type].constantize.send(*args)
      end
      STARLING_LOG.info "[#{Time.now.to_s(:db)}] Popped from #{queue} #{job[:task]} on #{job[:type]} #{job[:id]}"
    rescue ActiveRecord::RecordNotFound
      STARLING_LOG.warn "[#{Time.now.to_s(:db)}] WARNING from #{queue} #{job[:type]}##{job[:id]} gone from database."
    rescue Exception => error
      STARLING_LOG.error "[#{Time.now.to_s(:db)}] ERROR #{error.message}"
    end

    def self.stats(queue)
      return queue, STARLING.sizeof(queue)
    end

    def self.feedback(message)
      puts "=> [SIMPLIFIED STARLING] #{message}"
    end
    
  end

end