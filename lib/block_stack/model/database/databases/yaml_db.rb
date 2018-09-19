require_relative 'file_db'

module BlockStack
  module Database
    class YAMLDb < FileDb
      include BBLib::Effortless

      def self.file_types
        ['*.yml', '*.yaml']
      end

      def dataset(name)
        path = datasets[name.to_sym]
        return [] unless path && File.exist?(path)
        [(YAML.load_file(path) || [])].flatten(1).compact.keys_to_sym
      end

      def save_dataset(name, payload)
        payload.to_yaml.to_file(File.join(path, "#{name}.yml"), mode: 'w')
      end
    end
  end
end
