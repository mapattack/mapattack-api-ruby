module Mapattack; module ArcGIS

  class DeviceRegstrar
    include Celluloid
    include HTTPClientActor

    URL = 'https://www.arcgis.com/sharing/oauth2/registerDevice'.freeze

    def register
      post URL, client_id: Mapattack::CONFIG[:ago_client_id]
    end

  end

  class DeviceUpdater
    include Celluloid
    include HTTPClientActor

    URL = 'https://www.arcgis.com/sharing/oauth2/apps/%s/devices/%s/update'

    def update ago_data, params
      post URL % [CONFIG[:ago_client_id], ago_data['device_id']],
        token: ago_data['access_token'],
        apnsProdToken: params[:apns_prod_token],
        apnsSandboxToken: params[:apns_sandbox_token],
        gcmRegistrationId: params[:gcm_registration_id]
    end

  end

  def self.device_registrar_pool
    @device_registrar_pool ||= DeviceRegstrar.pool
    @device_registrar_pool
  end

  def self.device_updater_pool
    @device_updater_pool ||= DeviceUpdater.pool
    @device_updater_pool
  end

end; end
