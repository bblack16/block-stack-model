module BlockStack
  module Associations
    class OneToOne < Association
      attr_bool :foreign_key, default: false

      def associated?(obj_a, obj_b)
        return false if obj_a == obj_b
        retrieve(obj_a) == obj_b
      end

      def associate(obj_a, obj_b)
        obj_b = model.find(obj_b) unless obj_b.is_a?(Model)
        return false unless obj_a && obj_b
        return true if associated?(obj_a, obj_b)
        disassociate_all(obj_a)
        query = foreign_key? ? { attribute => obj_b.attribute(column) } : { column => obj_a.attribute(attribute) }
        (foreign_key? ? obj_a : obj_b).update(query)
      end

      def disassociate(obj_a, obj_b)
        if foreign_key?
          query = { attribute => obj_b.attribute(column) }
          obj_a.class.find_all(query).each { |i| i.update(attribute => nil) }
        else
          query = { column => obj_a.attribute(attribute) }
          obj_b.class.find_all(query).each { |i| i.update(column => nil) }
        end
      end

      def retrieve(obj)
        return nil unless obj.id
        if foreign_key?
          raise InvalidAssociationError, "#{obj.class} does not have a method named #{attribute} and cannot be associated with a #{model}." unless obj.respond_to?(attribute)
        else
          raise InvalidAssociationError, "#{model} does not have a method named #{column} and cannot be associated with a #{obj.class}." unless model.attribute?(column)
        end
        model.find(column => obj.attribute(attribute))
      end

      def delete(obj)
        return true unless cascade? && !foreign_key
        retrieve(obj)&.delete
      end

      def opposite
        OneToOne.new(
          from: to,
          to: from,
          column: attribute,
          attribute: column,
          foreign_key: !foreign_key
        )
      end

      def process_dform(form, obj)
        # TODO Fix this so that it uses presets
        field = {
          name:          attribute,
          type:          :select,
          label:         model.clean_name,
          include_blank: true,
          class:         'select-2',
          # TODO Improve sorting for options (make it customizable)
          options:       model.all.map { |m| [m.id, m.title] }.sort_by { |ary| ary.last.to_s.downcase }.to_h
        }.merge(dformed_args)
        if form.field(attribute)
          field[:value] = form.field(attribute).value
          form.replace(attribute, form.field(attribute).serialize.deep_merge(field))
        else
          form.add_field(field)
        end
      end

      protected

      def simple_init(*args)
        super
        named = BBLib.named_args(*args)
        self.attribute = named[:attribute] || (foreign_key? ? "#{to.singularize}_id".to_sym : :id)
        self.column = named[:column] || (foreign_key? ? :id : "#{from.singularize}_id".to_sym)
      end

      def method_name_default
        to&.singularize
      end

    end
  end
end
