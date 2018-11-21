require 'elasticsearch'
require_relative 'dataset'

# This monkey patches the Elasticsearch transport client to include methods to
# generate and return a dataset
module Elasticsearch
  module Transport
    class Client

      def dataset(index, type = '*')
        Elasticsearch::Dataset.new(self, index, type)
      end

      alias_method :[], :dataset

    end
  end
end
