module Mapattack::Webserver::Game
  def self.included base
    base.class_eval do

      get '/game/list' do

        games = []
        user_location = params[:longitude] ? Terraformer::Point.new(params[:longitude], params[:latitude]) : nil

        # get boards
        #
        Mapattack.geotrigger.triggers(tags: BOARD_TAG).each do |b|

          board_id = nil

          b.data['tags'].each do |t|
            board_id = $1 if t =~ /^board:([^:]+)$/
            break if board_id
          end

          if board_id

            geo = Terraformer.parse b.condition['geo']['geojson']

            board = {
              board_id: board_id,
              name: b.properties['title'] || 'Untitled Board',
              bbox: geo.bbox
            }

            board[:distance] = user_location.distance_to geo if user_location
            if game_id = Mapattack.redis {|r| r.get BOARD_ID_GAME_KEY % board_id}
              games << game_stats_for(game_id)
            end
          end

          { games: games }
        end

      end

      # ---

      def game_stats_for game_id

        # futures for pipeline
        rs, rp, bs, bp, a = nil, nil, nil, nil, false

        Mapattack.redis do |r|
          r.pipelined do
            rs = r.hvals GAME_ID_RED_KEY % game_id
            rp = r.scard GAME_ID_RED_MEMBERS_KEY % game_id
            bs = r.hvals GAME_ID_BLUE_KEY % game_id
            bp = r.scard GAME_ID_BLUE_MEMBERS_KEY % game_id
            a = r.get GAME_ID_ACTIVE_KEY % game_id
          end
        end

        {
          red: {
            score: rs.value.reduce(0, &:+),
            num_players: rp.value
          },
          blue: {
            score: bs.value.reduce(0, &:+),
            num_players: bp.value
          },
          active: a.value == 1
        }
      end

    end
  end
end
