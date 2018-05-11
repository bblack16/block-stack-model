module BlockStack
  module Validations
    class Contains < Validation

      protected

      def validate(value, expression)
        value.to_s.include?(expression.to_s)
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} be contained in #{expressions.join_terms(mode == :all ? :and : :or)}"
      end

    end
  end
end
