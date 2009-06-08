ActionController::Routing::Routes.draw do |map|

  map.connect '*path_info', :controller  => 'webdav', :action => 'webdav'
  map.root :controller  => 'webdav', :action => 'webdav'

end