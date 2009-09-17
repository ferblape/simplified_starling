require 'starling'

begin
  STARLING_CONFIG = YAML.load_file("#{File.dirname(__FILE__)}/../../../../config/starling.yml")[RAILS_ENV] unless defined?(STARLING_CONFIG)
  STARLING_LOG = Logger.new(STARLING_CONFIG['log_file'])
  STARLING = Starling.new("#{STARLING_CONFIG['host']}:#{STARLING_CONFIG['port']}")
end

require 'simplified_starling'
require 'simplified_starling/active_record'