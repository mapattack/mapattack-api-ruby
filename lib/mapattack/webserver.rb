require 'angelo/mustermann'

module Mapattack
  class Webserver < Angelo::Base
    include Angelo::Mustermann
    include Helpers
    include RedisPoolified

    %w[ device
        board
        game
    ].each {|mod| require "mapattack/webserver/#{mod}_routes"}
    include DeviceRoutes
    include BoardRoutes
    include GameRoutes

    @@report_errors = true
    @@log_level = Logger::DEBUG

    content_type :json

    post '/trigger/callback' do
      if params[:device][:deviceId]

        geo = params[:trigger][:condition][:geo]
        coin_id = params[:trigger][:triggerId]
        points = params[:trigger][:properties][:value]

        message = {
          type: 'coin',
          coin_id: coin_id,
          latitude: geo[:latitude],
          longitude: geo[:longitude],
          timestamp: params[:triggeredAt][:unix],
          value: points,
          device_id: params[:device][:deviceId]
        }

        device = Device.new id: params[:device][:deviceId]
        if vals = device.active_game
          game = Game.new id: vals[:game_id]

          if coin_owner = redis.hget(GAME_ID_COINS_KEY % vals[:game_id], coin_id)
            {error: 'coin already claimed'}
          else
            if team = device.team_for_game(game)

              debug "setting coin ownership for #{team}"
              message[:team] = team

              redis.multi do |r|
                r.hincrby GAME_ID_TEAM_KEY % [game.id, team], DEVICE_ID_KEY % device.id, points
                r.hset GAME_ID_COINS_KEY % game.id, coin_id, team
              end

              message.merge! game.scores_for(device)

              debug "coin event!: #{message}"
              redis.publish GAME_ID_KEY % game.id, message.to_json

              message
            else
              {error: 'ENOTEAM'}
            end
          end

        else
          {error: 'ENOGAME'}
        end
      end
    end

    @@game_ws = {}

    websocket '/viewer/:game_id' do |ws|
      websockets[params[:game_id].to_sym] << ws
      async :game_ws, params[:game_id] unless @@game_ws[params[:game_id]]
    end

    task :game_ws do |game_id|
      @@game_ws[game_id] = true
      r = ::Redis.new driver: :celluloid, host: CONFIG[:redis_host], port: CONFIG[:redis_port]
      catch :done do
        gids = game_id.to_sym
        r.subscribe GAME_ID_KEY % game_id do |on|
          on.message do |channel, msg|
            websockets[gids].each {|ws| ws.write msg}
            throw :done if JSON.parse(msg)['type'] == 'game_end' or websockets[gids].length == 0
          end
        end
      end
      r.quit
      @@game_ws.delete game_id
    end

  end
end
