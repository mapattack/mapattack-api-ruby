module Mapattack
  class Game < Model

    attr_accessor :board

    def initialize opts = {}
      super
      self.board = opts[:board]
      self.id ||= Mapattack.generate_id 16
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
      ps = redis.multi [
        [:smembers, GAME_ID_RED_MEMBERS_KEY % id],
        [:smembers, GAME_ID_BLUE_MEMBERS_KEY % id]
      ]
      { red: ps[0], blue: ps[1] }
    end

    def active?
      redis.get(GAME_ID_ACTIVE_KEY % id) == '1'
    end

    def scores_for device
      ag = device.active_game
      rs = redis.multi [
        [:hvals, GAME_ID_RED_KEY % ag[:game_id]],
        [:hvals, GAME_ID_BLUE_KEY % ag[:game_id]]
      ]
      { player_score: ag[:device_score],
        red_score: rs[0].reduce(:+),
        blue_score: rs[1].reduce(:+) }
    end

    def stats

      # s = redis.multi do |r|
      #   r.hvals GAME_ID_RED_KEY % id
      #   r.scard GAME_ID_RED_MEMBERS_KEY % id
      #   r.hvals GAME_ID_BLUE_KEY % id
      #   r.scard GAME_ID_BLUE_MEMBERS_KEY % id
      #   r.get GAME_ID_ACTIVE_KEY % id
      # end

      # rs, rp, bs, bp, a = redis.pipelined [
      s = redis.pipelined [
        [:hvals, GAME_ID_RED_KEY % id],
        [:scard, GAME_ID_RED_MEMBERS_KEY % id],
        [:hvals, GAME_ID_BLUE_KEY % id],
        [:scard, GAME_ID_BLUE_MEMBERS_KEY % id],
        [:get, GAME_ID_ACTIVE_KEY % id]
      ]

      # {
      #   red: {
      #     score: rs.value.reduce(0, &:+),
      #     num_players: rp.value
      #   },
      #   blue: {
      #     score: bs.value.reduce(0, &:+),
      #     num_players: bp.value
      #   },
      #   active: a.value == 1
      # }

      {
        game_id: id,
        red_team: s[1].value,
        red_score: s[0].value.reduce(0, &:+),
        blue_team: s[3].value,
        blue_score: s[2].value.reduce(0, &:+),
        active: (s[4].value == '1')
      }
    end

  end
end
