module BlockStack
  class Association
    include BBLib::Effortless
    attr_symbol :column, :attribute
    attr_symbol :from, :to, required: true
    attr_of Object, :model, allow_nil: true, serialize: false
    attr_bool :cascade, default: true
    attr_sym :method_name, default_proc: :method_name_default, allow_nil: true
    attr_bool :singular, default: true
    attr_bool :process_dforms, default: true
    attr_hash :dformed_args

    before :model, :lookup_model

    def self.type
      self.to_s.split('::').last.method_case.to_sym
    end

    def type
      self.class.type
    end

    def ==(obj)
      obj.is_a?(Association) && type == obj.type && serialize == obj.serialize
    end

    # Returns true if both objects are associated by the bounds of this association
    # (they may be associated in a different way, but this is scoped to only this association.)
    def associated?(obj_a, obj_b)
      raise BBLib::AbstractError
    end

    # Associates the given object to the provided model objects.
    def associate(obj_a, obj_b)
      raise BBLib::AbstractError
    end

    # Removes the associations to the given object for the provided model objects.
    def disassociate(obj_a, obj_b)
      raise BBLib::AbstractError
    end

    def disassociate_all(obj)
      [retrieve(obj)].flatten.compact.each { |i| disassociate(obj, i) }
    end

    # Retrieves the associated model(s)
    def retrieve(obj)
      raise BBLib::AbstractError
    end

    # Hook for cascading delete when the provided object is deleted
    def delete(obj)
      return true unless cascade?
      raise BBLib::AbstractError
    end

    # Generates the opposite association for this one (for the other side)
    # Can return an array of associations to add more than one
    def opposite
      raise BBLib::AbstractError
    end

    def process_dform(form, obj)
      # Nothing in base class. This allows subclasses to add to or
      # modify the dformed form for the parent object.
    end

    protected

    def simple_init(*args)
      method_name
    end

    def lookup_model
      return if @model
      @model = BlockStack::Model.model_for(to)
    end

    def method_name_default
      to
    end

  end
end

require_relative 'types/one_to_one'
require_relative 'types/one_to_many'
require_relative 'types/many_to_one'
require_relative 'types/many_to_many'
require_relative 'types/one_through_one'
