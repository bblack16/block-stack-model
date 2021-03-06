require_relative 'memory'

module BlockStack
  module Models
    module CSV
      def self.included(base)
        base.extend(Memory::ClassMethods)
        base.send(:include, BlockStack::Model)
        base.send(:include, Memory::InstanceMethods)
      end

      def self.type
        [:csv]
      end

      def self.client
        'BlockStack::Database::CSVDb'
      end

      BlockStack::Adapters.register(self)

      def self.build_db(type, *args)
        require_relative '../databases/csv_db'
        BlockStack::Database::CSVDb.new(*args)
      end

    end
  end
end
