module Mapattack; module HTTP; module Device
  class Info < Responder

    def handle_request
      require_access_token do
        {
          device_id: @ago_data[:device_id],
          name: @profile[:name],
          access_token: @ago_data[:access_token]
        }
      end
    end

  end
end; end; end
