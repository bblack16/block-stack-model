module BlockStack
  module HistoryModel
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.send(:after, :save, :save_history)
      base.send(:bridge_method, :history_model)
    end

    module ClassMethods
      def history_model(db = Database.db)
        return @audit_model if @audit_model
        namespace = self.to_s.split('::')[0..-2].join('::')
        @audit_model = BBLib.class_create([namespace, "#{self}History"].compact.join('::')) do
          include BBLib::Effortless
          attr_int :version, default_proc: :next_version
          attr_hash :changes

          bridge_method :for_model

          def next_version
            1
          end

          def self.for_model
            model_name.to_s.sub(/_history$/, '').to_sym
          end
        end.tap do |klass|
          klass.send(:include, BlockStack::Model::Dynamic(db))
          klass.send(:attr_int, "#{model_name}_id".to_sym, arg_at: 0)
          klass.send(:define_method, :next_version) do
            return 1 unless send("#{for_model}_id")
            (self.class.max(:version, "#{for_model}_id": send("#{for_model}_id")) || 0) + 1
          end
        end
      end
    end

    module InstanceMethods
      def save_history
        # p change_set.diff, change_set.previous
        return true unless change_set.diff?
        logger.debug("Saving change history record for #{self} ##{id}.")
        history_model.new(id, changes: change_set.previous).save
      end
    end
  end
end
