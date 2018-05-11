module BlockStack
  module Validations
    class EndWith < Validation

      protected

      def validate(value, expression)
        value.to_s.end_with?(expression.to_s)
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} end with #{expressions.join_terms(mode == :all ? :and : :or)}"
      end

    end
  end
end
