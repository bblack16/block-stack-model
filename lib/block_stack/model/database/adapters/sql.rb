module BlockStack
  module Models
    module SQL

      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, BlockStack::Model)
        base.send(:include, InstanceMethods)

        base.singleton_class.send(:before, :all, :find_all, :find, :first, :last, :sample, :count, :max, :min, :sum, :distinct, :exist?, :create_table_if_not_exist)
        base.send(:before, :save, :delete, :exist?, :create_table_if_not_exist)
      end

      def self.type
        [:sqlite, :postgres, :mysql, :mysql2, :odbc, :oracle, :mssql]
      end

      # TODO Should an adapter be made per SQL DB with a parent mixin?
      def self.client
        [
          'Sequel::SQLite::Database', 'Sequel::Postgres::Database', 'Sequel::MySQL::Database',
          'Sequel::ODBC::Database', 'Sequel::Oracle::Database', 'Sequel::MSSQL::Database'
        ]
      end

      BlockStack::Adapters.register(self)

      def self.build_db(type, *args)
        require 'sequel'
        type = :mysql2 if type == :mysql
        Sequel.send(type, *args).tap do |db|
          db.loggers = [BlockStack.logger]
          db.sql_log_level = :debug
          if type == :postgres
            db.extension :pg_array, :pg_json
          end
        end
      end

      def self.processing_model(model = nil)
        @processing_model = model if model
        @processing_model
      end

      def self.determine_mapping(obj, opts = {})
        case obj
        when :integer, :integer_between, Integer
          :Integer
        when :float, :float_between, Float
          :Float
        when :time, Time, DateTime
          :Timestamp
        when :date, Date
          :Date
        when :bool, :boolean, TrueClass, FalseClass
          :Boolean
        when :element_of
          list = opts[:list].is_a?(Proc) ? opts[:list].call : opts[:list]
          types = list.map { |i| determine_mapping(i) }.uniq
          types.size == 1 ? types.first : :Text
        when :of
          BBLib.most_frequent_str([opts[:classes]].flatten.map { |c| determine_mapping(c) })
        when :array, Array, :elements_of, :array_of
          # TODO Suuport Array when in postgres
          :Text
        when :hash, Hash
          # TODO Suuport JSON when in postgres
          :Text
        when :string, :dir, :file, :symbol, String, Symbol, Dir, File
          :String
        else
          :Text
        end
      end

      # Implementation to add a dynamic property to the class to match
      # a column in the database that does not exist on the class definition
      # def self.add_dynamic_property(key, value)
      #   puts "Adding dynamic sql property: #{key}"
      #   type = case value
      #   when Integer, Float, Array, Hash, Date, Time, String
      #     "attr_#{key.class.to_s.downcase}"
      #   when TrueClass, FalseClass
      #     :attr_bool
      #   else
      #     :attr_str
      #   end
      #   send(type, key, allow_nil: true)
      # end

      def self.serialize_sql(values)
        hash = values.hmap do |k, v|
          [
            k,
            if BBLib.is_any?(v, Array, Hash)
              v.to_json
            elsif BBLib.is_any?(v, Symbol)
              v.to_s
            else
              v
            end
          ]
        end
        hash.delete(:id) unless hash[:id]
        hash
      end

      module ClassMethods
        def find(query)
          query = { id: query } unless query.is_a?(Hash)
          dataset.where(query).first
        end

        def [](id)
          return super unless id.is_a?(Range)
          limit = id.last.negative? ? (count + id.last - id.first) : (id.last - id.first)
          limit = limit + 1 unless id.exclude_end?
          all(offset: id.first, limit: limit)
        end

        def all(opts = {}, &block)
          build_filter(opts).all
        end

        def find_all(query, &block)
          filter = build_filter(query)
          query = query.keys_to_sym if query.is_a?(Hash)
          filter.where(query).all
        end

        def first
          dataset.limit(1).first
        end

        def last
          dataset.order(:id).last
        end

        def count(query = {})
          dataset.where(query).count
        end

        def average(field, query = {})
          dataset.where(query).avg(field)
        end

        def min(field, query = {})
          dataset.where(query).min(field)
        end

        def max(field, query = {})
          dataset.where(query).max(field)
        end

        def sum(field, query = {})
          dataset.where(query).sum(field)
        end

        def distinct(field, query = {})
          dataset.select(field).where(query).distinct.all.map { |i| i[field.to_sym] }
        end

        def sample(query = {})
          case adapter_type
          when :sqlite, :postgres
            dataset.where(query).order(Sequel.function(:random)).limit(1).first
          when :mysql
            dataset.where(query).order(Sequel.function(:rand)).limit(1).first
          else
            all(query).sample
          end
        end

        def search(query)
          sql = attr_columns.hmap do |column|
            next unless searchable_attributes[column[:name]]
            casted = case column[:type]
            when :integer, :Integer, :primary_key
              next unless query =~ /^\d+$/
              query.to_i
            when :float, :Float
              next unless query =~ /^\d+(\.\d+)?$/
              query.to_f
            when :bool, :boolean, :Boolean
              next # Bool fields are not searchable
            else
              query
            end
            [column[:name], casted]
          end.map do |field, expression|
            case expression
            when Integer, Float
              "\"#{field}\" == #{expression}"
            else
              "\"#{field}\" LIKE \"%#{expression}%\""
            end
          end.join(' OR ')
          dataset.where(Sequel.lit(sql)).all
        end

        # Returns the specific SQL adapter being used
        def adapter_type
          {
            'Sequel::SQLite::Database': :sqlite,
            'Sequel::Postgres::Database': :postgres,
            'Sequel::MySQL::Database': :mysql,
            'Sequel::ODBC::Database': :odbc,
            'Sequel::Oracle::Database': :oracle,
            'Sequel::MSSQL::Database': :mssql
          }[db.class.to_s.to_sym] || :unknown
        end

        def table_exist?
          @table_exist ||= db.tables.include?(dataset_name)
        end

        def attr_columns
          _attrs.map do |name, data|
            next if data[:options].include?(:serialize) && !data[:options][:serialize]
            {
              type: data[:options][:sql_type] ? data[:options][:sql_type] : BlockStack::Models::SQL.determine_mapping(data[:type], data[:options]),
              name: name,
              options: data[:sql] || {},
              default: data[:default] || data[:options][:default]
            }
          end.compact
        end

        def missing_columns
          return [] unless table_exist?
          attr_columns.map { |a| a[:name] } - dataset.columns
        end

        def extra_columns
          return [] unless table_exist?
          dataset.columns - attr_columns.map { |a| a[:name] }
        end

        def create_table_if_not_exist
          if table_exist?
            create_missing_columns unless @_columns_checked
            return true
          else
            logger.info("Creating table for #{self}: #{dataset_name} (#{BBLib.plural_string(attr_columns.size, 'column')})")
            BlockStack::Models::SQL.processing_model(self)
            db.create_table?(dataset_name) do
              BlockStack::Models::SQL.processing_model.attr_columns.each do |column|
                BlockStack.logger.info("Adding new column #{column[:name]} [#{column[:type]}]#{column[:options].empty? ? nil : "(#{column[:options].map { |k, v| "#{k}: #{v}" }.join(', ')})"}")
                send(column[:type], column[:name], column[:options])
              end
            end
          end
        end

        # TODO Raise error when columns types are a mismatch (a migration is needed)
        def create_missing_columns
          if missing = missing_columns.empty? || @_columns_checked
            @_columns_checked = true unless @_columns_checked
            return true
          end
          BlockStack::Models::SQL.processing_model(self)
          db.alter_table(dataset_name) do
            missing = BlockStack::Models::SQL.processing_model.missing_columns
            BlockStack.logger.info("Attempting to create #{BBLib.plural_string(missing.size, 'missing column')}.")
            BlockStack::Models::SQL.processing_model.attr_columns.each do |column|
              next unless missing.include?(column[:name])
              BlockStack.logger.info("Adding missing column #{column[:name]} [#{column[:type]}]#{column[:options].empty? ? nil : "(#{column[:options].map { |k, v| "#{k}: #{v}" }.join(', ')})"}")
              add_column(column[:name], column[:type], column[:options])
            end
          end
          missing.each do |column|
            attr_data = attr_columns.find { |col| col[:name] == column }
            next unless  attr_data && !attr_data[:default].nil?
            dataset.update(SQL.serialize_sql(column => attr_data[:default]))
          end
          true
        end

        def drop_extra_columns
          BlockStack::Models::SQL.processing_model(self)
          db.alter_table(dataset_name) do
            BlockStack::Models::SQL.processing_model.extra_columns.each do |col|
              BlockStack.logger.info("Dropping column #{col}")
              drop_column col
            end
          end
        end

        def custom_instantiate(result)
          return nil unless result
          return result if result.is_a?(Model)
          result = deserialize_sql(result)
          self.new(result)
        end

        private

        def build_filter(opts = {})
          opts[:sort] = opts[:order] if opts[:order]
          dataset.limit(opts[:limit]).offset(opts[:offset]).order(opts[:sort])
        end

        def deserialize_sql(result)
          result.hmap do |k, v|
            [
              k.to_sym,
              if _attrs[k.to_sym] && ([:hash, :array, :array_of, :elements_of].any? { |t| t == _attrs[k.to_sym][:type] } || [_attrs[k.to_sym][:classes]].flatten.any? { |c| c.is_a?(Class) && c.ancestors.include?(BBLib::Effortless) }) && v.is_a?(String)
                ::JSON.parse(v)
              elsif defined?(Sequel::Postgres) && v.is_a?(Sequel::Postgres::JSONArray)
                v.keys_to_sym
              else
                v
              end
            ]
          end
        end

      end

      module InstanceMethods
        protected

        def adapter_save
          if exist?
            dataset.where(id: id).update(serialize_sql)
          else
            self.id = dataset.insert(serialize_sql)
          end
          id ? true : false
        end

        def adapter_delete
          super
          dataset.where(id: id).delete
        end

        def create_table_if_not_exist
          self.class.create_table_if_not_exist
        end

        def serialize_sql(values = nil)
          SQL.serialize_sql(values || change_set.diff)
        end
      end
    end
  end
end
