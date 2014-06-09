module Mapattack
  class Board

    attr_accessor :id

    class << self

      def for obj
        case obj
        when Mapattack::Game
          self.class.new id: Mapattack.redis {|r| r.get GAME_ID_BOARD_KEY % obj.id}
        when Mapattack::Device
          raise NotImplementedError
        end
      end

    end

    def initialize opts = {}
      self.id = opts[:id]
    end

  end
end

