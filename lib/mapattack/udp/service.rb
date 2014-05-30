module Mapattack
  module UDP
    class Service
      include Celluloid::IO

      RECV_MAXLEN = 576

      finalizer :finalize

      def initialize
        @socket = Celluloid::IO::UDPSocket.new
        @socket.bind '0.0.0.0', CONFIG[:udp_port]
        async.listen
      end

      def listen
        loop { async.handle_data *@socket.recvfrom(RECV_MAXLEN) }
      end

      def finalize
        @socket.close if @socket
      end

      def handle_data data, server_inet_addr
        Mapattack.redis {|r| r.publish REDIS_GAME_CHANNEL % 'foo', data}
      end

      def build_location_update data
        accuracy = Integer(data['accuracy'])
        accuracy = 5 if accuracy <= 30
        {
          locations: [
            {
              timestamp: Integer(data['timestamp']),
              latitude:  Float(data['latitude']),
              longitude: Float(data['longitude']),
              accuracy:  accuracy,
              speed:     Integer(data['speed']),
              bearing:   Integer(data['bearing'])
            }
          ]
        }
      end

    end
  end
end
