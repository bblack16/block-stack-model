module BlockStack
  module Validations
    class CustomModel < Validation

      protected

      def validate(value, expression)
        return false unless expression.is_a?(Proc)
        expression.call(@model)
      end

    end
  end
end
