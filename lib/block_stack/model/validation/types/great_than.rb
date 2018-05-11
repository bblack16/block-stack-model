module BlockStack
  module Validations
    class GreaterThan < Validation

      protected

      def validate(value, expression)
        value > expression
      rescue NoMethodError, ArgumentError => _e
        false
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} be greater than #{expressions.join_terms(mode == :all ? :and : :or)}"
      end

    end
  end
end
