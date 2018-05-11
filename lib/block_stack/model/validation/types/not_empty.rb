module BlockStack
  module Validations
    class NotEmpty < Validation

      protected

      def validate(value, expression)
        !(value.nil? || value.respond_to?(:empty?) && value.empty?)
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? nil : ' not'} be empty."
      end

    end
  end
end
