require_relative 'adapters'

module BlockStack
  module Database
    def self.databases
      @databases ||= {}
    end

    def self.db
      databases[primary_database] || databases.values.first
    end

    def self.primary_database
      @primary_database
    end

    def self.primary_database=(name)
      @primary_database = name.to_sym
    end

    def self.dbs
      databases
    end

    def self.name_for(db)
      databases.keys.find { |name| databases[name] == db }
    end

    def self.setup(name, type, *args)
      adapter = BlockStack::Adapters.by_type(type)
      raise ArgumentError, "Could not locate an appropriate adapter for #{type}." unless adapter
      BlockStack.logger.info("Setting up database :#{name}. Type is #{type}.")
      databases[name.to_sym] = adapter.build_db(type, *args)
      BlockStack.logger.info("Added new database client :#{name} (#{databases[name.to_sym].class})")
      databases[name.to_sym]
    end
  end
end
