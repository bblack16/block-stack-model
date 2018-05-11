
module BlockStack
  class Validation
    include BBLib::Effortless
    include BBLib::TypeInit

    MODES = [:any, :all, :none].freeze

    attr_sym :attribute, required: true, arg_at: 0
    attr_element_of MODES, :mode, default: MODES.first
    attr_ary :expressions, default: nil, allow_nil: true, arg_at: :block
    attr_bool :inverse, default: false
    attr_str :message, default: ''
    attr_bool :allow_nil, default: false

    def self.types
      descendants.map(&:type)
    end

    # Called and passed a model. If the model passes this validation true is
    # returned, otherwise false.
    # The default implementation here should generally not be changed in child
    # classes of Validation, as overwriting :validate is all that should be
    # required.
    def valid?(model)
      @model = model
      value = model.attribute(attribute)
      return true if value.nil? && allow_nil?
      mode_method = (mode == :none ? :any : mode)
      valid = if expressions.empty?
        validate(value, nil)
      else
        valid = expressions.send("#{mode_method}?") do |exp|
          validate(value, exp)
        end
      end
      inverse? ? !valid : valid
    end

    # Converts snake cased attribute names to titled cased names.
    # This is a util method for use in the default message methods of child
    # classes.
    def clean_attribute_name
      attribute.to_s.gsub('_', '').title_case
    end

    protected

    # The parent validation returns false always as it should never be used.
    # This class is abstract and is meant to be inherited from.
    # You can also access to model object via the @model instance variable.
    def validate(value, expression)
      # Perform validation steps on the model and then return true of false
      false
    end

    def default_message
      # Should return a stringthat represents why the model is invalid, if it is.
      # This is used unless a custom message is passed in to the message
      # attribute.
      "Field #{attribute} is not valid."
    end

  end

  require_all(File.expand_path('../types', __FILE__))
end
