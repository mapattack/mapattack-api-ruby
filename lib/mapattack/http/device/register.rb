module Mapattack; module HTTP; module Device
  class Register < Responder

    def handle_request
      if params[:access_token].nil? or params[:access_token].empty?
        create_new_ago_device
      else

        # get AGO oauth data from redis
        #
        dts = JSON.parse redis.get 'device:tokens:' + params[:access_token] rescue nil

        # if we have everything...
        #
        if dts and dts['device_id']

          # update profile
          #
          set_profile dts['device_id']

          # respond with id and "access_token"
          #
          {
            device_id: dts['device_id'],
            access_token: params[:access_token]
          }


        else

          # ain't nobody got time for that
          #
          create_new_ago_device

        end

      end
    end

    def create_new_ago_device

      # create a new "access_token" to map to real AGO oauth data
      #
      at = Mapattack.generate_id 48

      # register for AGO oauth data and save it
      #
      dts = Mapattack::ArcGIS.device_registrar_pool.future.register.value
      binding.pry
      dts = {
        device_id: dts['device']['deviceId'],
        access_token: dts['deviceToken']['access_token'],
        refresh_token: dts['deviceToken']['refresh_token']
      }
      redis.set 'device:tokens:' + at, dts.to_json

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
      redis.set 'device:profile:' + device_id, profile_json
    end

  end

end; end; end
