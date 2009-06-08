# Load libraries
plugin_path = File.dirname __FILE__
require File.join(plugin_path, 'config', 'funkenrailsdav.rb')
require 'railsdav'

ActionController::Base.send(:extend, Railsdav::Acts::Webdav::ActMethods)

# We will be so brash and rename the standard index.html to index_backup.html, because it's most likely not needed
indexfile = File.join(Rails.root, 'public', 'index.html')
backupfile = File.join(Rails.root, 'public', 'index_backup.html')
File.rename indexfile, backupfile  if File.exists? indexfile

# Load list of users
Funkenrailsdav.users = YAML::load_file File.join(plugin_path, 'config', 'users.yml')

# Create a directory for every user
FileUtils.mkdir_p(Funkenrailsdav.base_dir) unless File.exist?(Funkenrailsdav.base_dir) 
Funkenrailsdav.users.each_key do |user|
  path = File.join(Funkenrailsdav.base_dir, user)
  FileUtils.mkdir_p(path) unless File.exist? path 
end
