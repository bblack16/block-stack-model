require_relative 'association/associations'

module BlockStack
  module Model
    module Associations
      BlockStack::Association.descendants.each do |association|
        define_method(association.type) do |name, opts = {}|
          custom = opts.delete(:options) || {}
          opts.delete(:default)
          asc = BlockStack::Associations.add(opts[:asc] || association.new(opts.merge(from: dataset_name, to: name)))
          defaults = {
            dformed_field: { type: (asc.singular? ? :select : :multi_select) },
            serialize:     false,
            association:   asc,
            default_proc:  proc { |x| asc.retrieve(x) }
          }

          (opts[:blockstack] ||= {})[:display] = false unless opts[:blockstack] && opts[:blockstack][:display]
          attr_custom(asc.method_name, opts.merge(custom).merge(defaults)) do |args|
            items = [args].flatten.compact.map do |arg|
              if arg.is_a?(Hash)
                _attr_pack(arg, asc.model, opts)
              elsif arg.is_a?(Model)
                arg
              else
                asc.model.find(arg)
              end
            end.compact
            asc.singular? ? items.first : items
          end
        end
      end
    end
  end
end
