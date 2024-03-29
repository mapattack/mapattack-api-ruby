module Mapattack; class Webserver; module GameRoutes
  def self.included base
    base.class_eval do

      # get '/game/list' do
      post '/game/list' do

        games = []
        user_location = params[:longitude] ? Terraformer::Point.new(params[:longitude], params[:latitude]) : nil

        # get boards
        #
        Mapattack.geotrigger.triggers(tags: BOARD_TAG).each do |b|

          board_id = nil

          b.data['tags'].each do |t|
            board_id = m[1] if m = BOARD_ID_REGEX.match(t)
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
            if game_id = redis.get(BOARD_ID_GAME_KEY % board_id)
              games << Game.new(id: game_id).stats
            end
          end

          { games: games }
        end

      end

      post '/game/create' do
        raise RequestError.new board_id: "required" if params[:board_id].nil? or params[:board_id].empty?
        with_device_gt_session do

          game = Game.new
          board_id = params[:board_id]
          device = Device.new id: @gt.device_data['deviceId'], gt_session: @gt

          Mapattack.redis do |r|
            r.pipelined do
              r.set GAME_ID_BOARD_KEY % game.id, board_id
              r.set BOARD_ID_GAME_KEY % board_id, game.id
            end
          end

          # save game info
          #
          a = Geotrigger::Application.new session: @gt
          board_trigger = a.triggers(tags: [BOARD_ID_KEY % board_id]).first
          board_polygon = Terraformer.parse board_trigger.condition['geo']['geojson']

          game_data = {
            name: board_trigger.properties['title'],
            bbox: board_polygon.bbox,
            creator: {
              device_id: device.id,
              name: device.profile['name']
            }
          }
          redis.set GAME_ID_DATA_KEY % game.id, game_data.to_json

          # copy game coins
          #
          a.triggers(tags: [COIN_BOARD_ID_KEY % board_id]).each do |coin_trigger|
            coin_data = {
              latitude: coin_trigger.condition['geo']['latitude'],
              longitude: coin_trigger.condition['geo']['longitude'],
              value: coin_trigger.properties['value'].to_i
            }
            redis.hset GAME_ID_COIN_DATA_KEY % game.id, coin_trigger.trigger_id, coin_data.to_json
          end

          # add device to game
          #
          team = device.choose_team_for game
          device.set_game_tag game
          device.set_active_game game, team

          { game_id: game.id, team: team }
        end
      end

      post '/game/start' do
        require_game_id
        with_device_gt_session do

          board = Board.for @game
          @game.activate!

          debug "posting to trigger/update..."
          data = @gt.post 'trigger/update', tags: COIN_BOARD_ID_KEY % board.id,
                                            addTags: GAME_ID_TAG % @game.id,
                                            action: {callbackUrl: CONFIG[:callback_url]}
          debug "done trigger/update."

          redis.publish GAME_ID_KEY % @game.id, {type: GAME_START_EVENT, game_id: @game.id}.to_json

          { game_id: @game.id, num_coins: data['triggers'].length }
        end
      end

      post '/game/join' do
        require_game_id
        with_device_gt_session do

          device = Device.new id: @gt.device_data['deviceId'], gt_session: @gt
          team = device.choose_team_for @game
          device.set_game_tag @game
          device.set_active_game @game, team

          join_event = {
            type: PLAYER_JOIN_EVENT,
            name: device.profile['name'],
            team: team,
            device_id: device.id
          }
          redis.publish GAME_ID_KEY % @game.id, join_event.to_json

          { game_id: @game.id, team: team }
        end
      end

      # get '/game/state' do
      post '/game/state' do
        require_game_id
        game_data = @game.data
        raise RequestError.new game: "no data!" unless game_data

        red_score = 0
        blue_score = 0
        red_players = 0
        blue_players = 0

        # populate coins and set scores
        #
        coin_data = Coin.data_for @game
        coin_states = Coin.states_for @game

        coins = coin_data.map do |coin_id, coin|
          coin = JSON.parse coin
          _coin = {
            coin_id: coin_id,
            latitude: coin['latitude'],
            longitude: coin['longitude'],
            value: coin['value'].to_i
          }
          if coin_states and coin_states[coin_id]
            _coin[:team] = coin_states[coin_id].to_sym
            case _coin[:team]
            when :red
              red_score += _coin[:value]
            when :blue
              blue_score += _coin[:value]
            end
          end
          _coin
        end

        # this gives us a list of device_ids, by team
        player_vals = @game.players
        device_ids = player_vals[:red] + player_vals[:blue]

        # get all player data
        #
        all_player_data = {}
        pd = redis.multi do |r|
          device_ids.each do |did|
            r.get DEVICE_LOCATION_ID_KEY % did
            r.get DEVICE_PROFILE_ID_KEY % did
          end
        end

        device_ids.each_with_index do |did, i|
          all_player_data[did] = {
            location: pd[i*2] ? JSON.parse(pd[i*2]) : nil,
            profile: JSON.parse(pd[i*2+1])
          }
        end

        # get all scores
        #
        all_scores = {}
        redis.multi([
          [:hgetall, GAME_ID_BLUE_KEY % @game.id],
          [:hgetall, GAME_ID_RED_KEY % @game.id]
        ]).each do |scores|
          scores.each do |did, score|
            if m = DEVICE_ID_REGEX.match(did)
              all_scores[m[1]] = score.to_i
            end
          end
        end

        players = player_vals.map do |team, team_players|
          team_players.map do |did|
            p = {
              device_id: did,
              team: team,
              score: 0
            }
            red_players += 1 if team == :red
            blue_players += 1 if team == :blue

            if all_player_data[did] && l = all_player_data[did][:location]
              p.merge! l
            end

            if all_player_data[did][:profile] && n = all_player_data[did][:profile]['name']
              p[:name] = n
            else
              p[:name] = did[0,3]
            end
            p[:score] = all_scores[did] if all_scores[did]
            p
          end
        end
        players.flatten!

        # response
        #
        {
          game: {
            game_id: @game.id,
            active: @game.active?,
            name: (game_data['name'] || 'Unititled Game'),
            bbox: game_data['bbox'],
            teams: {
              blue: {
                size: blue_players,
                score: blue_score
              },
              red: {
                size: red_players,
                score: red_score
              }
            },
            creator: {
              name: (game_data['creator']['name'] rescue nil),
              device_id: (game_data['creator']['device_id'] rescue nil)
            }
          },
          coins: coins,
          players: players
        }
      end

      post '/game/end' do
        game = Game.new id: params[:game_id]
        board = Board.for game
        redis.multi do |r|
          r.del BOARD_ID_GAME_KEY % board.id
          r.del GAME_ID_ACTIVE_KEY % game.id
        end

        game_tag = GAME_ID_KEY % game.id

        Mapattack.geotrigger.post 'device/update', tags: game_tag, removeTags: game_tag
        Mapattack.geotrigger.post 'trigger/update', tags: game_tag, removeTags: game_tag
        redis.publish game_tag, {type: 'game_end', game_id: game.id}.to_json

        {result: 'ended'}
      end

      get '/game/list' do

        # user location?
        ul = Terraformer::Point.new params[:longitude], params[:latitude] if params[:longitude]

        games = []

        triggers = Mapattack.geotrigger.post('trigger/list', tags: ['board'])['triggers']
        triggers.each do |t|

          shape = case
                  when t['condition']['geo']['geojson']
                    Terraformer.parse t['condition']['geo']['geojson']
                  when t['condition']['geo']['distance']
                    geo = t['condition']['geo']
                    Terraformer::Circle.new([
                      t['condition']['geo']['longitude'],
                      t['condition']['geo']['latitude']
                    ], t['condition']['geo']['distance']).polygon
                  end

          board_id = Mapattack.ids_for( 'board', *t['tags']).first
          board = {
            board_id: board_id,
            name: t['properties']['title'] || 'Untitled Board',
            bbox: (shape.bbox rescue nil)
          }
          board[:distance] = ul.distance_to(shape) if ul and shape

          game_id = redis.get BOARD_ID_GAME_KEY % board_id

          if game_id
            board[:game] = Game.new(id: game_id).stats
            games << board
          end

        end

        {games: games}
      end

    end
  end
end; end; end
