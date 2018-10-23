require_relative 'model_associations'
require_relative 'validation/validation'
require_relative 'exceptions/invalid_model'
require_relative 'exceptions/uniqueness_error'
require_relative 'exceptions/invalid_association'
require_relative 'change_set'
require_relative 'configuration'

module BlockStack
  module Model

    def self.included(base)
      included_classes.push(base)
      base.send(:include, BBLib::Effortless)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.extend(Associations)

      base.singleton_class.send(:after, :all, :find_all, :query, :search, :instantiate_all, send_value_ary: true, modify_value: true)
      base.singleton_class.send(:after, :find, :first, :last, :sample, :instantiate, send_value: true, modify_value: true)
      base.send(:attr_int, :id, default: nil, allow_nil: true, sql_type: :primary_key, dformed: false)
      base.send(:attr_time, :created_at, :updated_at, default_proc: proc { Time.now }, dformed: false, blockstack: { display: false }, searchable: false)
      base.send(:attr_of, Configuration, :configuration, default_proc: proc { |x| x.ancestor_config }, singleton: true)
      base.send(:attr_of, ChangeSet, :change_set, default_proc: proc { |x| ChangeSet.new(x) }, serialize: false, dformed: false)
      base.send(:attr_ary_of, Validation, :validations, default: [], singleton: true)
      base.send(:attr_hash, :errors, default: {}, serialize: false, dformed: false)
      base.send(:bridge_method, :config, :db, :model_name, :clean_name, :plural_name, :dataset_name, :validations, :associations, :track_changes?)
      base.send(:config, display_name: base.clean_name)
      
      base.load_associations

      ##########################################################
      # Add basic implementations of query methods
      # Only if they are not already defined by the adapter or class
      ##########################################################
      base.instance_eval do
        # Should take an ID or hash based query and return a single result.
        def find(query)
          query = { id: query } unless query.is_a?(Hash)
          find_all(query).first
        end unless respond_to?(:find)

        # Takes an ID (integer) or an Integer Range and returns the matching
        # record(s).
        def [](id)
          case id
          when Range
            all[id]
          else
            find(id)
          end
        end unless respond_to?(:[])

        # Takes a basic query and returns all matching results. This has no
        # default implementation, so adapters MUST redefine this method.
        def find_all(query, &block)
          raise AbstractError, 'This method should have been defined in a sub class.'
        end unless respond_to?(:find_all)

        # Returns all saved instances of this model. There is no default implementation
        # so adapters MUST redefine this method.
        def all(&block)
          raise AbstractError, 'This method should have been defined in a sub class.'
        end unless respond_to?(:all)

        # Retrieves the first instance of this model.
        def first
          all.first
        end unless respond_to?(:first)

        # Returns the last or latest instance of this model.
        def last
          all.last
        end unless respond_to?(:last)

        # Returns the total number of instances of this model type currently in
        # the dataset.
        def count(query = {})
          query.nil? || query.empty? ? all.size : find_all(query).size
        end unless respond_to?(:count)

        # Calculates the sum of a given field and returns it.
        # A query can optionally be passed to sum only matching results.
        def sum(field, query = {})
          find_all(query).map { |i| i.attribute(field) }.sum
        end unless respond_to?(:sum)

        # Calculates the average of a given field and returns it.
        # A query can optionally be passed to average only matching results.
        def average(field, query = {})
          BBLib.average(find_all(query).map { |i| i.attribute(field) })
        end unless respond_to?(:average)

        # Finds the minimum value of a given field and returns it.
        # A query can optionally be passed to check only matching results.
        def min(field, query = {})
          find_all(query).map { |i| i.attribute(field) }.min
        end unless respond_to?(:min)

        # Finds the maximum value of a given field and returns it.
        # A query can optionally be passed to check only matching results.
        def max(field, query = {})
          find_all(query).map { |i| i.attribute(field) }.max
        end unless respond_to?(:max)

        # Returns all disctinct values for the provided field.
        # A query can optionally be passed to check only matching results.
        def distinct(field, query = {})
          find_all(query).map { |i| i.attribute(field) }.uniq
        end unless respond_to?(:distinct)

        # Used to return a random instance of this model from the dataset.
        def sample(query = {})
          query ? find_all(query).sample : all.sample
        end unless respond_to?(:sample)

        # Checks to see if a model exists in the dataset either by ID or a
        # provided query.
        def exist?(query = {})
          query = { id: query } unless query.is_a?(Hash)
          (query && find(query) != nil) ? true : false
        end unless respond_to?(:exist?)

        # Returns a range of the model based on a page number. The page number uses
        # the models paginate_at to calculate the range to return.
        # If pagination is disabled, only index = 1 will return results and will
        # simply call :all.
        def page(index = 1)
          index = index.to_i
          return [] unless index.positive?
          return index == 1 ? all : [] unless config.paginate_at
          offset = (index - 1) * config.paginate_at
          cap = offset + config.paginate_at
          self[offset...cap]
        end unless respond_to?(:page)

        # Basic search implementation. Generally this should be recreated by the
        # adapter or even by the specific model. In the default implementation this
        # will search only attributes that have the :searchable option set to true.
        # Different adapaters will likely alter this behavior and the default
        # implementation is extremely inneficient against large datasets since it
        # loads everything.
        # This differs from :query in that the search passed in should be a string
        # that will be checked against all searchable fields.
        def search(query, opts = {})
          if defined?(BlockStack::Query)
            # TODO Add implementation via Query
            Model.basic_search(query, all, opts[:fields])
          else
            Model.basic_search(query, all, opts[:fields])
          end
        end unless respond_to?(:search)

        # Runs the provided query against this model.The query should be a String,
        # Hash or BlockStack::Query object. This method will only work if
        # BlockStack::Query is available, otherwise an exception will be
        # thrown. Generally this does not need to be overwritten by adapters
        # since BlockStack::Query comes with its own adapters.
        # This differs from :search in that the query passed in is expected to
        # be in the BlockStack::Query DSL, which targets specific fields.
        def query(query = {}, dataset = query_dataset, &block)
          raise RuntimeError, "BlockStack::Query was not loaded but :query was called on #{self}. Try adding require 'block_stack/query'" unless defined?(BlockStack::Query)
          dataset = yield(dataset) || dataset if block_given?
          BlockStack::Query.execute(query, dataset)
        end unless respond_to?(:query)

        # This method is called by the default query method and should return
        # the dataset of the adapter.
        # This can be used to enhance the dataset before it is used for querying.
        # For example, a SQL adapter may add joins to the dataset before handing
        # it to the query method.
        def query_dataset
          dataset
        end unless respond_to?(:query_dataset)
      end
    end

    def self.Dynamic(db = Database.db)
      db = Database.databases[db.to_sym] if db.is_a?(Symbol) || db.is_a?(String)
      unless db
        BlockStack.logger.warn('No database has been configured. Models cannot be dynamically loaded without one. Creating an in-memory DB for now.')
        db = Database.setup(:default, :memory)
      end
      BlockStack::Adapters.by_client(db.class)
    end

    def self.next_db
      @next_db
    end

    def self.next_db=(db)
      @next_db = db
    end

    def self.consume_next_db
      db = Model.next_db
      Model.next_db = nil
      db || BlockStack::Database.db
    end

    def self.model_for(name)
      included_classes_and_descendants.find { |c| c.dataset_name == name || c.model_name == name }
    end

    def self.included_classes
      @included_classes ||= []
    end

    def self.included_classes_and_descendants
      included_classes.flat_map { |c| [c] + c.descendants }
    end

    def self.default_config
      Configuration.new
    end

    module ClassMethods
      def inherited(subclass)
        subclass.db(Model.consume_next_db)
      end

      def database_name
        @database_name ||= Database.name_for(db) || :unknown
      end

      def load_associations
        BlockStack::Associations.associations_for(dataset_name).each do |asc|
          send(asc.type, asc.to, asc: asc)
        end
        BlockStack::Associations.associations.values.each do |h|
          h.values.each do |asc|
            asc.through_model if asc.respond_to?(:through)
          end
        end
      end

      def create(payload)
        new(payload).tap do |obj|
          obj.save
        end
      end

      def create_or_update(payload)
        query = [config.unique_by].flatten.hmap do |field|
          [ field.to_sym, payload[field] ]
        end
        if item = find(query)
          item.update(payload)
          item
        else
          create(payload)
        end
      end

      def create_many(*payloads)
        payloads.flatten.map do |payload|
          create(payload)
        end
      end

      def create_or_update_many(payloads)
        [payloads].flatten(1).all? do |payload|
          create_or_update(payload)
        end
      end

      def db(database = nil)
        return @db = database if database
        @db ||= Database.db
      end

      def model_name(name = nil)
        @model_name = name if name
        @model_name || to_s.split('::').last.method_case.to_sym
      end

      def plural_name(new_name = nil)
        @plural_name = new_name if new_name
        @plural_name || self.model_name.to_s.pluralize.to_sym
      end

      def clean_name
        model_name.to_s.gsub(/_+/, ' ').title_case
      end

      def attribute?(name)
        return nil unless name
        _attrs.include?(name)
      end

      def dataset_name(new_name = nil)
        return @dataset_name = new_name.to_sym if new_name
        @dataset_name ||= plural_name
      end

      def dataset
        db[dataset_name]
      end

      def associations
        BlockStack::Associations.associations_for(self)
      end

      def ancestor_config
        config = Model.default_config
        ancestors.reverse.each do |a|
          next if a == self
          config = config.merge(a.config) if a.respond_to?(:config)
        end
        config
      end

      def config?(key)
        configuration.include?(key)
      end

      def config(args = nil)
        case args
        when Hash
          args.each { |k, v| configuration.send("#{k}=", v) }
        when String, Symbol
          configuration.to_h.hpath(args).first
        when nil
          configuration
        else
          raise ArgumentError, "Not sure what to do with the argument passed to configs. Class was #{args.class}."
        end
      end

      def instantiate(result)
        return nil unless result
        return result if result.is_a?(Model)
        if respond_to?(:custom_instantiate)
          send(:custom_instantiate, result)
        else
          self.new(result)
        end
      end

      def instantiate_all(*results)
        results.map { |r| instantiate(r) }
      end

      def validate(attribute, type, *expressions, **opts, &block)
        opts = opts.merge(expressions: expressions) unless expressions.empty?
        opts = opts.merge(expressions: block, type: :custom) if block
        self.validations << Validation.new(opts.merge(attribute: attribute, type: type))
      end

      def dform(obj = self)
        DFormed.form_for(obj, bypass: true).tap do |form|
          associations.each { |association| association.process_dform(form, obj) if association.process_dforms? }
        end
      end

      # Returns the controller class for this model if one exists.
      # If the build param is set to true, a class will be dynamically
      # instantiated if one does not already exist.
      def controller(crud: false)
        raise RuntimeError, "BlockStack::Controller not found. You must require it first if you wish to use it: require 'block_stack/server'" unless defined?(BlockStack::Controller)
        return @controller if @controller
        controller_class = BlockStack.setting(:default_controller) unless controller_class.is_a?(BlockStack::Controller)
        # Figure out this classes namespace
        namespace = self.to_s.split('::')[0..-2].join('::')
        controller = BBLib.class_create([namespace, "#{self}Controller"].compact.join('::'), controller_class)
        controller.crud(self) if crud
        @controller = controller
      end

      def controller=(cont)
        raise RuntimeError, "BlockStack::Controller not found. You must require it first if you wish to use it: require 'block_stack/server'" unless defined?(BlockStack::Controller)
        raise TypeError, "Controller must be a BlockStack::Controller" unless cont.is_a?(BlockStack::Controller)
        @controller = cont
      end

      def register_link(name, url)
        config(links: {}) unless config.links.is_a?(Hash)
        tag = BBLib::HTML.build(:a, name.to_s.title_case, href: tag) if url.is_a?(String) && !tag.strip.encap_by?('<')
        config.links[name.to_sym] = tag
      end

      def link_for(name, label = nil, **attributes)
        if config.links && link = config.links[name.to_sym].dup
          context = attributes.delete(:context) || self
          link.content = BBLib.pattern_render(label || link.content, context)
          link.attributes = link.attributes.hmap do |k, v|
            [k, BBLib.pattern_render(v.to_s, context)]
          end
          return link.merge(attributes)
        end
      end

      def link_for?(name, context = self)
        config.links && config.links.include?(name.to_sym)
      end

      # Returns only the attrs of this model that have searchable set to true.
      def searchable_attributes
        _attrs.find_all do |name, data|
          next if data[:options][:singleton]
          next if data[:options][:serialize] == false
          !data[:options].include?(:searchable) ||
          data[:options][:searchable]
        end.to_h
      end
    end

    module InstanceMethods
      def ==(obj)
        obj.is_a?(Model) && self.class == obj.class && id == obj.id
      end

      def exist?
        self.class.exist?(unique_by_query)
      end

      def dataset_name
        self.class.dataset_name
      end

      def dataset
        self.class.dataset
      end

      def attributes
        self.class._attrs.keys
      end

      def attribute(name)
        send(name) if attribute?(name)
      end

      def attribute?(name)
        return nil unless name
        _attrs.include?(name) && respond_to?(name)
      end

      def update(params, save_after = true)
        # Is the below needed?
        # raise InvalidModelError, self unless valid?
        params.each do |k, v|
          if attribute?(k)
            send("#{k}=", v)
          else
            # TODO toggle behavior (probably between warn or raise error)
            warn("Unknown attribute #{k} passed to #{self.class} in update params. Ignoring it...")
          end
        end
        save_after ? save : true
      end

      def refresh
        self.class.find(id).serialize.each do |k, v|
          send("#{k}=", v) if k.respond_to?("#{k}=")
        end
        reset_change_set
        true
      end

      def save(skip_associations = false)
        logger.debug("About to save #{clean_name} ID: #{id || 'new'}")
        raise InvalidModelError, self unless valid?
        if exist_not_equal?
          if config.merge_if_exist
            self.id = _remote_id
          else
            raise UniquenessError, "Another #{clean_name} already exists with the same attributes (#{[config.unique_by].flatten.join_terms})"
          end
        end
        return true unless change_set.changes?
        # previous = change_set.previous
        # already_exists = exist?
        self.updated_at = Time.now
        adapter_save
        save_associations unless skip_associations
        refresh
        # if track_changes? && already_exists
        #   logger.debug("Saving change history record for #{self} ##{id}.")
        #   history_model.new(id, changes: previous).save
        # end
        true
      end

      def delete
        logger.debug("Deleting #{clean_name} with ID #{id}.")
        delete_associations
        adapter_delete
      end

      def save_associations
        _attrs.find_all { |name, a| a[:options][:association] }.each do |name, opts|
          items = [send(name)].flatten(1).flat_map do |value|
            next unless value
            value.save(true) unless value.exist?
            value
          end.compact
          items = items.first if opts[:options][:association].singular?
          opts[:options][:association].associate(self, items) if items
        end
      end

      def valid?
        return true if validations.empty?
        validate
        self.errors.empty?
      end

      def errors
        validate
        errors
      end

      def validate
        self.errors.clear
        validations.each do |validation|
          valid = validation.valid?(self)
          next if valid
          (errors[validation.attribute] ||= []).push(validation.message)
        end
        self.errors = errors.hmap { |k, v| [k, v.uniq] }
      end

      def delete_associations
        logger.debug { "Deleting associations for #{self.class.clean_name} #{id}." }
        BlockStack::Associations.associations_for(self).all? do |asc|
          logger.debug("Deleting association for #{self.class.clean_name} #{id}: #{asc}")
          asc.delete(self)
        end
      end

      def dform
        self.class.dform(self)
      end

      # Checks to see if this model exists based on it's unique_by config setting
      # and that the existing entry in the database matches this objects
      # id (or whatever a subclass considers to be ==).
      # true means a matching record by uniqueness was found, but with a different
      # id. Note, this can happen if the object itself has a nil id.
      def exist_not_equal?
        query = unique_by_query(self.serialize)
        item = self.class.find(query)
        return false unless item
        item != self
      end

      # Takes a hash of parameters and constructs a query to check existence of
      # this object in the database based on the unique_by config.
      # If no has is provided the attributes of this object are used instead.
      def unique_by_query(hash = nil)
        [config.unique_by].flatten.hmap do |field|
          [ field.to_sym, hash ? hash[field] : attribute(field) ]
        end
      end

      # Finds the ID of the first record that matches this one based on its
      # unique_by configuration. Returns nil if no match is found.
      def _remote_id
        self.class.find(unique_by_query(self.serialize))&.id
      end

      # Default methods used in default views to display this model. Can be overriden
      # in the parent class.

      def title
        [config.title_method].flatten.find { |method| return send(method) if respond_to?(method) } || "#{config.display_name} #{id}"
      end

      def description
        [config.description_method].flatten.find { |method| return send(method) if respond_to?(method) }
      end

      def tagline
        result = [config.tagline_method].flatten.find { |method| return send(method) if respond_to?(method) }
        return result if result
        result = BBLib.chars_up_to(description.to_s.split(/\.[\s$]/).first, 90)
        return result.to_s + '.' if result
        nil
      end

      def thumbnail
        [config.thumbnail_method].flatten.find { |method| return send(method) if respond_to?(method) }
        "/#{clean_name}/#{title}"
      end

      def background
        [config.background_method].flatten.find { |method| return send(method) if respond_to?(method) }
        "/#{clean_name}/background"
      end

      def icon
        [config.icon_method].flatten.find { |method| return send(method) if respond_to?(method) }
        "/#{clean_name}/icon"
      end

      def link_for(name, label = nil, **attributes)
        self.class.link_for(name, label, attributes.merge(context: self))
      end

      def link_for?(name)
        self.class.link_for?(name)
      end

      protected

      def adapter_save
        # Define some logic here on each adapter
      end

      def adapter_delete
        # Define custom delete logic for each adapter
      end

      def reset_change_set
        change_set.reset
      end

      def simple_init(*args)
        reset_change_set
      end
    end

    # A basic search implementation. Used only if BlockStack::Query is not
    # available since it is far more efficient and powerful.
    def self.basic_search(query, models, fields = nil)
      models.find_all do |model|
        model.class.searchable_attributes.any? do |name, details|
          next if fields && !fields.include?(name)
          value = model.send(name)
          next unless value && !value.to_s.strip.empty?
          basic_search_match(query, value)
        end
      end
    end

    # A basic search implementation helper method. Used only if BlockStack::Query is not
    # available since it is far more efficient and powerful.
    def self.basic_search_match(query, value)
      case [value.class]
      when [Array]
        value.map { |v| basic_search_match(query, v) }
      when [Hash]
        value.squish.values.map { |v| basic_search_match(query, v) }
      when [Integer], [Float]
        value == query.to_s.to_i if query =~ /^\d+$/
      when [Time]
        value == Time.parse(query) rescue nil
      when [Date]
        value == Date.parse(query) rescue nil
      else
        value =~ /#{Regexp.escape(query.to_s).gsub('\\*', '.*')}/i
      end
    end

  end
end
