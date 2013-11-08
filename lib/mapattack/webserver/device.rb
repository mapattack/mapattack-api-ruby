module Mapattack::Webserver::Device
  def self.included base
    base.class_eval do

      post '/device/register' do

        # without an "access_token"...
        #
        if params[:access_token].nil? or params[:access_token].empty?

          # create token, register device, stash in redis
          #
          create_new_ago_device

        else

          # get AGO oauth data from redis
          #
          dts = JSON.parse redis.get REDIS_DEVICE_TOKENS % params[:access_token] rescue nil

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

      post '/device/register_push' do
        require_access_token do
          Mapattack::Arcgis.device_updater_pool.async.update @ago_data, params
        end
      end

      get '/device/info' do
        require_access_token do
          {
            device_id: @ago_data[:device_id],
            name: @profile[:name],
            access_token: @ago_data[:access_token]
          }
        end
      end

    end
  end
end
