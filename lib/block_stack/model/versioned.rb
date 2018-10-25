module BlockStack
  module Model
    module Versioned
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
        base.send(:before, :save_associations, :save_version)
        base.send(:bridge_method, :version_model)
        base.send(:one_to_many, "#{base.model_name}_histories".to_sym)
      end

      module ClassMethods
        def version_model(db = Database.db)
          return @version_model if @version_model
          namespace = self.to_s.split('::')[0..-2].join('::')
          @version_model = BBLib.class_create([namespace, "#{self}History"].compact.join('::')) do
            include BBLib::Effortless
            attr_int :version, default_proc: :next_version
            attr_hash :changes, default: {}, pre_proc: proc { |x| x.keys_to_sym }

            bridge_method :parent_name, :parent_model


            def next_version
              1
            end

            def self.parent_name
              model_name.to_s.sub(/_history$/, '').to_sym
            end

            def self.parent_model
              BlockStack::Model.model_for(parent_name)
            end

          end.tap do |klass|
            klass.send(:include, BlockStack::Model::Dynamic(db))
            klass.send(:attr_int, "#{model_name}_id".to_sym, arg_at: 0)
            klass.send(:define_method, :next_version) do
              return 1 unless send("#{parent_name}_id")
              (self.class.max(:version, "#{parent_name}_id": send("#{parent_name}_id")) || 0) + 1
            end
            klass.send(:many_to_one, klass.parent_name)
          end
        end
      end

      module InstanceMethods
        def save_version
          return true unless change_set.previous
          changes = change_set.previous.except(:id, :updated_at, :created_at)
          return true if changes.empty?
          logger.debug("Saving change history record for #{self.model_name} ##{id}.")
          send("#{model_name}_histories") << version_model.new(id, changes: changes)
        end

        # Load the state of this object at a specific version.
        # Version can be an integer to load back to a specific version or
        # a date/time (String, Date or Time) to load the nearest version to the
        # provided time.
        def load_version(version)
          if version.is_a?(String)
            if version =~ /^\d+$/
              version = version.to_i
            else
              version = Time.parse(version)
            end
          elsif version.is_a?(Date)
            Time.parse(version.to_s)
          end
          merged = serialize.tap do |hash|
            versions.select { |h| version.is_a?(Integer) ? h.version >= version : h.created_at > version }
                   .sort_by { |h| h.version }.reverse
                   .each { |h| hash.deep_merge!(h.changes) }
          end
          self.class.new(merged)
        end

        def versions
          return [] unless id
          version_model.find_all("#{model_name}_id": id)
        end
      end
    end
  end
end
