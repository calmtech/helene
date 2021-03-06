module Helene
  module S3
    class Object
      class << Object
        MetaHeader = 'x-amz-meta' unless defined?(MetaHeader)
        MetaHeaderPrefix = MetaHeader + '-' unless defined?(MetaHeaderPrefix)
        ACLHeader = 'x-amz-acl' unless defined?(ACLHeader)

        def partition_into_meta_headers(headers) #:nodoc:
          hash = headers.dup
          meta = {}
          hash.each do |key, value|
            if key[%r/^#{ MetaHeaderPrefix }/]
              meta[key.gsub(MetaHeaderPrefix, '')] = value
              hash.delete(key)
            end
          end
          [hash, meta]
        end

        def meta_prefixed(meta_headers, prefix=MetaHeaderPrefix)
          meta = {}
          meta_headers.each do |meta_header, value|
            if meta_header[%r/#{prefix}/]
              meta[meta_header] = value
            else
              meta["#{ MetaHeaderPrefix }#{meta_header}"] = value
            end
          end
          meta
        end
      end

      attr_accessor :bucket
      attr_accessor :key
      attr_accessor :last_modified
      attr_accessor :e_tag
      attr_accessor :size
      attr_accessor :storage_class
      attr_accessor :owner
      attr_accessor :headers
      attr_accessor :meta_headers
      attr_writer   :data
      
      # def initialize(bucket, name, data=nil, headers={}, meta_headers={}, last_modified=nil, e_tag=nil, size=nil, storage_class=nil, owner=nil)

      def initialize(*args)
        options = args.extract_options!.to_options!
        @bucket = args.shift || options[:bucket] 
        @key = args.shift || options[:key] || options[:name]
        @data = args.shift || options[:data]

        @e_tag         = options[:e_tag]
        @storage_class = options[:storage_class]
        @owner         = options[:owner]
        @last_modified = options[:last_modified]
        @size          = options[:size]
        @headers       = options[:headers]||{}
        @meta_headers  = options[:meta_headers]||options[:meta]||{}

        @key = Key.for(@key)
         
        if @last_modified && !@last_modified.is_a?(Time) 
          @last_modified = Time.parse(@last_modified)
        end

        @size = Float(@size).to_i unless @size.nil?

        @headers, meta_headers = Object.partition_into_meta_headers(@headers)

        @meta_headers.merge!(meta_headers)
      end

      def url(*args)
        options = args.extract_options!.to_options!
        options.to_options!
        expires = options.delete(:expires) || 24.hours
        headers = options.delete(:headers) || {}
        case args.shift.to_s
          when '', 'get'
            bucket.interface.get_link(bucket, key, expires, headers)
        end
      end
      alias_method :url_for, :url
      
      def to_s
        @key.to_s
      end
      alias_method 'name', 'to_s'
      
      def data
        get if !@data and exists?
        @data
      end
      
      def get(headers={})
        response = @bucket.interface.get(@bucket.name, @key, headers)
        @data    = response[:object]
        @headers, @meta_headers = Object.partition_into_meta_headers(response[:headers])
        refresh(false)
        self
      end
      
      def put(data=nil, perms=nil, headers={})
        headers[ACLHeader] = perms if perms
        @data = data || @data
        meta  = Object.meta_prefixed(@meta_headers)
        @bucket.interface.put(@bucket.name, @key, @data, meta.merge(headers))
      end
      
      def rename(new_name)
        @bucket.interface.rename(@bucket.name, @key, new_name)
        @key = Key.for(new_name)
      end
      
      def copy(new_key_or_name)
        new_key_or_name = Object.create(@bucket, new_key_or_name.to_s) unless new_key_or_name.is_a?(Object)
        @bucket.interface.copy(@bucket.name, @key, new_key_or_name.bucket.name, new_key_or_name.name)
        Key.for(new_key_or_name)
      end

      def move(new_key_or_name)
        new_key_or_name = Object.create(@bucket, new_key_or_name.to_s) unless new_key_or_name.is_a?(Object)
        @bucket.interface.move(@bucket.name, @name, new_key_or_name.bucket.name, new_key_or_name.name)
        Key.for(new_key_or_name)
      end
      
      def refresh(head=true)
        new_key        = @bucket.find_or_create_object_by_absolute_path(key)
        @last_modified = new_key.last_modified
        @e_tag         = new_key.e_tag
        @size          = new_key.size
        @storage_class = new_key.storage_class
        @owner         = new_key.owner
        if @last_modified
          self.head
          true
        else
          @headers = @meta_headers = {}
          false
        end
      end

      def head
        @headers, @meta_headers = Object.partition_into_meta_headers(@bucket.interface.head(@bucket, @key))
        true
      end
      
      def reload_meta
        @meta_headers = Object.partition_into_meta_headers(@bucket.interface.head(@bucket, @key)).last
      end
      
      def save_meta(meta_headers)
        meta = Object.meta_prefixed(meta_headers)
        @bucket.interface.copy(@bucket.name, @key, @bucket.name, @key, :replace, meta)
        @meta_headers = Object.partition_into_meta_headers(meta).last
      end
 
      def exists?
        @bucket.find_or_create_object_by_absolute_path(key).last_modified ? true : false
      end

      
      def delete
        raise 'Object key must be specified.' if @key.blank?
        @bucket.interface.delete(@bucket, @key) 
      end
      
      def grantees
        Grantee::grantees(self)
      end
    end
  end
end
