# Copyright (c) 2006 Stuart Eccles
# Released under the MIT License.  See the LICENSE file for more details.

# The base_dir parameter can be a string for a directory or a symbol for a method which is run for every 
# request allowing the base directory to be changed based on the request
#
# If the parameter :absolute = true the :base_dir setting will be treated as an absolute path, otherwise 
# the it will be taken as a directory underneath the RAILS_ROOT
#

require 'shared-mime-info'

module Railsdav
  class FileResource
    include Resource

    @@logger = Logger.new(STDOUT)

    WEBDAV_PROPERTIES = [ :displayname, :creationdate, :getlastmodified,
                          :getetag, :getcontenttype, :getcontentlength ]

    class_inheritable_accessor :file_options

    self.file_options = {
      :base_dir => Funkenrailsdav.base_dir,
      :base_url => '',
      :absolute_path => false,
      :max_propfind_depth => 1
    }

    def initialize(*args)
      @file = args.first
      FileResource.do_file_action do
        @stat = File.lstat(@file)
      end
      
      if args.last.is_a?(String)
        @href = args.last
        @href = File.join(@href, '') if collection?
      end
    end

    def self.initialize_by_path_and_href(path, href)
      abs_file_path = sanitized_path(path)           
      do_file_action do
        new(abs_file_path, href) if File.exists?(abs_file_path)
      end
    end

    def collection?
      @stat.directory?
    end

    def delete!
      self.class.do_file_action do
        FileUtils.rm_r(@file)
      end
    end

    def move!(dest_path, depth)
      self.class.do_file_action do
        File.rename(@file, dest_path)
      end
    end

    def copy!(dest_path, depth)
      self.class.do_file_action do
        FileUtils.cp_r(@file, dest_path, :preserve => true)
      end
    end

    def children
     resources = []
     Dir.foreach(@file) do |entry|
       resources << self.class.new(File.join(@file, entry), File.join(@href, entry)) if entry != '..' && entry != '.'
     end if collection?
     resources
    end

    def properties
      props = {}
      WEBDAV_PROPERTIES.each do |method|
        props[method] = send(method) if respond_to?(method)
      end
      props
    end 

    def displayname 
      File.basename(@file)
    end

    def creationdate
      @stat.ctime.xmlschema
    end

    def getlastmodified
      @stat.mtime.httpdate
    end

    def getetag
      sprintf('%x-%x-%x', @stat.ino, @stat.size, @stat.mtime.to_i)
    end

    def getcontenttype
      if collection?
        "httpd/unix-directory"
      else
        mimetype = MIME.check_globs(displayname).to_s
        mimetype.blank? ? "application/octet-stream" : mimetype
      end
    end

    def getcontentlength 
      collection? ? nil : @stat.size
    end

    def data
      File.new(@file)
    end

    def self.mkcol_for_path(path)
      check_for_missing_intermediate(path)
      file_path = sanitized_path(path)
      do_file_action do
        Dir.mkdir(file_path)
      end
    end 

    def self.write_content_to_path(path, content)    
      file_path = sanitized_path(path)  
      do_file_action do
        File.open(file_path, "wb") {|f| f.write(content) }
      end
    end

    def self.copy_to_path(resource, dest_path, depth)
      check_for_missing_intermediate(dest_path)
      dest_file_path = sanitized_path(dest_path)
      resource.copy!(dest_file_path, depth)
    end

    def self.move_to_path(resource, dest_path, depth)
      check_for_missing_intermediate(dest_path)
      dest_file_path = sanitized_path(dest_path)
      resource.move!(dest_file_path, depth)
    end

    def self.check_for_missing_intermediate(path)
      raise TODO409Error unless File.exists?(sanitized_path(File.dirname(path)))
    end

    def self.sanitized_path(file_path = '/')
      if file_path =~ %r{\A(.+/)?http:/?/.+/#{file_options[:base_url]}/(\1?.+)\z}
        file_path = $2
      end
      # TODO more work on the santized
      file_root = file_options[:base_dir].is_a?(Symbol) ? send(file_options[:base_dir]) : file_options[:base_dir]
      file_root = File.join(Rails.root, file_root) unless file_options[:absolute_path]
      path = File.expand_path(File.join(file_root, file_path))

      # Deny paths that dont include the original path
      raise ForbiddenError unless path =~ /\A#{File.expand_path(file_root)}/ 

      path
    end

    def self.do_file_action
      begin
        yield
      rescue Errno::ENOENT, Errno::EEXIST
        raise ConflictError
      rescue Errno::EPERM, Errno::EACCES
        raise ForbiddenError
      rescue Errno::ENOSPC
        raise InsufficientStorageError
      end
    end
  end
end
