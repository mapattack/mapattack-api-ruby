module Mapattack; module ArcGIS

  module HTTPClientActor
    def hc
      @hc ||= HTTPClient.new
      @hc
    end
    def post url, params = {}
      JSON.parse hc.post(url, params.merge(f: 'json')).body
    end
  end

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

    def update
      raise NotImplementedError
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

