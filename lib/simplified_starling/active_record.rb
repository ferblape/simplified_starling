module SimplifiedStarling
  ##
  # Push record task into the queue
  #
  def push(task, *args)

    ActiveRecord::Base.verify_active_connections! if defined?(ActiveRecord)

    job = {}
    job[:type] = (self.kind_of? Class) ? self.to_s : self.class.to_s
    job[:id] = (self.kind_of? Class) ? nil : self.id
    job[:task] = task
    if args.any? && args.last.is_a?(Hash) && args.last[:queue]
      job[:queue] = args.last.delete(:queue)
      # If the last argument is an empty hash whe should remove it
      args.delete(args.last) if args.last.empty?
    end
    job[:queue] ||= Simplified::Starling.default_queue
    job[:options] = args

    STARLING.set(job[:queue], job)

    STARLING_LOG.info "[#{Time.now.to_s(:db)}] Pushed #{job[:task]} on #{job[:type]} #{job[:id]} in queue #{job[:queue]}"

  rescue Exception => error
    STARLING_LOG.error "[#{Time.now.to_s(:db)}] ERROR #{error.message}"
    raise MemCache::MemCacheError, error.message
  end

  # Define methods push_in_<queue_name>
  Simplified::Starling.queues.each do |queue|
    define_method "push_in_#{queue}".to_sym do |task, *args|
      args << {} unless args.last.is_a?(Hash)
      args.last.merge!(:queue => queue)
      push(task, *args)
    end
  end

end

module SimplifiedStarling

  class ActiveRecord::Base
    include SimplifiedStarling
  end

end

class Class
  include SimplifiedStarling
end

ActiveRecord::Base.send(:include, SimplifiedStarling)