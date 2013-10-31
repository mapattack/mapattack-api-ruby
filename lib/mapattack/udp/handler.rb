module Mapattack
  module UDP
    class Handler
      include Celluloid::IO

      def initialize service
        @service = service
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
