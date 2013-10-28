module Mapattack; module HTTP; module Device
  class RegisterPush < Responder

    def handle_request
      require_access_token do
        Mapattack::Arcgis.device_updater_pool.async.update ago_data, params
      end
    end

  end
end; end; end
