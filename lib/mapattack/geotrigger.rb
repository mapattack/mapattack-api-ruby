module Mapattack; module Geotrigger

  class Client
    include Celluloid
    include HTTPActor

    URL = 'https://geotrigger.arcgis.com'.freeze

  end

end; end
