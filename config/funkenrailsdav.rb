module Funkenrailsdav

  # Hash containing the users
  mattr_accessor :users

  # Relative path to directory where to store the webdav files (relative to Rails.root)
  mattr_accessor :base_dir
  self.base_dir = 'webdav'
 
end


 