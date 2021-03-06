module BlockStack
  module Validations
    class LessThanOrEqual < Validation

      protected

      def validate(value, expression)
        value <= expression
      rescue NoMethodError, ArgumentError => _e
        false
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} be less than or equal to #{expressions.join_terms(mode == :all ? :and : :or)}"
      end

    end
  end
end
