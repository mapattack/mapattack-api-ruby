require 'json'
require 'yaml'
# require 'httpclient'

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

  REDIS_POOL_CONF = {
    timeout: 5,
    size: 16
  }
  REDIS_DEVICE_TOKENS =  'device:tokens:%s'
  REDIS_DEVICE_PROFILE = 'device:profile:%s'
  REDIS_GAME_CHANNEL = 'game:%s'

  ID_POSSIBLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.freeze

  class << self

    @udp = UDP::Service.new

    @arcgis = ArcGIS.new
    attr_reader :arcgis

    def redis &block
      @redis ||= ConnectionPool.new REDIS_POOL_CONF do
        Redis.new driver: :celluloid
      end
      @redis.with &block
    end

    def geotrigger
      @geotrigger ||= Geotrigger::Application.new client_id: CONFIG[:ago_client_id],
                                                  client_secret: CONFIG[:ago_client_secret]
    end

    def generate_id length
      Array.new(length).map {ID_POSSIBLE[rand ID_POSSIBLE.length]}.join
    end

  end
end

require 'mapattack/arcgis'
require 'mapattack/webserver/helpers'
require 'mapattack/webserver'

Mapattack::Webserver.run unless $0 == 'irb'
