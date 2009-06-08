class WebdavController < ApplicationController

  acts_as_webdav :resource_model => Webdav

  before_filter :authenticate

  def authenticate
    request.inspect # Don't ask. It just has to be here to make the authentication work and I don't understand why.
    authenticate_or_request_with_http_basic { |username, password|  
      if Funkenrailsdav.users.has_key?(username) and password == Funkenrailsdav.users[username] 
        return true
      else
        render :text => 'All my base are not belong to you.', :status => 401 and return 
      end
    }
  end

end
