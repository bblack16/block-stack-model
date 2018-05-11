module BlockStack
  module Validations
    class Exist < Validation

      protected

      def validate(value, expression)
        !value.nil?
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} exist"
      end

    end
  end
end
