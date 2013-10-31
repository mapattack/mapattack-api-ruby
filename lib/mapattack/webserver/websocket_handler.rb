module Mapattack
  class WebsocketHandler
    include Celluloid::Logger

    WEBSOCKET_GAME_ID = 'game_id'.freeze

    def initialize socket
      @socket = socket
      begin
        handle
      rescue => e
        warn e.message
        @socket.close if @socket
        @redis.quit if @redis
      end
      debug "here"
    end

    def handle

      # prompt for game_id
      #
      @socket.write WEBSOCKET_GAME_ID.dup

      # read back game_id, interpolate into channel name
      #
      @channel = REDIS_GAME_CHANNEL % JSON.parse(@socket.read)[WEBSOCKET_GAME_ID]

      # fire up a new redis connection
      #
      @redis = Redis.new driver: :celluloid

      # subscribe to the channel, piping messages back to websocket
      #
      @redis.subscribe(@channel) do |on|
        on.message do |chan, msg|
          @socket.write msg
        end
      end
    end

  end
end
