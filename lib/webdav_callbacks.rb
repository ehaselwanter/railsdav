# This module WebDavCallbacks adds callbacks before and after webdav methods.
# Overidding classes can add methods before and after every webdav method by overriding
# before_webdav_#{method} and after_webdav_#{method}

module Railsdav
  module Webdav
    module Callbacks

      METHODS = [ :get, :put, :copy, :move, :propfind, :proppatch, :mkcol ]

      CALLBACKS = METHODS.map {|action| [ "before_webdav_#{action}", "after_webdav_#{action}" ] }.flatten

      def self.included(base) #:nodoc:
        base.extend(ClassMethods)
        base.class_eval do
          METHODS.each do |method|
            alias_method_chain "webdav_#{method}", :callbacks
          end
        end
      end

      module ClassMethods
      end

      def before_webdav_get; end
      def after_webdav_get; end

      def webdav_get_with_callbacks
        before_webdav_get
        result = webdav_get_without_callbacks
        after_webdav_get
        result
      end
      
      def before_webdav_put; end
      def after_webdav_put; end
      
      def webdav_put_with_callbacks
        before_webdav_put
        result = webdav_put_without_callbacks
        after_webdav_put
        result
      end

      def before_webdav_copy; end
      def after_webdav_copy; end

      def webdav_copy_with_callbacks
        before_webdav_copy
        result = webdav_copy_without_callbacks
        after_webdav_copy
        result
      end 

      def before_webdav_move; end
      def after_webdav_move; end

      def webdav_move_with_callbacks
        before_webdav_move
        result = webdav_move_without_callbacks
        after_webdav_move
        result
      end

      def before_webdav_propfind; end
      def after_webdav_propfind; end

      def webdav_propfind_with_callbacks
        before_webdav_propfind
        result = webdav_propfind_without_callbacks
        after_webdav_propfind
        result
      end

      def before_webdav_proppatch; end
      def after_webdav_proppatch; end

      def webdav_proppatch_with_callbacks
        before_webdav_proppatch
        result = webdav_proppatch_without_callbacks
        after_webdav_proppatch
        result
      end

      def before_webdav_mkcol; end
      def after_webdav_mkcol; end

      def webdav_mkcol_with_callbacks
        before_webdav_mkcol
        result = webdav_mkcol_without_callbacks
        after_webdav_mkcol
        result
      end
    end
  end
end
