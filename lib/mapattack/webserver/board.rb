module Mapattack::Webserver::Board
  def self.included base
    base.class_eval do

      get '/board/list' do
        if !params[:latitude].nil?

          # query geotrigger api for triggers with tag 'board' nearby
          #
          board_triggers = Mapattack.geotrigger.triggers({
            tags: 'board',
            geo: {
              latitude: params[:latitude],
              longitude: params[:longitude],
              distance: 1000
            }
          })

          #
          #
          board_triggers.each do |trigger|
            trigger.data['tags'].detect {|t| m = BOARD_ID_REGEX.match t}
            board_id = m[1]
          end

        else
          { boards: [] }
        end
      end

    end
  end
end
