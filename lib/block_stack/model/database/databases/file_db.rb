module BlockStack
  module Database

    class FileDb
      include BBLib::Effortless

      attr_dir :path, mkdir: true
      attr_bool :recursive, default: false

      def self.file_types
        []
      end

      def next_id(dataset_name)
        (dataset(dataset_name).map { |i| i[:id].to_i }.max || 0) + 1
      end

      bridge_method :file_types

      def datasets
        BBLib.scan_dir(path, *file_types, recursive: recursive).hmap do |file|
          [file.file_name(false).method_case.to_sym, file]
        end
      end

      def dataset(name)
        # Fill this in in child classes
      end

      def [](name)
        dataset(name)
      end

      def save_dataset(name, payload)
        # Fill this in in child classes
      end

      def has?(dataset_name, id)
        dataset[dataset_name].any? do |result|
          result[:id].to_i == id
        end
      end

      def save(dataset_name, obj)
        obj.id = next_id(dataset_name) unless obj.id
        dataset = dataset(dataset_name)
        dataset.delete_if { |item| item[:id].to_i == obj.id }
        dataset << obj.serialize
        save_dataset(dataset_name, sort_dataset(dataset))
        return obj.id
      end

      def delete(dataset_name, obj)
        dataset = dataset(dataset_name)
        dataset.delete_if { |item| item[:id].to_i == obj.id }
        save_dataset(dataset_name, dataset)
        return obj.id
      end

      def sort_dataset(dataset)
        dataset.sort_by { |i| i[:id].to_i }
      end

    end
  end
end
