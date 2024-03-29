module Mapattack; class Webserver; module BoardRoutes
  def self.included base
    base.class_eval do

      # full list of available boards within 1km
      #
      # get '/board/list' do
      post '/board/list' do
        raise RequestError.new latitude: 'required' if params[:latitude].nil?

        boards = []
        longitude = Float(params[:longitude])
        latitude = Float(params[:latitude])

        # make a location point object
        #
        point = Terraformer::Point.new longitude, latitude

        # query geotrigger api for triggers with tag 'board' nearby
        #
        BigDecimal.limit Terraformer::PRECISION
        Mapattack.geotrigger.triggers({
          tags: 'board',
          geo: {
            latitude: latitude,
            longitude: longitude,
            distance: 1000
          }
        }).each do |trigger|

          # make the polygon object and determine closest point on it to location
          #
          polygon = Terraformer.parse trigger.condition['geo']['geojson']

          # find the id of the board by parsing the 'board:xxx' tag
          #
          match = nil
          trigger.data['tags'].detect {|t| match = BOARD_ID_REGEX.match t}
          board_id = match[1] unless match.nil?
          next unless board_id

          # board data
          #
          dist = point.distance_to(polygon)
          board = {
            board_id: board_id,
            name: trigger.properties['title'] || "Untitled Board",
            distance: dist,
            bbox: polygon.bbox
          }

          # search redis for a currently running game
          #
          if game_id = redis.get(BOARD_ID_GAME_KEY % board_id)
            game = Game.new id: game_id
            board[:game] = game.stats
          end

          boards << board
        end

        { boards: boards }
      end

      # a newly generated board id suitable for a new board
      #
      post '/board/new' do
        { board_id: Mapattack.generate_id }
      end

      # full state of the board with coins
      #
      # get '/board/state' do
      post '/board/state' do
        with_device_gt_session do

          # app model, with session built from params[:access_token]
          #
          a = Geotrigger::Application.new session: @gt

          # get the trigger for this board i.e. the board
          #
          b = a.triggers(tags: [BOARD_ID_KEY % params[:board_id]]).first

          # build up the board state hash
          #
          board = {
            board_id: params[:board_id],
            game_id: false,
            name: b.properties['title'] || 'Untitled Board',
            bbox: Terraformer.parse(b.condition['geo']['geojson']).bbox
          }

          # map the coin state hash
          #
          coins = a.triggers(tags: [COIN_BOARD_ID_KEY % params[:board_id]]).map do |coin|
            { coin_id: coin.trigger_id,
              latitude: coin.condition['geo']['latitude'],
              longitude: coin.condition['geo']['longitude'],
              value: coin.properties['value'] }
          end

          # if we have a game running, add the id to the state
          #
          if game_id = redis.get(BOARD_ID_GAME_KEY % params[:board_id])
            board[:game_id] = game_id
          end

          { board: board, coins: coins }
        end
      end

    end
  end
end; end; end
