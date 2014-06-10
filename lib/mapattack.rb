require 'json'
require 'yaml'
# require 'httpclient'

require 'bundler'
Bundler.require

$:.unshift File.expand_path '..', __FILE__

require 'mapattack/udp/service'
require 'mapattack/arcgis'

module Mapattack

  BOARD_ID_REGEX = /^board:([^:]+)$/
  GAME_ID_REGEX = /^game:([^:]+)$/
  COIN_ID_REGEX = /^coin:([^:]+)$/
  DEVICE_ID_REGEX = /^device:([^:]+)$/

  BOARD_ID_KEY =             'board:%s'
  BOARD_ID_GAME_KEY =        'board:%s:game'

  COIN_BOARD_ID_KEY =        'coin:board:%s'

  GAME_ID_KEY =              'game:%s'
  GAME_ID_RED_KEY =          'game:%s:red'
  GAME_ID_BLUE_KEY =         'game:%s:blue'
  GAME_ID_RED_MEMBERS_KEY =  'game:%s:red:members'
  GAME_ID_BLUE_MEMBERS_KEY = 'game:%s:blue:members'
  GAME_ID_TEAM_MEMBERS_KEY = 'game:%s:%s:members'
  GAME_ID_TEAM_KEY =         'game:%s:%s'
  GAME_ID_ACTIVE_KEY =       'game:%s:active'
  GAME_ID_BOARD_KEY =        'game:%s:board'
  GAME_ID_DATA_KEY =         'game:%s:data'
  GAME_ID_COIN_DATA_KEY =    'game:%s:coin_data'
  GAME_ID_COINS_KEY =        'game:%s:coins'

  DEVICE_PROFILE_ID_KEY =    'device:profile:%s'
  DEVICE_TEAM_KEY =          'device:team:%s'
  DEVICE_ACTIVE_GAME_KEY =   'device:active_game:%s'
  DEVICE_TOKENS_KEY =        'device:tokens:%s'
  DEVICE_LOCATION_ID_KEY =   'device:location:%s'

  BOARD_TAG =   'board'
  GAME_ID_TAG = 'game:%s'

  CONFIG = YAML.load_file File.expand_path '../../config.yml', __FILE__

  REDIS_POOL_CONF = {
    timeout: 5,
    size: 16
  }

  GAME_START_EVENT =  'game_start'
  PLAYER_JOIN_EVENT = 'player_join'

  ID_POSSIBLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'

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

require 'mapattack/models/game'
require 'mapattack/models/board'
require 'mapattack/models/coin'
require 'mapattack/models/device'
require 'mapattack/webserver/helpers'
require 'mapattack/webserver'

Mapattack::Webserver.run unless $0 == 'irb'
