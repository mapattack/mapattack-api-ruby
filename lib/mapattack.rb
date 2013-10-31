require 'json'
require 'yaml'
require 'httpclient'
require 'pry'
require 'pry-nav'
require 'celluloid'
require 'celluloid/io'
require 'connection_pool'
require 'angelo'
require 'redis'
require 'celluloid/redis'
require 'celluloid/autostart'

$:.unshift File.expand_path '..', __FILE__

require 'mapattack/udp/service'
require 'mapattack/udp/handler'

module Mapattack

  CONFIG = YAML.load_file File.expand_path '../../config.yml', __FILE__

  @udp = Mapattack::UDP::Service.new
  def self.udp; @udp; end



  REDIS_POOL_CONF = {
    timeout: 5,
    size: 16
  }
  REDIS_DEVICE_TOKENS =  'device:tokens:%s'.freeze
  REDIS_DEVICE_PROFILE = 'device:profile:%s'.freeze

  def self.redis &block
    @redis ||= ConnectionPool.new REDIS_POOL_CONF do
      Redis.new driver: :celluloid
    end
    @redis.with &block
  end



  ID_POSSIBLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.freeze

  def self.generate_id length
    Array.new(length).map {ID_POSSIBLE[rand ID_POSSIBLE.length]}.join
  end



  module HTTPClientActor

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

end

require 'mapattack/arcgis'
require 'mapattack/webserver/helpers'
require 'mapattack/webserver'

Mapattack::Webserver.run unless $0 == 'irb'
