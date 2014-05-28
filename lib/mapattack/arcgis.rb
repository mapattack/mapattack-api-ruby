module Mapattack
  class ArcGIS
    include Celluloid::IO

    REGISTER_URL = 'https://www.arcgis.com/sharing/oauth2/registerDevice'

    def register
      post REGISTER_URL, client_id: CONFIG[:ago_client_id]
    end



    UPDATE_URL = 'https://www.arcgis.com/sharing/oauth2/apps/%s/devices/%s/update'

    def update ago_data, params
      post UPDATE_URL % [CONFIG[:ago_client_id], ago_data['device_id']],
        token: ago_data['access_token'],
        apnsProdToken: params[:apns_prod_token],
        apnsSandboxToken: params[:apns_sandbox_token],
        gcmRegistrationId: params[:gcm_registration_id]
    end



    def post url, params
      JSON.parse HTTP.post(url, params: params.merge(f: :json)).body
    end

  end
end
