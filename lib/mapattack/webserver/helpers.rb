module Mapattack
  module Helpers

    def require_access_token &block
      if params[:access_token]
        ago_data = redis.get DEVICE_TOKENS_KEY % params[:access_token]
        if ago_data
          @ago_data = Angelo::Responder.symhash.merge! JSON.parse ago_data
          profile = JSON.parse redis.get DEVICE_PROFILE_ID_KEY % @ago_data[:device_id]
          @profile = Angelo::Responder.symhash.merge! profile
          yield
        else
          { error: "no AGO oauth data found for '#{params[:access_token]}'" }
        end
      else
        { error: 'no access_token param' }
      end
    end

    def with_device_gt_session &block
      require_access_token do
        @gt = Geotrigger::Session.new client_id: CONFIG[:ago_client_id], type: :device
        @gt.access_token = params[:access_token]
        yield
      end
    end

    def require_game_id
      raise RequestError.new game_id: 'required' if params[:game_id].nil? or params[:game_id].empty?
      @game = Mapattack::Game.new params[:game_id]
    end

  end
end
