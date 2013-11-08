require 'json'
require 'yaml'
require 'httpclient'

require 'bundler'
Bundler.require

$:.unshift File.expand_path '..', __FILE__

require 'mapattack/udp/service'
require 'mapattack/udp/handler'

module Mapattack

  BOARD_ID_REGEX = /^board:([^:]+)$/
  GAME_ID_REGEX = /^game:([^:]+)$/
  COIN_ID_REGEX = /^coin:([^:]+)$/

  CONFIG = YAML.load_file File.expand_path '../../config.yml', __FILE__

  @udp = Mapattack::UDP::Service.new
  def self.udp; @udp; end



  REDIS_POOL_CONF = {
    timeout: 5,
    size: 16
  }
  REDIS_DEVICE_TOKENS =  'device:tokens:%s'.freeze
  REDIS_DEVICE_PROFILE = 'device:profile:%s'.freeze
  REDIS_GAME_CHANNEL = 'game:%s'.freeze

  def self.redis &block
    @redis ||= ConnectionPool.new REDIS_POOL_CONF do
      Redis.new driver: :celluloid
    end
    @redis.with &block
  end



  def self.geotrigger
    @geotrigger ||= ::ArcGIS::GT::Application.new client_id: CONFIG[:ago_client_id],
                                                  client_secret: CONFIG[:ago_client_secret]
  end



  ID_POSSIBLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.freeze

  def self.generate_id length
    Array.new(length).map {ID_POSSIBLE[rand ID_POSSIBLE.length]}.join
  end



end

require 'mapattack/arcgis'
require 'mapattack/webserver/helpers'
require 'mapattack/webserver/websocket_handler'
require 'mapattack/webserver'

Mapattack::Webserver.run unless $0 == 'irb'
