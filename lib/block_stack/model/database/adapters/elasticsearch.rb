require_relative '../util/elasticsearch/util'

module BlockStack
  module Models
    module Elasticsearch

      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, BlockStack::Model)
        base.send(:include, InstanceMethods)
        base.send(:attr_str, :_id, :_type, :_index, serialize: false, dformed_field: false)
        base.send(:attr_bool, :increment_id, default: true, singleton: true, dformed_field: false)
        base.send(:attr_str, :document_type, default: 'doc', singleton: true, dformed_field: false)
        base.send(:attr_int, :max_query_size, default: 10_000, singleton: true, dformed_field: false)
        base.send(:bridge_method, :next_id, :increment_id?)
      end

      def self.type
        :elasticsearch
      end

      def self.client
        ['Elasticsearch::Client', 'Elasticsearch::Transport::Client']
      end

      BlockStack::Adapters.register(self)

      def self.build_db(type, *args)
        require_relative '../util/elasticsearch/client'
        ::Elasticsearch::Client.new(*args)
      end

      module ClassMethods
        def find(query)
          query = if query.is_a?(Hash)
            Util.hash_to_basic_and_query(query)
          else
            Util.basic_or_query(
              { ids: { type: document_type, values: [query].flatten } },
              { match: { id: query } }
            )
          end
          get_query_results(query).first
        end

        def all(&block)
          get_query_results(query: { match_all: {} })
        end

        def find_all(query, &block)
          return all if query.nil? || query.empty?
          query = Util.hash_to_basic_and_query(query)
          get_query_results(query)
        end

        def first
          get_query_results(size: 1, query: { match_all: {} }).first
        end

        def last
          get_query_results(size: 1, sort: :desc, query: { match_all: {} }).first
        end

        def count(query = nil)
          query = Util.hash_to_basic_and_query(query) if query
          query = { query: { match_all: {} } } unless query
          execute_query(query).hpath('hits.total').first.to_i
        end

        def average(field, query = {})
          get_agg_result(field, :avg, query)
        end

        def min(field, query = {})
          get_agg_result(field, :min, query)
        end

        def max(field, query = {})
          get_agg_result(field, :max, query)
        end

        def sum(field, query = {})
          get_agg_result(field, :sum, query)
        end

        def distinct(field, query = {})
          agg_query = Util.basic_agg_query(field, :terms)
          agg_query = Util.hash_to_basic_and_query(query).merge(agg_query) if query
          execute_query(agg_query).hpath('aggregations.agg.buckets.[0..-1].key')
        end

        def sample(query = {})
          query = {
            query: {
              function_score: {
                random_score: {}
              }
            }
          }
          get_query_results(query).first
        end

        def next_id
          (max(:id) || 0) + 1
        end

        def execute_query(query)
          query = { size: max_query_size }.merge(query)
          dataset.search(query)
        end

        # TODO Add default sort
        def get_query_results(query)
          hits = execute_query(query).hpath('hits.hits').first
          return [] unless hits && !hits.empty?
          hits.map do |hit|
            hit['_source'].expand.merge(hit.only('_id', '_type', '_index')).kmap do |key|
              key.to_s.gsub('@', '_').to_sym
            end
          end
        end

        def get_agg_result(field, agg_type, query = {})
          agg_query = Util.basic_agg_query(field, agg_type)
          agg_query = Util.hash_to_basic_and_query(query).merge(agg_query) if query
          execute_query(agg_query).hpath('aggregations.agg.value').first
        end

      end

      module InstanceMethods

        def retrieve_id
          return id if self.id
          next_id
        end

        protected

        # TODO: Parse responses
        def adapter_save
          self.id = retrieve_id unless self.id
          dataset.save(serialize, _id)
        end

        # TODO: Error handling
        def adapter_delete
          if _id
            dataset.delete(_id)['result'] == 'deleted'
          elsif id
            dataset.delete_by(id: id)['result'] == 'deleted'
          else
            false
          end
        end
      end
    end
  end
end
