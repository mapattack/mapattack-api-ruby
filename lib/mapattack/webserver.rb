module Mapattack
  class Webserver < Angelo::Base
    include Helpers
    include RedisPoolified

    %w[ device
        board
        game
    ].each {|mod| require "mapattack/webserver/#{mod}_routes"}
    include DeviceRoutes
    include BoardRoutes
    include GameRoutes

    content_type :json

    websocket '/ws' do |s|
      # WebsocketHandler.new s
    end

  end
end
