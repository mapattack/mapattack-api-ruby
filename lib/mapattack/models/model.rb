module Mapattack
  class Model
    include RedisPoolified

    attr_accessor :id

    def initialize opts = {}
      self.id = opts[:id]
    end

  end
end
