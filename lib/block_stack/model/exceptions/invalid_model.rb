module BlockStack
  class InvalidModelError < BlockStack::Exception
    attr_reader :errors

    def initialize(model_or_msg = 'Invalid model', model = nil)
      case model_or_msg
      when BlockStack::Model
        @errors = model_or_msg.errors
        super("#{model_or_msg.clean_name} #{model_or_msg.id ? "#{model_or_msg.id} " : nil}could not be saved because the following fields were invalid: #{model_or_msg.errors.keys.join_terms}.")
      else
        @errors = model ? model.errors : {}
        super(model_or_msg.to_s)
      end
    end

  end
end
