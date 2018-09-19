require_relative 'file_db'
require 'csv'

module BlockStack
  module Database
    class CSVDb < FileDb
      include BBLib::Effortless

      def self.file_types
        ['*.csv']
      end

      def dataset(name)
        path = datasets[name.to_sym]
        return [] unless path && File.exist?(path)
        csv = CSV.parse(File.read(path), headers: true).map(&:to_h)
        [(csv || [])].flatten(1).compact.keys_to_sym
      end

      def save_dataset(name, payload)
        CSV.generate do |csv|
          csv << payload.first.keys
          payload.each { |row| csv << row.values }
        end.to_file(File.join(path, "#{name}.csv"), mode: 'w')
      end
    end
  end
end
