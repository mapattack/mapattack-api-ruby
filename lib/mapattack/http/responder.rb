module Mapattack
  module HTTP
    class Responder
      include Celluloid::Logger

      GET =  'GET'.freeze
      POST = 'POST'.freeze

      DEFAULT_HEADERS = {
        'Content-Type' => 'application/json'
      }

      attr_writer :connection

      def request= request, do_respond = true
        @params = nil
        @request = request
        @body = handle_request || {}
        respond if do_respond
      end

      def handle_request
        raise NotImplementedError.new "#{self.class} must override #handle_request"
      end

      def params
        @params ||= case @request.method
                    when GET
                      (@request.query_string || '').split('&').reduce(Responder.symhash) do |p, kv|
                        key, value = kv.split('=').map {|s| CGI.escape s}
                        p[key] = value
                        p
                      end
                    when POST
                      body = @request.body.to_s
                      body = '{}' if body.empty?
                      Responder.symhash.merge! JSON.parse body
                    end
        @params
      end

      def respond headers = nil
        @connection.respond :ok, (headers || DEFAULT_HEADERS), @body.to_json
      end

      def self.symhash
        Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
      end

      def redis
        @redis ||= Redis.new
        @redis
      end

      class Redis
        def method_missing meth, *args
          Mapattack.redis {|r| r.__send__ meth, *args}
        end
      end

    end

  end
end
