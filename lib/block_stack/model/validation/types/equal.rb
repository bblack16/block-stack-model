module BlockStack
  module Validations
    class Equal < Validation

      protected

      def validate(value, expression)
        expression == value
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} exist"
      end

    end
  end
end
