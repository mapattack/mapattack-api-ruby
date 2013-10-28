module Mapattack
  module HTTP
    class Responder
      include Celluloid::Logger

      EMPTY_JSON = '{}'.freeze

      DEFAULT_HEADERS = {
        'Content-Type' => 'application/json'
      }

      def self.symhash
        Hash.new {|hash,key| hash[key.to_s] if Symbol === key }
      end

      attr_writer :connection

      def initialize method, &block
        @method = method

      end

      def request= request, do_respond = true
        @params = nil
        @request = request
        begin
          @body = handle_request || {}
          respond if do_respond
        rescue => e
          error e.message
          # e.backtrace.each {|t| error t}
          ::STDERR.puts e.backtrace
          @connection.respond :internal_server_error, DEFAULT_HEADERS, {error: 'server error'}.to_json
        end
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
                      body = EMPTY_JSON if body.empty?
                      Responder.symhash.merge! JSON.parse body
                    end
        @params
      end

      def respond headers = nil
        @connection.respond :ok, (headers || DEFAULT_HEADERS), @body.to_json
      end

      def require_access_token &block
        if params[:access_token]
          ago_data = redis.get REDIS_DEVICE_TOKENS % params[:access_token]
          if ago_data
            @ago_data = Responder.symhash.merge! JSON.parse ago_data
            profile = JSON.parse redis.get REDIS_DEVICE_PROFILE % ago_data['device_id']
            @profile = Responder.symhash.merge! profile
            yield
          else
            { error: "no AGO oauth data found for '#{params[:access_token]}'" }
          end
        else
          { error: 'no access_token param' }
        end
      end

      def redis
        @redis ||= RedisPool.new
        @redis
      end

      class RedisPool
        def method_missing meth, *args
          Mapattack.redis {|r| r.__send__ meth, *args}
        end
      end

    end

  end
end
