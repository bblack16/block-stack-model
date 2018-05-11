module BlockStack
  module Validations
    class Matches < Validation

      protected

      def validate(value, expression)
        return false unless expression.is_a?(Regexp)
        value.to_s =~ expression
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} match #{expressions.map(&:inspect).join_terms(mode == :all ? :and : :or)}"
      end

    end
  end
end
