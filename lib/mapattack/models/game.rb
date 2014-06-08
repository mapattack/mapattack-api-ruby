module Mapattack
  class Game

    attr_accessor :id, :board

    def initialize opts = {}
      self.id = opts[:id] || Mapattack.generate_id
      self.board = opts[:board]
    end

    def team_counts
      counts = Mapattack.redis do |r|
        r.multi do
          r.scard GAME_ID_RED_MEMBERS_KEY % self.id
          r.scard GAME_ID_BLUE_MEMBERS_KEY % self.id
        end
      end
      { red: counts[0], blue: counts[1] }
    end

  end
end
