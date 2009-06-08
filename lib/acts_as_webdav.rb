# Copyright (c) 2006 Stuart Eccles
# Released under the MIT License.  See the LICENSE file for more details.
#
# Modified by Marcello Nuccio.
#
# Here is an example configuration:
#
# A model:
#
#   class WebdavResource < Railsdav::FileResource
#   end
#
# A controller:
#
#   class WebDavController < ApplicationController
#     skip_before_filter :verify_authenticity_token
#     acts_as_webdav
#   end
#
# the controller must then have a route like:
#
#   ActionController::Routing::Routes.draw do |map|
#     map.connect 'home/*path_info', :controller  => 'web_dav', :action => 'webdav'
#     map.root :controller  => 'web_dav', :action => 'webdav'
#   end
#
# and you should add webdav methods into config/environments.rb:
#
#   ActionController::ACCEPTED_HTTP_METHODS.merge(%w{propfind mkcol move copy})
#
#
# Add authentication using rails authenticate_with_http_basic method.
#

require 'action_controller'
require 'unicode'

module Railsdav
  module Acts #:nodoc:
    module Webdav #:nodoc:

      ACTIONS = %w(lock unlock options propfind proppatch mkcol delete put copy move)
      VERSIONS = %w(1 2)

      module ActMethods
        def acts_as_webdav(options = {})
          class_inheritable_accessor :dav_actions
          class_inheritable_accessor :dav_versions
          class_inheritable_accessor :resource_model
          
          self.resource_model = options[:resource_model]
          options[:extra_actions]      ||= []
          options[:extra_dav_versions] ||= []
          self.dav_actions = ACTIONS + options[:extra_actions]
          self.dav_versions = VERSIONS + options[:extra_dav_versions]

          include InstanceMethods unless included_modules.include?(InstanceMethods)
          #include Railsdav::Webdav::Callbacks
          #hide_action(*(ACTIONS.map {|method| "webdav_#{method}" }))
        end
      end

      module InstanceMethods
        def webdav
          method = "webdav_#{request.head? ? "head" : request.method}"
          raise UnknownWebDavMethodError unless respond_to?(method, true)
          begin
            set_depth
            set_path_info
            logger.debug "path_info = #{@path_info.inspect}"
            __send__(method)
          rescue BaseError => error
            render :nothing => true, :status => error.http_status
          end
        end

        private
        
        def webdav_options
          response.headers['DAV'] = dav_versions.join(",")
          response.headers['MS-Author-Via'] = "DAV"
          response.headers["Allow"] = dav_actions.map(&:upcase).join(",")
          render :nothing => true, :status => 200
        end

        def webdav_lock
          #TODO implementation for now return a 200 OK
          render :nothing => true, :status => 200
        end

        def webdav_unlock
          #TODO implementation for now return a 200 OK
          render :nothing => true, :status => 200
        end

        PROPFIND_TEMPLATE = File.dirname(__FILE__) + '/../templates/propfind.xml.builder'

        def webdav_propfind
          resource = find_resource_by_path(@path_info)
          raise NotFoundError unless resource
          resources = get_dav_resource_props(resource)

          render(:file => PROPFIND_TEMPLATE, :status => 207, :locals => { :resources => resources.flatten })
        end

        PROPPATCH_TEMPLATE = File.dirname(__FILE__) + '/../templates/proppatch.xml.builder'

        def webdav_proppatch
          resource = find_resource_by_path(@path_info)
          raise NotFoundError unless resource

          begin
            req_xml = REXML::Document.new request.raw_post
          rescue REXML::ParseException
            raise BadRequestBodyError
          end
          ns = { "" => "DAV:" }
          remove_properties = REXML::XPath.match(req_xml, "/propertyupdate/remove/prop/*", ns)
          set_properties = REXML::XPath.match(req_xml, "/propertyupdate/set/prop/*", ns)

          render(:file => PROPPATCH_TEMPLATE, :status => 207,
                 :locals => { :resource => resource,
                              :remove_properties => remove_properties,
                              :set_properties => set_properties })
        end
     
        def webdav_mkcol
          mkcol_for_path(@path_info)
          render :nothing => true, :status => 201
        end
     
        def webdav_delete
          resource = find_resource_by_path(@path_info)
          raise NotFoundError unless resource

          resource.delete!
          render :nothing => true, :status => 204
        end

        def webdav_put
          write_content_to_path(@path_info, request.raw_post)      
          render :nothing => true, :status => 201
        end

        def with_source_and_destination_resources
          begin
            uri = URI.parse(request.env['HTTP_DESTINATION'].chomp('/'))
            raise BadGatewayError if request.host_with_port != "#{uri.host}:#{uri.port}"
            base_path = url_for(:only_path => true, :path_info => "")
            raise ForbiddenError if uri.path !~  /^#{Regexp.escape(base_path)}\//
            logger.debug "destination_path = #{$'.inspect}"
            dest_path = $'
          rescue URI::InvalidURIError
            raise BadGatewayError
          end

          source_resource = find_resource_by_path(@path_info)
          raise NotFoundError unless source_resource
          dest_resource = find_resource_by_path(dest_path)
          raise PreconditionFailsError if dest_resource && !overwrite_destination?
           
          yield(source_resource, dest_path)
          render :nothing => true, :status => (dest_resource ? 204 : 201)
        end

        def webdav_copy
          with_source_and_destination_resources do |source_resource, dest_path|
            copy_to_path(source_resource, dest_path, @depth)
          end
        end

        def webdav_move
          with_source_and_destination_resources do |source_resource, dest_path|
            move_to_path(source_resource, dest_path, @depth)
          end
        end
        
        def webdav_get
          resource = find_resource_by_path(@path_info)
          raise NotFoundError unless resource
          data_to_send = resource.data 
          raise NotFoundError if data_to_send.blank?
          
          # Hack by funkensturm. to allow the root URL to respond to webdav requests
          raise NotFoundError if File.expand_path(data_to_send.path) == File.join(Rails.root, resource.file_options[:base_dir])
          # Hack end
          
          response.headers["Last-Modified"] = resource.getlastmodified
          if data_to_send.kind_of?(File) 
            raise File.expand_path(data_to_send.path)
            send_file File.expand_path(data_to_send.path), :filename => resource.displayname, :stream => true
          else
            send_data data_to_send, :filename => resource.displayname
          end
        end
        
        def webdav_head
          resource = find_resource_by_path(@path_info)
          raise NotFoundError if resource.blank?
          response.headers["Last-Modified"] = resource.getlastmodified
          render :nothing => true, :status => 200
        end

        private

        #
        # These are default implementations
        # If you do not want to implement one of them, dont put
        # the corresponding HTTP method in ACCEPTED_HTTP_METHODS
        #

        def mkcol_for_path(path)
          raise ForbiddenError unless resource_model
          resource_model.mkcol_for_path(path)
        end

        def move_to_path(resource, dest_path, depth)
          raise ForbiddenError unless resource_model
          resource_model.move_to_path(resource, dest_path, depth)
        end

        def write_content_to_path(path, content)
          raise ForbiddenError unless resource_model
          resource_model.write_content_to_path(path, content)
        end

        def copy_to_path(resource, dest_path, depth)
          raise ForbiddenError unless resource_model
          resource_model.copy_to_path(path, content)
        end

        def find_resource_by_path(path)
          raise ForbiddenError unless resource_model
          href = url_for(:only_path => true, :path_info => params[:path_info])
          resource_model.initialize_by_path_and_href(path, href)
        end

        def overwrite_destination?
          request.env['HTTP_OVERWRITE'] == 'T'
        end

        def get_dav_resource_props(resource)
          @depth -= 1
          ret_set = [ resource ]

          ret_set += (resource.children.map do |child|
            get_dav_resource_props(child)
          end) if @depth >= 0 && resource.children

          ret_set
        end

        def set_path_info
          raise ForbiddenError if params[:path_info].nil?
          logger.debug "params[:path_info] = #{params[:path_info].inspect}"
          path = params[:path_info].join('/')
          @path_info = case request.env["HTTP_USER_AGENT"]
          when /Microsoft|Windows/
            logger.info("CONVERTED: " + Iconv.iconv('UTF-8', 'latin1', URI.unescape(path)).first)
            Iconv.iconv('UTF-8', 'latin1', URI.unescape(path)).first
          when /cadaver/
            URI.unescape(URI.unescape(path))
          else
            URI.unescape(path)
          end
        end

        def set_depth
          depth_header = request.env['HTTP_DEPTH'] 
          @depth = depth_header == 'infinity' ? 50 : (Integer(depth_header || 1) rescue 1)
        end
      end
    end
  end
end
