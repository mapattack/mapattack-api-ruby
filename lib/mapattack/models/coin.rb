module Mapattack
  class Coin

    attr_accessor :id, :game

    class << self

      def data_for game
        Mapattack.redis {|r| r.hgetall GAME_ID_COIN_DATA_KEY % game.id}
      end

      def states_for game
        Mapattack.redis {|r| r.hgetall GAME_ID_COINS_KEY % game.id}
      end

    end

    def initialize opts = {}
      self.id = opts[:id]
      self.game = opts[:game]
    end

  end
end
