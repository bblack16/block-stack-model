module BlockStack
  module Validations
    class Unique < Validation

      protected

      def validate(value, expression)
        if @model.exist?
          !@model.class.find_all(attribute => value).any? do |match|
            match != @model
          end
        else
          !@model.class.distinct(attribute).include?(value)
        end
      end

      def default_message
        "#{clean_attribute_name} must#{inverse? ? ' not' : nil} be unique"
      end

    end
  end
end
