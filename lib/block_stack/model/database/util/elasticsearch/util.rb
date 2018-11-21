module BlockStack
  module Models
    module Elasticsearch
      module Util
        def self.basic_or_query(*queries)
          bool_query(should: queries, minimum_should_match: 1)
        end

        def self.basic_and_query(*queries)
          bool_query(must: queries)
        end

        def self.hash_to_basic_and_query(hash)
          basic_and_query(
            *hash.map do |field, expression|
              { match: { field => expression.nil? ? '' : expression } }
            end
          )
        end

        def self.basic_agg_query(field, agg_type)
          {
            size: 0,
            aggs: {
              agg: {
                agg_type => {
                  field: field
                }
              }
            }
          }
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
