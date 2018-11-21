# The Elasticsearch gem cannot be subdivided into datasets like most otherwise
# database clients so this class provides the a wrapper to simulate this functionality
# so that it can be treated the same as other adapters.
module Elasticsearch
  class Dataset
    include BBLib::Effortless

    attr_of Transport::Client, :client, arg_at: 0
    attr_str :index, arg_at: 1
    attr_str :type, default: 'doc', arg_at: 2
    attr_bool :log_results, default: false

    def search(query, opts = {})
      log(query, action: :search)
      client.search(opts.merge(index: index, body: query)).tap do |result|
        log(result, action: :search) if log_results?
        log("(#{result.hpath('took').first} ms) Query returned #{BBLib.plural_string(result.hpath('hits.total').first, 'result')}.", action: :search)
      end
    rescue Elasticsearch::Transport::Transport::Errors::NotFound, Elasticsearch::Transport::Transport::Errors::BadRequest => e
      log(e, :warn, action: :search)
      []
    end

    def save(body, id = nil)
      args = { index: index, type: type, body: body }
      args[:id] = id if id
      client.index(args)
    end

    # This delete is meant for the Elasticsearch document id
    def delete(_id)
      log(:"Deleting document #{_id}", action: :delete)
      client.delete(index: index, type: type, id: _id)
    end

    # This delete is meant for deleting by some other criteria like a custom id
    def delete_by(query)
      client.delete(index: index, q: Dataset.to_query_string(query))
    end

    def self.to_query_string(query)
      case query
      when Hash
        query.map do |key, value|
          "#{key}:#{value.to_s.include?(' ') ? "\"#{value}\"" : value}"
        end.join(' AND ')
      else
        query.to_s
      end
    end

    def log(message, sev = :debug, action: nil)
      BlockStack.logger.send(sev, "#{[:elasticsearch, action, index].join('/')} - #{message}")
    end
  end
end
