module BlockStack
  module Validations
    class StartWith < Validation

      protected

      def validate(value, expression)
        value.to_s.start_with?(expression.to_s)
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} exist"
      end

    end
  end
end
