module Mapattack
  class Game < Model

    attr_accessor :board

    def initialize opts = {}
      super
      self.board = opts[:board]
      self.id ||= Mapattack.generate_id
    end

    def team_counts
      counts = redis.multi [
        [:scard, GAME_ID_RED_MEMBERS_KEY % self.id],
        [:scard, GAME_ID_BLUE_MEMBERS_KEY % self.id]
      ]
      { red: counts[0], blue: counts[1] }
    end

    def activate!
      redis.set GAME_ID_ACTIVE_KEY % id, 1
    end

    def data
      JSON.parse redis.get GAME_ID_DATA_KEY % id
    end

    def players
      ps = r.multi [
        [:smembers, GAME_ID_RED_MEMBERS_KEY % id],
        [:smembers, GAME_ID_BLUE_MEMBERS_KEY % id]
      ]
      { red: ps[0], blue: ps[1] }
    end

    def active?
      redis.get(GAME_ID_ACTIVE_KEY % id) == 1
    end

  end
end
