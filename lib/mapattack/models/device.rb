module Mapattack
  class Device

    attr_accessor :id, :gt_sesion

    def initialize opts = {}
      self.id = opts[:id]
      self.gt_session = opts[:gt_session]
    end

    def team_for_game_id game
      team_membership = Mapattack.redis do |r|
        r.multi do
          r.sismember GAME_ID_RED_MEMBERS_KEY % game.id, self.id
          r.sismember GAME_ID_BLUE_MEMBERS_KEY % game.id, self.id
        end
      end

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
      Mapattack.redis {|r| r.set DEVICE_TEAM_KEY % team}
      return team
    end

    def set_game_tag game
      (gt_session || Mapattack.geotrigger).post 'device/update', setTags: GAME_ID_TAG % game.id
    end

    def active_game
      active_game = Mapattack.redis {|r| r.get DEVICE_ACTIVE_GAME_KEY % id}
      active_game_data = JSON.parse(active_game) || { game_id: nil, team: nil }
      responses = Mapattack.redis do |r|
        r.multi do
          r.hget GAME_ID_TEAM_KEY % [active_game_data['game_id'], active_game_data['team']]
          r.get DEVICE_PROFILE_ID_KEY % id
        end
      end
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
      Mapattack.redis {|r| r.srem GAME_ID_TEAM_MEMBERS_KEY % [ag['game_id'], ag['team']]} if ag = self.active_game

      other_team = team.to_sym == :red ? :blue : :red

      # set current active game to given one
      #
      Mapattack.redis do |r|
        r.multi do
          r.set DEVICE_ACTIVE_GAME_KEY % id, {game_id: game.id, team: team}.to_json
          r.srem GAME_ID_TEAM_MEMBERS_KEY % [game.id, other_team], id
          r.sadd GAME_ID_TEAM_MEMBERS_KEY % [game.id, team], id
        end
      end

    end

    def profile
      @profile ||= JSON.parse Mapattack.redis {|r| r.get DEVICE_PROFILE_ID_KEY % id}
    end

  end
end
