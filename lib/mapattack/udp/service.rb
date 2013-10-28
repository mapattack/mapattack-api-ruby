module Mapattack
  module UDP
    class Service
      include Celluloid::IO

      RECV_MAXLEN = 576

      finalizer :finalize
      attr_reader :websockets

      def initialize
        @socket = Celluloid::IO::UDPSocket.new
        @socket.bind '0.0.0.0', CONFIG[:udp_port]
        @handler_pool = Handler.pool args: [Celluloid::Actor.current]
        async.listen
      end

      def << websocket
        @websockets ||= []
        @websockets << websocket
      end

      def listen
        loop {
          @handler_pool.async.handle_data *@socket.recvfrom(RECV_MAXLEN)
        }
      end

      def finalize
        @socket.close if @socket
      end

    end
  end
end
