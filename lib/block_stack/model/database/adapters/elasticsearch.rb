require_relative '../util/elasticsearch_util'

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
        require 'elasticsearch'
        ::Elasticsearch::Client.new(*args)
      end

      module ClassMethods

        def find(query)
          query = ElasticsearchUtil.basic_or_query(
            { ids: { type: document_type, values: [query].flatten } },
            { match: { id: query } }
          ) unless query.is_a?(Hash)
          get_query_results(query).first
        end

        def all(opts = {}, &block)
          get_query_results(query: { match_all: {} })
        end

        def find_all(query, &block)
          return all if query.nil? || query.empty?
          query = ElasticsearchUtil.basic_and_query(
            *query.map do |field, expression|
              { match: { field => expression } }
            end
          )
          get_query_results(query)
        end

        # def first
        #   create_query_dataset.first
        # end
        #
        # def last
        #   create_query_dataset.sort('$natural': -1).first
        # end
        #
        # def count(query = {})
        #   create_query_dataset(query).count
        # end
        #
        # def average(field, query = {})
        #   BBLib.average(create_query_dataset(query).distinct(field).to_a)
        # end
        #
        # def min(field, query = {})
        #   create_query_dataset(query).sort(field => 1).limit(1).first[field]
        # end
        #
        # def max(field, query = {})
        #   create_query_dataset(query).sort(field => -1).limit(1).first[field]
        # end
        #
        # def sum(field, query = {})
        #   create_query_dataset(query).distinct(field).to_a.sum
        # end
        #
        # def distinct(field, query = {})
        #   create_query_dataset.distinct(field)
        # end

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

        # TODO
        def next_id
          0
        end

        def execute_search(query)
          query = { size: max_query_size }.merge(query)
          logger.debug("[Search] #{query}")
          db.search(index: dataset_name, body: query)
        end

        # TODO Add default sort
        def get_query_results(query)
          execute_search(query).hpath('hits.hits').first.map do |hit|
            hit['_source'].expand.merge(hit.only('_id', '_type', '_index')).kmap do |key|
              key.to_s.gsub('@', '_').to_sym
            end
          end
        end

      end

      module InstanceMethods

        def retrieve_id
          return id if self.id
          next_id
        end

        def index_keys
          if self._id
            {_id: self._id }
          else
            config.unique_by.hmap do |attribute|
              [attribute.to_sym, attribute(attribute)]
            end
          end
        end

        protected

        # TODO: Parse responses
        def adapter_save
          db.index(index: dataset_name, type: document_type, id: _id, body: serialize)
        end

        # TODO: Error handling
        # TODO: Parse responses
        def adapter_delete
          if _id
            db.delete(index: dataset_name, type: document_type, id: _id)
          elsif id
            db.delete(index: dataset_name, q: "id:#{id}")
          else
            false
          end
        end
      end
    end
  end
end
