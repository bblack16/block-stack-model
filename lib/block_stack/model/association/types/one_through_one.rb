module BlockStack
  module Associations
    class OneThroughOne < ManyToMany

      def associated?(obj_a, obj_b)
        super && retrieve(obj_a) == obj_b
      end

      def associate(obj_a, obj_b)
        obj_b = model.find(obj_b) unless obj_b.is_a?(Model)
        return true if associated?(obj_a, obj_b)
        disassociate_all(obj_a)
        disassociate_all(obj_b)
        through_model.create(through_attribute => obj_a.attribute(attribute), through_column => obj_b.attribute(column))
      end

      def disassociate(obj_a, obj_b)
        through_model.find_all(through_attribute => obj_a.attribute(attribute)).all? { |i| i.delete }
        through_model.find_all(through_column => obj_b.attribute(column)).all? { |i| i.delete }
      end

      def retrieve(obj)
        return nil unless obj.id
        join_id = through_model.find(through_attribute => obj.attribute(attribute))&.attribute(through_column)
        return nil unless join_id
        model.find(column => join_id)
      end

      def delete(obj)
        return true unless cascade?
        retrieve(obj)&.delete
      end

      def opposite
        OneThroughOne.new(
          from:      to,
          to:        from,
          column:    attribute,
          attribute: column,
          through:   through
        )
      end

      def process_dform(form, obj)
        form.add_field(
          {
            name:          method_name,
            type:          :select,
            label:         model.clean_name,
            include_blank: true,
            value:         obj.send(method_name)&.id,
            options:       model.all.hmap { |m| [m.id, m.title] }
          }.merge(dformed_args)
        )
      end

      protected

      def method_name_default
        to&.singularize
      end

    end
  end
end
