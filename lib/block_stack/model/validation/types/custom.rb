module BlockStack
  module Validations
    class Custom < Validation

      protected

      def validate(value, expression)
        return false unless expression.is_a?(Proc)
        expression.call(value)
      end

    end
  end
end
