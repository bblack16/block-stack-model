module BlockStack
  module Adapters

    def self.adapters
      @adapters ||= []
    end

    def self.register(adapter)
      if adapter.respond_to?(:type)
        adapters << adapter unless adapters.include?(adapter)
        true
      else
        raise ArgumentError, "Invalid adapter #{adapter}. Must respond to :type."
      end
    end

    def self.by_type(type)
      adapters.find do |m|
        [m.type].flatten.include?(type)
      end
    end

    def self.by_client(client)
      adapters.find do |a|
        next unless a.respond_to?(:client)
        [a.client].flatten.include?(client.to_s)
      end
    end

  end

  require_all(File.expand_path('../adapters', __FILE__))
end
