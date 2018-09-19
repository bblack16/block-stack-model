require_relative 'memory'

module BlockStack
  module Models
    module JSON
      def self.included(base)
        base.extend(Memory::ClassMethods)
        base.send(:include, BlockStack::Model)
        base.send(:include, Memory::InstanceMethods)
      end

      def self.type
        [:json]
      end

      def self.client
        'BlockStack::Database::JSONDb'
      end

      BlockStack::Adapters.register(self)

      def self.build_db(type, *args)
        require_relative '../databases/json_db'
        BlockStack::Database::JSONDb.new(*args)
      end

    end
  end
end
