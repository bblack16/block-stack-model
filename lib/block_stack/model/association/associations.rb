require_relative 'association'

module BlockStack
  module Associations
    ASSOCIATION_TYPES = [:one_to_one, :one_to_many, :many_to_one, :many_to_many, :one_through_one]

    def self.associations
      @associations ||= {}
    end

    def self.types
      BlockStack::Association.descendants.flat_map { |d| d.type }.uniq
    end

    def self.add(asc, add_opposite = true)
      return asc if (associations[asc.from] ||= {})[asc.method_name] == asc
      associations[asc.from][asc.method_name] = asc
      if add_opposite && !association?(asc.to, asc.from)
        [asc.opposite].flatten.each do |op|
          add(op, false)
        end
      end
      asc
    end

    def self.association?(model, dataset)
      associations[model] && associations[model][dataset] ? true : false
    end

    def self.retrieve(from, to)
      association_for(from, to)&.retrieve(from)
    end

    def self.association_for(from, method)
      from = from.dataset_name if from.respond_to?(:dataset_name)
      associations[from] ? associations[from][method] : nil
    end

    def self.associations_for(obj)
      dataset_name = obj.respond_to?(:dataset_name) ? obj.dataset_name : obj
      associations[dataset_name]&.values || []
    end
  end
end
