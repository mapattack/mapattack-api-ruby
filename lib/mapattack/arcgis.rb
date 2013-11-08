module Mapattack; module ArcGIS

  module HTTPClientActor

    def self.included base
      base.__send__ :include, Celluloid
    end

    def hc
      @hc ||= HTTPClient.new
      @hc
    end

    def get url, params = {}
      request :get, url, params
    end

    def post url, params = {}
      request :post, url, params
    end

    def request meth, url, params
      JSON.parse hc.__send__(meth, url, params.merge(f: 'json')).body
    end
    private :request

  end

  class DeviceRegstrar
    include HTTPClientActor

    URL = 'https://www.arcgis.com/sharing/oauth2/registerDevice'.freeze

    def register
      post URL, client_id: Mapattack::CONFIG[:ago_client_id]
    end

  end

  class DeviceUpdater
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
