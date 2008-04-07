require 'railsdav'

ActionController::Base.send(:extend, Railsdav::Acts::Webdav::ActMethods)
