module Mapattack
  class Webserver < Reel::Server
    include Celluloid::Logger

    GET =  'GET'.freeze
    POST = 'POST'.freeze

    def initialize host = '127.0.0.1', port = 8080
      info "Mapattack::Webserver#initialize on #{host}:#{port}"
      create_responders
      super host, port, &method(:on_connection)
    end

    def on_connection connection
      connection.each_request do |request|
        if request.websocket?
          route_websocket request.websocket
        else
          route_request connection, request
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

    def route_websocket websocket
      Mapattack.udp << websocket
    end

    def create_responders
      @responders = {
        '/device/register' =>      Mapattack::HTTP::Device::Register.new,
        '/device/register_push' => Mapattack::HTTP::Device::RegisterPush.new,
        '/device/info' =>          Mapattack::HTTP::Device::Info.new,
        '/board/list' =>           Mapattack::HTTP::Board::List.new
      }
    end

  end
end
