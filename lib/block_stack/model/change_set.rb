module BlockStack
  module Model
    # Used to store the changes made to model in between saves. This is done to
    # avoid unnecessary calls to the database and to view changes made prior to
    # saving them.
    # Also checks to see if there are pending association changes.
    class ChangeSet
      include BBLib::Effortless

      # Holds the original values that this object contained.
      attr_hash :original
      # Holds changes from the previous set before a reset was called
      attr_hash :previous, default: {}
      # Holds a reference to the model or object that the changeset is for.
      attr_of BBLib::Effortless, :object, arg_at: 0

      # before :reset, :set_previous
      after :object=, :reset

      # Returns a hash showing what values have been changed. If the hash is empty
      # there have been no changes.
      def diff
        return {} unless object
        return object.serialize unless object.id
        object.serialize.hmap do |k, v|
          v == original[k] ? nil : [k, v]
        end
      end

      alias changes diff

      # Returns true if there are currently any differences between the original
      # and the new object.
      def diff?
        !diff.empty? || associations_changed?
      end

      alias changes? diff?

      # Called when a new object is set. This causes the changeset to reset the
      # original values to the object itself. This is also called whenether an
      # object is saved to indicate that those changes have been committed.
      def reset
        set_previous if self.original
        self.original = object.serialize.dup.hmap { |k, v| [k, (v.dup rescue v)] }
      end

      # Checks to see if any of the associations for this object have pending
      # changes.
      def associations_changed?
        return false unless object.is_a?(BlockStack::Model)
        return true unless object.exist?
        old_obj = object.class.find(object.id)
        return false unless old_obj
        object.associations.any? do |association|
          name = association.method_name
          object.send(name) != old_obj.send(name)
        end
      end

      def set_previous
        self.previous = diff.hmap do |k, _v|
          [k, original[k].dup]
        end.dup
      end
    end
  end
end
