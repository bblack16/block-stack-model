module BlockStack
  module Associations
    class ManyToMany < Association
      attr_sym :through, required: true
      attr_of Object, :through_model, serialize: false
      attr_sym :through_attribute, :through_column, serialize: false

      attr_bool :singular, default: false

      before :through_model, :through_attribute, :through_column, :lookup_through_model

      def associated?(obj_a, obj_b)
        return false if obj_a == obj_b
        ary = [obj_a, obj_b]
        b = ary.find { |m| m.is_a?(model) }
        a = ary.find { |m| m.is_a?(BlockStack::Model.model_for(from)) }
        return false unless a && b
        through_model.find(through_attribute => a.attribute(attribute), through_column => b.attribute(column))
      end

      def associate(obj_a, *objs)
        current = retrieve(obj_a)
        [objs].flatten.compact.all? do |obj_b|
          obj_b = model.find(obj_b) unless obj_b.is_a?(Model)
          current.delete(obj_b)
          if associated?(obj_a, obj_b)
            true
          else
            through_model.create(through_attribute => obj_a.attribute(attribute), through_column => obj_b.attribute(column))
          end
        end
        current.each { |i| disassociate(obj_a, i) }
      end

      def disassociate(obj_a, obj_b)
        through_model.find_all(through_attribute => obj_a.attribute(attribute), through_column => obj_b.attribute(column)).all? { |i| i.delete }
      end

      def retrieve(obj)
        return [] unless obj.id
        join_ids = through_model.find_all(through_attribute => obj.attribute(attribute)).map { |r| r.attribute(through_column) }.uniq
        return [] unless join_ids && !join_ids.empty?
        model.find_all(column => join_ids)
      end

      # Many to many does not cascade when deleting
      def delete(obj)
        true
      end

      def opposite
        ManyToMany.new(
          from: to,
          to: from,
          column: attribute,
          attribute: column,
          through: through
        )
      end

      def process_dform(form, obj)
        form.add_field(
          {
            name:          method_name,
            type:          :multi_select,
            label:         model.clean_name,
            include_blank: true,
            value:         obj.send(method_name).map(&:id),
            options:       model.all.hmap { |m| [m.id, m.title] }
          }.merge(dformed_args)
        )
      end

      protected

      def simple_init(*args)
        super
        named = BBLib.named_args(*args)
        self.attribute = named[:attribute] || :id
        self.column = named[:column] || :id
      end

      def lookup_through_model
        column = @through_column
        attribute = @through_attribute
        @through_model     = BlockStack::Model.model_for(through) unless @through_model
        @through_attribute = ("#{BlockStack::Model.model_for(from).model_name}_id".to_sym rescue nil) unless @through_attribute
        @through_column    = ("#{BlockStack::Model.model_for(to).model_name}_id".to_sym rescue nil) unless @through_column
        if !attribute && @through_attribute
          BlockStack::Associations.add(OneToOne.new(
            from: through,
            to: from,
            column: self.attribute,
            attribute: @through_attribute,
            foreign_key: true
          ), false)
        end
        if !column && @through_column
          BlockStack::Associations.add(OneToOne.new(
            from: through,
            to: to,
            column: self.column,
            attribute: @through_column,
            foreign_key: true
          ), false)
        end
      end

    end
  end
end
