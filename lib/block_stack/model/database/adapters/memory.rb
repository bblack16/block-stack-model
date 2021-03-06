module BlockStack
  module Models
    module Memory
      def self.included(base)
        base.extend ClassMethods
        base.send(:include, BlockStack::Model)
        base.send(:include, InstanceMethods)
      end

      def self.type
        [:memory]
      end

      def self.client
        'BlockStack::Database::MemoryDb'
      end

      BlockStack::Adapters.register(self)

      def self.build_db(type, *args)
        require_relative '../databases/memory_db'
        BlockStack::Database::MemoryDb.new
      end

      module ClassMethods

        def find(query)
          query = { id: query } unless query.is_a?(Hash)
          find_all(query).first
        end

        def all(opts = {})
          query_dataset
        end

        def find_all(query, opts = {})
          all.find_all do |i|
            run_query(i, query)
          end
        end

        def custom_instantiate(result)
          return nil unless result
          return result if result.is_a?(Model)
          self.new(result)
        end

        def query(query = {}, dataset = query_dataset, &block)
          raise RuntimeError, "BlockStack::Query was not loaded but :query was called on #{self}. Try adding require 'block_stack/query'" unless defined?(BlockStack::Query)
          dataset = yield(dataset) || dataset if block_given?
          BlockStack::Query.execute(query, all)
        end unless respond_to?(:query)

        def query_dataset
          return dataset unless is_polymorphic_child?
          type = send(init_foundation_method)
          dataset.find_all do |obj|
            value = obj.is_a?(Model) ? obj.send(init_foundation_method) : obj[init_foundation_method]
            value == type
          end
        end

        protected

        def run_query(obj, query)
          query.all? do |k, v|
            query_check(v, obj.attribute(k))
          end
        end

        def query_check(exp, value)
          case exp
          when Regexp
            exp =~ value.to_s
          when Range
            exp === value
          when String
            exp == value.to_s
          else
            exp == value
          end
        end
      end

      module InstanceMethods
        protected

        def adapter_save
          db.save(dataset_name, self)
        end

        def adapter_delete
          db.delete(dataset_name, self)
        end
      end
    end
  end
end
