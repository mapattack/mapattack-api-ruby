require 'json'
require 'yaml'
require 'httpclient'
require 'pry'
require 'pry-nav'
require 'celluloid'
require 'celluloid/io'
require 'reel'
require 'connection_pool'
require 'redis'
require 'celluloid/redis'
require 'celluloid/autostart'

$:.unshift File.expand_path '..', __FILE__

require 'mapattack/udp/service'
require 'mapattack/udp/handler'

require 'mapattack/webserver'
require 'mapattack/arcgis'
require 'mapattack/http/responder'
require 'mapattack/http/device/register'

module Mapattack

  CONFIG = YAML.load_file File.expand_path '../../config.yml', __FILE__

  @udp = Mapattack::UDP::Service.new



  REDIS_POOL_CONF = {
    timeout: 5,
    size: 16
  }

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

end

Mapattack::Webserver.run unless $0 == 'irb'
