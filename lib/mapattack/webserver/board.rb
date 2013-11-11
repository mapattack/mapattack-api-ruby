module Mapattack::Webserver::Board

  BOARD_ID_GAME_KEY =        'board:%s:game'.freeze
  GAME_ID_RED_KEY =          'game:%s:red'.freeze
  GAME_ID_BLUE_KEY =         'game:%s:blue'.freeze
  GAME_ID_RED_MEMBERS_KEY =  'game:%s:red:members'.freeze
  GAME_ID_BLUE_MEMBERS_KEY = 'game:%s:blue:members'.freeze
  GAME_ID_ACTIVE_KEY =       'game:%s:active'.freeze

  def self.included base
    base.class_eval do

      get '/board/list' do

        boards = []

        if !params[:latitude].nil?

          # make a location point object
          #
          point = Mapattack.rgeo.point params[:longitude], params[:latitude]

          # query geotrigger api for triggers with tag 'board' nearby
          #
          Mapattack.geotrigger.triggers({
            tags: 'board',
            geo: {
              latitude: params[:latitude],
              longitude: params[:longitude],
              distance: 1000
            }
          }).each do |trigger|

            # make the polygon object and determine closest point on it to location
            #
            polygon = Mapattack.rgeo.polygon

            # find the id of the board by parsing the 'board:xxx' tag
            #
            match = nil
            trigger.data['tags'].detect {|t| match = Mapattack::BOARD_ID_REGEX.match t}
            board_id = match[1] unless match.nil?
            next unless board_id

            # board data
            #
            board = {
              board_id: board_id,
              name: trigger.properties['title'] || "Untitled Board",
              distance: nil, # todo
              bbox: nil      # todo
            }

            # search redis for a currently running game
            #
            if game_id = redis.get(BOARD_ID_GAME_KEY % board_id)

              stats = redis.multi do |r|
                r.hvals GAME_ID_RED_KEY % game_id
                r.scard GAME_ID_RED_MEMBERS_KEY % game_id
                r.hvals GAME_ID_BLUE_KEY % game_id
                r.scard GAME_ID_BLUE_MEMBERS_KEY % game_id
                r.get GAME_ID_ACTIVE_KEY % game_id
              end

              board[:game] = {
                game_id: game_id,
                red_team: {
                  score: stats[0].reduce(0){|sum, points| sum += points},
                  num_players: stats[1]
                },
                blue_team: {
                  score: stats[2].reduce(0){|sum, points| sum += points},
                  num_players: stats[3]
                },
                active: (stats[4] == 1)
              }

            end

            boards << board

          end

        end

        { boards: boards }
      end

      post '/board/new' do
        { board_id: Mapattack.generate_id }
      end

    end
  end
end
