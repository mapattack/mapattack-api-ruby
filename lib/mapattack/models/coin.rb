module Mapattack
  class Coin

    attr_accessor :game

    class << self

      def data_for game
        redis.hgetall GAME_ID_COIN_DATA_KEY % game.id
      end

      def states_for game
        redis.hgetall GAME_ID_COINS_KEY % game.id
      end

    end

    def initialize opts = {}
      super
      self.game = opts[:game]
    end

  end
end
