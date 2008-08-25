require 'fileutils'

starling_plugin_folder = Dir.getwd + "/vendor/plugins/simplified_starling"
starling_config = Dir.getwd + "/config/starling.yml"
unless File.exist?(starling_config)
  FileUtils.cp starling_plugin_folder + "/files/starling.yml.tpl", starling_config
  puts "=> Copied starling configuration file."
else
  puts "=> Starling configuration file already exists."
end