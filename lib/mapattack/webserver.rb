module Mapattack
  class Webserver < Angelo::Base
    include Helpers

    %w[ device
        board
        game
    ].each {|mod| require "mapattack/webserver/#{mod}"}
    include Device
    include Board
    include Game

    content_type :json

    websocket '/ws' do |s|
      # WebsocketHandler.new s
    end

    # ---

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
