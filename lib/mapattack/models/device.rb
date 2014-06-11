module Mapattack
  class Device < Model

    attr_accessor :gt_sesion

    class << self

      def create_new_ago_device

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
        Device.new(dts[:device_id]).set_profile

        # respond with id and "access_token"
        #
        {
          device_id: dts[:device_id],
          access_token: at
        }
      end

    end

    def initialize opts = {}
      super
      self.gt_session = opts[:gt_session]
    end

    def team_for_game_id game
      team_membership = redis.multi [
        [:sismember, GAME_ID_RED_MEMBERS_KEY % game.id, self.id],
        [:sismember, GAME_ID_BLUE_MEMBERS_KEY % game.id, self.id]
      ]

      return :red if team_membership[0]
      return :blue if team_membership[1]
      return nil
    end

    def choose_team_for game
      team = team_for_game_id game
      if team.nil?
        counts = game.team_counts
        if counts[:red] < counts[:blue]
          team = :red
        else
          team = :blue
        end
      end
      redis.set DEVICE_TEAM_KEY % team
      return team
    end

    def set_game_tag game
      (gt_session || Mapattack.geotrigger).post 'device/update', setTags: GAME_ID_TAG % game.id
    end

    def active_game
      active_game = redis.get DEVICE_ACTIVE_GAME_KEY % id
      active_game_data = JSON.parse(active_game) || { game_id: nil, team: nil }
      responses = redis.multi [
        [:hget, GAME_ID_TEAM_KEY % [active_game_data['game_id'], active_game_data['team']]],
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
      redis.srem GAME_ID_TEAM_MEMBERS_KEY % [ag['game_id'], ag['team']] if ag = self.active_game

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

  end
end
