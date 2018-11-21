module BlockStack
  module Model
    # This object holds all of the configuration for a model within the Class object.
    # Since this is a HashStruct new configurations can be added by simply calling
    # any method followed by an = to set it (assuming that method does not already
    # exist). There are some basic configuration items shown below that are restricted
    # to specific values. Arbitrary configuration has no restrictions of object types.
    class Configuration < BBLib::HashStruct
      include BBLib::Effortless

      # Basic attributes
      # ----------------
      # Defines what field or fields make this object uniq. Mostly used by create_or_update to determine if a matching model exists
      attr_ary_of [Symbol], :unique_by, default: [:id]
      # Sets the default number of items returned for APIs. Set to nil to disable pagination completely (default).
      attr_int :paginate_at, default: nil, allow_nil: true
      # Default link tags for this model. Supports pattern interpolation using the {{field_name}} syntax
      attr_hash :links, default_proc: :default_links

      # Database attributes
      # -------------------
      # Dynamically add properties based on backend store. This will dynamically add readers/writers for data in the dataset.
      attr_bool :dynamic_properties, default: true
      # If a dataset (such as a SQL table) does not exist should the model try to create it
      # NOTE: This setting does not matter for most schema-less adapters.
      attr_bool :create_dataset_if_not_exist, default: true
      # When set to true any fields (or columns, SQL) not present in the dataset will be created on the fly by the model
      attr_bool :create_missing_fields, default: true
      # When an item is sent to create that already exists based on "unique_by", settings this to true will cause it to be merged. Otherwise and error will be raised.
      attr_bool :merge_if_exist, default: false

      # Attributes for default values and images in views
      # -------------------------------------------------
      # The attribute to use for a title in views that support it
      attr_ary_of [Symbol], :title_method, default: [:name]
      # The attribute to use for a tagline in views that support it
      attr_ary_of [Symbol], :tagline_method, default: [:brief, :short_description]
      # The attribute to use as a description in views that support it
      attr_ary_of [Symbol], :description_method, default: [:desc, :overview, :brief, :synopsis]
      # The attribute to use for a thumbnail in views that support it
      attr_ary_of [Symbol], :thumbnail_method, default: [:cover, :poster, :front_cover, :thumb]
      # The method(s) to call to get a large background image for this object
      attr_ary_of [Symbol], :background_method, default: [:backdrop, :fanart]
      # The method(s) to call to get an icon for this object
      attr_ary_of [Symbol], :icon_method, default: []

      # TODO Implement the below in the model
      # The setters below are not yet used in the BlockStack::Model or views
      # --------------------------------------------------------------------
      # Should be the name of the attribute to sort on by default. This can also be an array of fields. nil allows the adapter to use it's default sort (usually ID)
      attr_ary_of [Symbol], :sort_by, default: nil, allow_nil: true
      # When set to true, relations on this model will be serialized when serialize is called
      # attr_bool :serialize_relations, default: false
      # Set to true to enable caching or false to disable it. The adapter must support caching for this to matter.
      # attr_bool :cache, default: true
      # How long in seconds cached calls from this object should live. The adapter must support caching for this to matter.
      # attr_float :cache_ttl, default: 120

      init_type :loose

      def default_links
        {
          show:   BBLib::HTML.build(:a, 'View', href: '/{{dataset_name}}/{{id}}'),
          index:  BBLib::HTML.build(:a, '{{plural_name}}', href: '/{{dataset_name}}'),
          delete: BBLib::HTML.build(:a, 'Delete', class: 'delete-model-btn', href: '#', 'del-url': "/api/{{dataset_name}}/{{id}}", 're-url': "/{{dataset_name}}"),
          edit:   BBLib::HTML.build(:a, 'Edit', href: '/{{dataset_name}}/{{id}}/edit'),
          create: BBLib::HTML.build(:a, 'New {{clean_name}}', href: '/{{dataset_name}}/new')
        }.tap do |hash|
          hash.merge!(
            view:    hash[:show],
            new:     hash[:create],
            browse:  hash[:index],
            destroy: hash[:delete]
          )
        end
      end

      protected

      def simple_init(*args)
        BBLib.named_args(*args).each do |k, v|
          next if self.respond_to?(k)
          self.send("#{k}=", v)
        end
      end
    end
  end
end
