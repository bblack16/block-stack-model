module BlockStack
  module Models
    module Elasticsearch
      module ElasticsearchUtil
        def self.basic_or_query(*queries)
          bool_query(should: queries, minimum_should_match: 1)
        end

        def self.basic_and_query(*queries)
          bool_query(must: queries)
        end

        def self.bool_query(sub_query)
          {
            query: {
              bool: sub_query
            }
          }
        end
      end
    end
  end
end
