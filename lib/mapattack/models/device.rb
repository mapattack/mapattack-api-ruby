module Mapattack
  class Device < Model

    attr_accessor :id

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

    def choose_team_for_game_id game
      team = team_for_game_id game
      if team.nil?
        counts = game.team_counts
        if counts[:red] < counts[:blue]
          team = :red
        else
          team = :blue
        end
      end
      return team
    end

  end
end
