require 'faraday'
require 'json'

module ChatWork
  class Client
    def initialize(api_key, api_base, api_version)
      default_header = {
        'X-ChatWorkToken' => api_key,
        'User-Agent' => "ChatWork#{api_version} RubyBinding/#{ChatWork::VERSION}"
      }

      @conn = Faraday.new("#{api_base}#{api_version}", headers: default_header) do |builder|
        builder.request :url_encoded
        builder.adapter Faraday.default_adapter
      end
      @api_version = api_version
    end

    def handle_response(response)
      case response.status
      when 429 # Too many requests error
        return ChatWork::ChatWorkError.from_response(response.status, response.body), response.headers['x-ratelimit-remaining']
      when 204 # New messages don't exist
        return ChatWork::ChatWorkError.from_response(response.status, response.body), response.headers['x-ratelimit-remaining']
      when 200..299
        begin
          return JSON.parse(response.body), response.headers['x-ratelimit-remaining']
        rescue JSON::ParserError => e
          raise ChatWork::APIConnectionError.new("Response JSON is broken. #{e.message}: #{response.body}", e)
        end
      else
        ChatWork::ChatWorkError.from_response(response.status, response.body)
      end
    end

    Faraday::Connection::METHODS.each do |method|
      define_method(method) do |url, *args|
        begin
          response = @conn.__send__(method, @api_version + url, *args)
        rescue Faraday::Error::ClientError => e
          raise ChatWork::APIConnectionError.faraday_error(e)
        end
        handle_response(response)
      end
    end
  end
end
