module Mapattack
  module UDP
    class Service
      include Celluloid::IO
      include Celluloid::Logger
      include RedisPoolified

      RECV_MAXLEN = 576
      BIND_ADDR = '0.0.0.0'

      finalizer :finalize

      @@game_listeners = {}

      def initialize
        @socket = Celluloid::IO::UDPSocket.new
        @socket.bind BIND_ADDR, CONFIG[:udp_port]
        async.listen
        info "listening on udp://#{BIND_ADDR}:#{CONFIG[:udp_port]}"
      end

      def listen
        loop { async.handle_data *@socket.recvfrom(RECV_MAXLEN) }
      end

      def finalize
        @socket.close if @socket
      end

      def handle_data data, server_inet_addr

        data = JSON.parse data
        lu = build_location_update data

        with_device_gt_session access_token: data['access_token'] do |ago_data, gt|

          device = Device.new id: ago_data[:device_id]
          device.set_udp_info server_inet_addr[2], server_inet_addr[1]

          previous = device.location
          debug "previous: #{previous}"
          send_to_geotrigger = false
          distance = false

          if previous
            lu[:previous] = previous

            p1 = Terraformer::Point.new previous['longitude'], previous['latitude']
            p2 = Terraformer::Point.new lu[:locations][0][:longitude], lu[:locations][0][:latitude]

            distance = p1.distance_to p2
            if Numeric === distance and distance >= 10
              send_to_geotrigger = true
            end

          else
            send_to_geotrigger = true
          end

          if send_to_geotrigger
            debug "sending location update! distance was #{distance}"
            gt.post 'location/update', lu
            device.set_location lu[:locations][0] if previous and previous['timestamp'] < lu[:locations][0][:timestamp]
          else
            debug "NOT sending location update! distance was #{distance}"
          end

          if game_hash = device.active_game

            async.listen_to_game game_hash[:game_id] unless @@game_listeners[game_hash[:game_id]]

            pub_data = {
              type: 'player',
              name: game_hash[:device_name] || device.id[0,3],
              team: game_hash[:device_team],
              score: game_hash[:device_score] || 0,
              device_id: device.id
            }.merge! lu[:locations][0]

            redis.publish GAME_ID_KEY % game_hash[:game_id], pub_data.to_json

          end

        end

      end

      def build_location_update data
        accuracy = Integer(data['accuracy'])
        accuracy = 5 if accuracy <= 30
        {
          locations: [
            {
              timestamp: Integer(data['timestamp']),
              latitude:  Float(data['latitude']),
              longitude: Float(data['longitude']),
              accuracy:  accuracy,
              speed:     Integer(data['speed']),
              bearing:   Integer(data['bearing'])
            }
          ]
        }
      end

      def listen_to_game id
        @@game_listeners[id] = true
        game = Game.new id: id
        catch :done do
          r = ::Redis.new driver: :celluloid, host: CONFIG[:redis_host], port: CONFIG[:redis_port]
          r.subscribe GAME_ID_KEY % id do |on|
            on.message do |channel, msg|
              teams = game.players
              all_players = teams[:red] + teams[:blue]
              all_players.each do |device_id|
                d = Device.new id: device_id
                ui = d.udp_info
                @socket.send msg, 0, ui[:address], ui[:port]
              end
              throw :done if JSON.parse(msg)['type'] == 'game_end'
            end
          end
        end
        @@game_listeners[id] = false
      end

      private

      def require_access_token p = {}, &block
        if p[:access_token]
          ago_data = redis.get DEVICE_TOKENS_KEY % p[:access_token]
          if ago_data
            ago_data = Angelo::Responder.symhash.merge! JSON.parse ago_data
            profile = JSON.parse redis.get DEVICE_PROFILE_ID_KEY % ago_data[:device_id]
            profile = Angelo::Responder.symhash.merge! profile
            yield ago_data
          else
            { error: "no AGO oauth data found for '#{p[:access_token]}'" }
          end
        else
          { error: 'no access_token param' }
        end
      end

      def with_device_gt_session p = {}, &block
        require_access_token p do |ago_data|
          gt = Geotrigger::Session.new client_id: CONFIG[:ago_client_id],
                                       type: :device,
                                       refresh_token: ago_data[:refresh_token]
          response = yield ago_data, gt
          ago_data[:access_token] = gt.access_token
          redis.set DEVICE_TOKENS_KEY % p[:access_token], ago_data.to_json
          response
        end
      end

    end

  end
end
