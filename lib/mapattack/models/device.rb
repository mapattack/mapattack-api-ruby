module Mapattack
  class Device < Model

    class << self

      def create_new_ago_device name, avatar

        # create a new "access_token" to map to real AGO oauth data
        #
        at = Mapattack.generate_id 48

        # register for AGO oauth data and save it
        #
        dts = Mapattack.arcgis.register
        dts = {
          device_id: dts['device']['deviceId'],
          access_token: dts['deviceToken']['access_token'],
          refresh_token: dts['deviceToken']['refresh_token']
        }
        redis.set (DEVICE_TOKENS_KEY % at), dts.to_json

        # save profile info
        #
        Device.new(id: dts[:device_id]).set_profile name, avatar

        # respond with id and "access_token"
        #
        {
          device_id: dts[:device_id],
          access_token: at
        }
      end

    end

    def team_for_game game
      team_membership = redis.multi [
        [:sismember, GAME_ID_RED_MEMBERS_KEY % game.id, self.id],
        [:sismember, GAME_ID_BLUE_MEMBERS_KEY % game.id, self.id]
      ]

      return :red if team_membership[0]
      return :blue if team_membership[1]
      return nil
    end

    def choose_team_for game
      team = team_for_game game
      if team.nil?
        counts = game.team_counts
        if counts[:red] < counts[:blue]
          team = :red
        else
          team = :blue
        end
      end
      redis.set DEVICE_TEAM_KEY % id, team
      return team
    end

    def set_game_tag game
      Mapattack.geotrigger.post 'device/update', deviceIds: [id], setTags: GAME_ID_TAG % game.id
    end

    def active_game
      active_game = redis.get DEVICE_ACTIVE_GAME_KEY % id
      active_game_data = active_game ? JSON.parse(active_game) : { game_id: nil, team: nil }
      responses = redis.multi [
        [:hget, GAME_ID_TEAM_KEY % [active_game_data['game_id'], active_game_data['team']], DEVICE_ID_KEY % id],
        [:get, DEVICE_PROFILE_ID_KEY % id]
      ]
      profile = JSON.parse responses[1]
      {
        game_id: active_game_data['game_id'],
        device_team: active_game_data['team'],
        device_score: responses[0].to_i,
        device_name: profile['name']
      }
    end

    def set_active_game game, team

      # remove from other active game if there is one
      #
      if ag = self.active_game
        redis.srem GAME_ID_TEAM_MEMBERS_KEY % [ag['game_id'], ag['team']], id
      end

      other_team = team.to_sym == :red ? :blue : :red

      # set current active game to given one
      #
      redis.multi [
        [:set, DEVICE_ACTIVE_GAME_KEY % id, {game_id: game.id, team: team}.to_json],
        [:srem, GAME_ID_TEAM_MEMBERS_KEY % [game.id, other_team], id],
        [:sadd, GAME_ID_TEAM_MEMBERS_KEY % [game.id, team], id]
      ]
    end

    def profile
      @profile ||= JSON.parse redis.get DEVICE_PROFILE_ID_KEY % id
    end

    def set_profile name, avatar
      profile_json = {name: name, avatar: avatar}.to_json
      redis.set DEVICE_PROFILE_ID_KEY % id, profile_json
    end

    def udp_info
      JSON.parse redis.get DEVICE_UDP_ID_KEY % id rescue nil
    end

    def set_udp_info address, port
      redis.set DEVICE_UDP_ID_KEY % id, {address: address, port: port}.to_json
    end

    def location
      JSON.parse redis.get DEVICE_LOCATION_ID_KEY % id rescue nil
    end

    def set_location l
      redis.set DEVICE_LOCATION_ID_KEY % id, l.to_json
    end

  end
end
