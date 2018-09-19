require_relative 'file_db'

module BlockStack
  module Database
    class JSONDb < FileDb
      include BBLib::Effortless

      def self.file_types
        ['*.json']
      end

      def dataset(name)
        path = datasets[name.to_sym]
        return [] unless path && File.exist?(path)
        [JSON.parse(File.read(path))].flatten(1).compact.keys_to_sym
      end

      def save_dataset(name, payload)
        payload.to_json.to_file(File.join(path, "#{name}.json"), mode: 'w')
      end
    end
  end
end
