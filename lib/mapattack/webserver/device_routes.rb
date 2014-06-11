module Mapattack::Webserver::DeviceRoutes
  def self.included base
    base.class_eval do

      post '/device/register' do

        # without an "access_token"...
        #
        if params[:access_token].nil? or params[:access_token].empty?

          # create token, register device, stash in redis
          #
          Device.create_new_ago_device

        else

          # get AGO oauth data from redis
          #
          dts = JSON.parse redis.get(DEVICE_TOKENS_KEY % params[:access_token]) rescue nil

          # if we have everything...
          #
          if dts and dts['device_id']

            # update profile
            #
            d = Device.new id: dts['device_id']
            d.set_profile params[:name], params[:avatar]

            # respond with id and "access_token"
            #
            {
              device_id: d.id,
              access_token: params[:access_token]
            }


          else

            # ain't nobody got time for that
            #
            Device.create_new_ago_device

          end

        end
      end

      post '/device/register_push' do
        require_access_token do
          Mapattack.arcgis.async.update @ago_data, params
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
