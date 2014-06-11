module Mapattack
  class Board < Model

    class << self

      def for obj
        case obj
        when Game
          self.class.new id: redis.get(GAME_ID_BOARD_KEY % obj.id)
        when Device
          raise NotImplementedError
        end
      end

    end

  end
end

