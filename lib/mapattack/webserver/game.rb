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

      post '/game/create' do
        param_error :board_id, :required, 'missing board_id parameter' unless params[:board_id]
        halt if response.error?

        with_device_gt_session do

          game_id = Mapattack.generate_id
          board_id = params[:board_id]
          device_id = @gt.device_data['deviceId']

          Mapattack.redis do |r|
            r.pipelined do
              r.set GAME_ID_BOARD_KEY % game_id, board_id
              r.set BOARD_ID_GAME_KEY % board_id, game_id
            end
          end

          # save game info
          #
          a = Geotrigger::Application.new session: @gt
          board = a.triggers(tags: [BOARD_ID_KEY % board_id]).first
          board_polygon = Terraformer.parse board.condition['geo']['geojson']

          device_profile = JSON.parse Mapattack.redis {|r| r.get DEVICE_PROFILE_ID_KEY % device_id}
          game_data = {
            name: board.properties['title'],
            bbox: board_polygon.bbox,
            creator: {
              device_id: device_id,
              name: device_profile['name']
            }
          }
          Mapattack.redis do |r|
            r.set GAME_ID_DATA_KEY % game_id, game_data.to_json
          end

          # copy game coins
          #
          a.triggers(tags: [COIN_BOARD_ID_KEY % board_id]).each do |coin_trigger|
            coin_data = {
              latitude: coin_trigger.condition['geo']['latitude'],
              longitude: coin_trigger.condition['geo']['longitude'],
              value: coin_trigger.properties['value'].to_i
            }
            Mapattack.redis do |r|
              r.hset GAME_ID_COIN_DATA_KEY % game_id, coin_trigger.trigger_id, coin_data.to_json
            end
          end

          # add device to game
          #


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
