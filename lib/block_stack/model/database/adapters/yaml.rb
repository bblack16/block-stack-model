require_relative 'memory'

module BlockStack
  module Models
    module YAML
      def self.included(base)
        base.extend(Memory::ClassMethods)
        base.send(:include, BlockStack::Model)
        base.send(:include, Memory::InstanceMethods)
      end

      def self.type
        [:yaml]
      end

      def self.client
        'BlockStack::Database::YAMLDb'
      end

      BlockStack::Adapters.register(self)

      def self.build_db(type, *args)
        require_relative '../databases/yaml_db'
        BlockStack::Database::YAMLDb.new(*args)
      end

    end
  end
end
