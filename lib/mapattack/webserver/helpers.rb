module Mapattack
  module Helpers

    def create_new_ago_device

      # create a new "access_token" to map to real AGO oauth data
      #
      at = Mapattack.generate_id 48

      # register for AGO oauth data and save it
      #
      dts = Mapattack::ArcGIS.device_registrar_pool.future.register.value
      dts = {
        device_id: dts['device']['deviceId'],
        access_token: dts['deviceToken']['access_token'],
        refresh_token: dts['deviceToken']['refresh_token']
      }
      redis.set (REDIS_DEVICE_TOKENS % at), dts.to_json

      # save profile info
      #
      set_profile dts[:device_id]

      # respond with id and "access_token"
      #
      {
        device_id: dts[:device_id],
        access_token: at
      }
    end

    def profile_json
      { name: params[:name],
        avatar: params[:avatar]
      }.to_json
    end

    def set_profile device_id
      redis.set (REDIS_DEVICE_PROFILE % device_id), profile_json
    end

    def require_access_token &block
      if params[:access_token]
        ago_data = redis.get REDIS_DEVICE_TOKENS % params[:access_token]
        if ago_data
          @ago_data = Angelo::Responder.symhash.merge! JSON.parse ago_data
          profile = JSON.parse redis.get REDIS_DEVICE_PROFILE % @ago_data[:device_id]
          @profile = Angelo::Responder.symhash.merge! profile
          yield
        else
          { error: "no AGO oauth data found for '#{params[:access_token]}'" }
        end
      else
        { error: 'no access_token param' }
      end
    end

  end
end
