module Mapattack
  class Webserver < Reel::Server
    include Celluloid::Logger

    def initialize host = '127.0.0.1', port = 8080
      info "Mapattack::Webserver#initialize on #{host}:#{port}"
      create_responders
      super host, port, &method(:on_connection)
    end

    def on_connection connection
      while request = connection.request
        case request
        when Reel::Request
          route_request connection, request
        when Reel::WebSocket
          raise NotImplementedError
        end
      end
    end

    def route_request connection, request

      case request.path
      when '/ping'
        connection.respond :ok, {'Content-Type' => 'text/plain'}, 'pong'
      else

        if @responders[request.path]
          @responders[request.path].connection = connection
          @responders[request.path].request = request
        else
          connection.respond :not_found
        end

      end

    end

    def create_responders
      @responders = {
        '/device/register' => Mapattack::HTTP::Device::Register.new
      }
    end

  end
end
