module BlockStack
  module Validations
    class In < Validation

      protected

      def validate(value, expression)
        [expression].flatten(1).include?(value)
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} be in #{expressions.join_terms(mode == :all ? :and : :or)}"
      end

    end
  end
end
