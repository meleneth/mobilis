#!/usr/bin/env ruby
# frozen_string_literal: true

require "mobilis"

def rack_defaults(service)
  service.add_gem("json")
  service.add_gem("opentelemetry-instrumentation-rack")
end

def redis_client_code
  <<~RUBY
    def gameredis
      @gameredis ||= Redis.new(url: ENV.fetch("GAMEREDIS_URL", "redis://gameredis:6379"))
    end
  RUBY
end

def add_mnbme_gem(service)
  service.local_gem("mel-mnbme", require_name: "mel/mnbme") do |gem|
    gem.write_file("mel-mnbme.gemspec", <<~'RUBY')
      # frozen_string_literal: true

      Gem::Specification.new do |spec|
        spec.name = "mel-mnbme"
        spec.version = "0.1.0"
        spec.authors = ["Meleneth"]
        spec.summary = "Make Number Bigger: Microservices Edition"
        spec.description = "Shared backend code for the MNBME generated demo"
        spec.license = "MIT"
        spec.required_ruby_version = ">= 4.0.0"
        spec.files = Dir["lib/**/*"]
        spec.require_paths = ["lib"]
        spec.add_dependency "random_name_generator"
        spec.add_dependency "redis"
      end
    RUBY

    gem.write_file("lib/mel/mnbme.rb", <<~'RUBY')
      # frozen_string_literal: true

      require_relative "mnbme/redis_keys"
      require_relative "mnbme/game_management"
      require_relative "mnbme/redis"

      module Mel
        module MNBME
          class Error < StandardError; end
        end
      end
    RUBY

    gem.write_file("lib/mel/mnbme/redis_keys.rb", <<~'RUBY')
      # frozen_string_literal: true

      module Mel
        module MNBME
          class RedisKeys
            attr_accessor :player_uuid, :game_uuid

            def initialize(gameredis)
              @gameredis = gameredis
            end

            def game_log_key = "game:log"
            def player_name_key = "player:name##{player_uuid}"
            def game_entries_key = "game:entries##{game_uuid}"
            def open_games_list_key = "open_games"
            def running_games_list_key = "running_games"
            def player_medals_key = "player:medals##{player_uuid}"
            def game_players_key = "game:players##{game_uuid}"
            def game_name_key = "game:name##{game_uuid}"
            def game_number_key = "game:number##{game_uuid}"
            def game_max_number_key = "game:max:number##{game_uuid}"
          end
        end
      end
    RUBY

    gem.write_file("lib/mel/mnbme/game_management.rb", <<~'RUBY')
      # frozen_string_literal: true

      module Mel
        module MNBME
          module GameManagement
            def cleanup_dead_games
              running_games.each do |game|
                @game_uuid = game
                next if game_exists?

                game_log "Sending in the janitor after #{game_uuid}"
                cleanup_dead_game
              end
            end

            def add_game_to_open_list
              gameredis.lpush open_games_list_key, game_uuid
            end

            def game_exists?
              gameredis.exists(game_number_key) != 0
            end

            def make_new_game
              @game_uuid = SecureRandom.uuid
              set_new_game_counters
              add_new_game_to_lists
              gameredis.expire game_number_key, 10
              game_log "#{player_name} has discovered #{monster_name}"
            end

            def add_new_game_to_lists
              gameredis.lpush open_games_list_key, game_uuid
              gameredis.lpush running_games_list_key, game_uuid
              gameredis.lpush game_players_key, player_uuid
            end

            def set_new_game_counters
              gameredis.set game_name_key, monster_name
              gameredis.set game_number_key, 100
              gameredis.set game_max_number_key, 100
              gameredis.set game_entries_key, 5
            end

            def cleanup_dead_game
              gameredis.del game_name_key, game_number_key, game_max_number_key, game_entries_key, game_players_key
              gameredis.lrem running_games_list_key, -1, game_uuid
              gameredis.lrem open_games_list_key, -1, game_uuid
            end
          end
        end
      end
    RUBY

    gem.write_file("lib/mel/mnbme/redis.rb", <<~'RUBY')
      # frozen_string_literal: true

      require "random_name_generator"
      require "securerandom"

      module Mel
        module MNBME
          class Redis < RedisKeys
            attr_reader :gameredis

            include GameManagement

            def game_name = gameredis.get(game_name_key)
            def game_number = gameredis.get(game_number_key)
            def game_max_number = gameredis.get(game_max_number_key)
            def game_players = gameredis.lrange(game_players_key, 0, -1)
            def running_games = gameredis.lrange(running_games_list_key, 0, -1)
            def player_name = gameredis.get(player_name_key)
            def player_medals = gameredis.get(player_medals_key)
            def fetch_game_log = gameredis.lrange(game_log_key, 0, -1)

            def player_turn
              unless running_games.include? game_uuid
                @game_uuid = "closed"
                return 0
              end
              health = gameredis.decr game_number_key
              gameredis.expire game_number_key, 10
              check_health_conditions(health)
              health
            end

            def check_health_conditions(health)
              if health.zero?
                gameredis.incr player_medals_key
                game_log "#{player_name} has vanquished #{monster_name} and now has #{player_medals} medals"
                cleanup_dead_game
              elsif health.negative?
                cleanup_dead_game
                @game_uuid = "closed"
              end
            end

            def join_existing_or_create_game
              @game_uuid = gameredis.lpop(open_games_list_key) || "closed"
              attempt_join if game_uuid != "closed"
              make_new_game if game_uuid == "closed"
            end

            def game_log(message)
              gameredis.lpush game_log_key, message
              gameredis.ltrim game_log_key, 0, 99
            end

            private

            def attempt_join
              if gameredis.decr(game_entries_key).positive?
                add_game_to_open_list
                gameredis.lpush game_players_key, player_uuid
              else
                @game_uuid = "closed"
              end
            end

            def monster_name
              rng = RandomNameGenerator.new(RandomNameGenerator::ROMAN)
              "#{rng.compose(3)} #{rng.compose(3)} #{rng.compose(3)}"
            rescue StandardError
              retry
            end
          end
        end
      end
    RUBY
  end
end

Mobilis::DSL.generate("mnbme") do
  redis("gameredis")

  logs = loki("loki")
  otel_collector("otel-collector")
  grafana("grafana")
  jaeger("jaeger")
  prometheus("prometheus")
  alloy("alloy", loki: logs)

  connect from: "grafana", to: "loki"
  connect from: "grafana", to: "prometheus"
  connect from: "otel-collector", to: "jaeger"
  connect from: "prometheus", to: "otel-collector"

  rack("accountservice") do |svc|
    rack_defaults(svc)
    svc.add_gem("redis")
    config_ru = <<~'RUBY'
      # frozen_string_literal: true

      require "json"
      require "securerandom"
      require "redis"

      __REDIS_CLIENT__

      app = proc do |env|
        request = Rack::Request.new(env)
        uuid = SecureRandom.uuid
        name = request.params["name"]
        gameredis.set("player:name#{uuid}", name)
        gameredis.set("player:medals#{uuid}", 0)
        puts({ service: "accountservice", event: "player_registered", player_uuid: uuid, name: name }.to_json)
        [200, { "content-type" => "application/json" }, [{ name: name, player_uuid: uuid }.to_json]]
      end

      run app
    RUBY
    svc.write_file("config.ru", config_ru.gsub("__REDIS_CLIENT__", redis_client_code))
  end

  rack("achievementservice") do |svc|
    rack_defaults(svc)
    svc.write_file("config.ru", <<~'RUBY')
      # frozen_string_literal: true

      app = proc do
        [200, { "content-type" => "text/plain" }, ["achievementservice\\n"]]
      end

      run app
    RUBY
  end

  rack("gameservice") do |svc|
    rack_defaults(svc)
    svc.add_gem("redis")
    svc.add_gem("random_name_generator")
    add_mnbme_gem(svc)
    config_ru = <<~'RUBY'
      # frozen_string_literal: true

      require "json"
      require "redis"
      require "mel/mnbme"

      __REDIS_CLIENT__

      gameredis.flushdb

      class ConnectedBase
        attr_reader :env, :gamestore, :gameredis

        def initialize(gameredis)
          @gameredis = gameredis
        end

        def call(env)
          @env = env
          @gamestore = Mel::MNBME::Redis.new(@gameredis)
          response
        end

        def request = @request ||= Rack::Request.new(@env)
      end

      class MakeNumberBiggerGame < ConnectedBase
        def response
          gamestore.game_uuid = request.params["game_uuid"]
          gamestore.player_uuid = request.params["player_uuid"]
          health = gamestore.player_turn
          puts({ service: "gameservice", event: "player_turn", player_uuid: gamestore.player_uuid, game_uuid: gamestore.game_uuid, health: health }.to_json)
          [200, { "content-type" => "application/json" }, [{ number: health, game_uuid: gamestore.game_uuid }.to_json]]
        end
      end

      class ListRunningGames < ConnectedBase
        def response
          gamestore.cleanup_dead_games
          result = {}
          result[:games] = gamestore.running_games.to_h do |game_uuid|
            gamestore.game_uuid = game_uuid
            [game_uuid, {
              boss_name: gamestore.game_name,
              number: gamestore.game_number,
              maxnumber: gamestore.game_max_number,
              players: gamestore.game_players.map do |player_uuid|
                gamestore.player_uuid = player_uuid
                { name: gamestore.player_name, medals: gamestore.player_medals }
              end
            }]
          end
          result[:logs] = gamestore.fetch_game_log
          [200, { "content-type" => "application/json" }, [result.to_json]]
        end
      end

      class JoinGame < ConnectedBase
        def response
          gamestore.player_uuid = request.params["player_uuid"]
          gamestore.join_existing_or_create_game
          puts({ service: "gameservice", event: "join_game", player_uuid: gamestore.player_uuid, game_uuid: gamestore.game_uuid }.to_json)
          [200, { "content-type" => "application/json" }, [{ game_uuid: gamestore.game_uuid, game_name: gamestore.game_name }.to_json]]
        end
      end

      redis = gameredis
      app = Rack::Builder.app do
        map("/game/play") { run MakeNumberBiggerGame.new(redis) }
        map("/game/list") { run ListRunningGames.new(redis) }
        run JoinGame.new(redis)
      end

      run app
    RUBY
    svc.write_file("config.ru", config_ru.gsub("__REDIS_CLIENT__", redis_client_code))
  end

  rack("bigboard") do |svc|
    rack_defaults(svc)
    svc.add_gem("faraday")
    svc.write_file("config.ru", <<~'RUBY')
      # frozen_string_literal: true

      require "faraday"

      class BigBoard
        def call(_env)
          response = gameservice.get("/game/list").body
          [200, { "content-type" => "text/html" }, [page(response)]]
        end

        def page(response)
          games = response.fetch(:games, {})
          logs = response.fetch(:logs, [])
          <<~HTML
            <html>
              <head><meta http-equiv="refresh" content="1" /><style>body{font-family:sans-serif}.bigboard{display:flex;gap:2rem}.bigboard-child{flex:1;border:2px solid #d6b645;padding:1rem}</style></head>
              <body>
                <h1>BigBoard</h1>
                <div class="bigboard">
                  <div class="bigboard-child"><h2>Logs</h2><ul>#{logs.map { |log| "<li>#{log}</li>" }.join}</ul></div>
                  <div class="bigboard-child"><h2>Games</h2><ul>#{games.map { |_id, game| "<li><h3>#{game[:boss_name]} #{game[:number]}/#{game[:maxnumber]}</h3><ul>#{game[:players].map { |player| "<li>#{player[:name]} - #{player[:medals]}</li>" }.join}</ul></li>" }.join}</ul></div>
                </div>
              </body>
            </html>
          HTML
        end

        def gameservice
          Faraday.new(url: ENV.fetch("GAMESERVICE_URL", "http://gameservice:9292")) do |f|
            f.response :json, parser_options: { symbolize_names: true }
          end
        end
      end

      run BigBoard.new
    RUBY
  end

  rack("playerservice", instances: 17) do |svc|
    rack_defaults(svc)
    svc.add_gem("faraday")
    svc.add_gem("random_name_generator")
    svc.write_file("config.ru", <<~'RUBY')
      # frozen_string_literal: true

      require "faraday"
      require "json"
      require "random_name_generator"
      require "uri"

      def generate_name
        rng = RandomNameGenerator.new(RandomNameGenerator::ELVEN)
        "#{rng.compose(3)} #{rng.compose(3)}"
      rescue StandardError
        retry
      end

      def accountservice
        Faraday.new(url: ENV.fetch("ACCOUNTSERVICE_URL", "http://accountservice:9292")) do |f|
          f.response :json, parser_options: { symbolize_names: true }
        end
      end

      def gameservice
        Faraday.new(url: ENV.fetch("GAMESERVICE_URL", "http://gameservice:9292")) do |f|
          f.response :json, parser_options: { symbolize_names: true }
        end
      end

      Thread.new do
        name = generate_name
        puts({ service: "playerservice", event: "registering", name: name }.to_json)
        response = accountservice.post("/login", URI.encode_www_form({ name: name }))
        player_uuid = response.body[:player_uuid]
        game_uuid = "closed"

        loop do
          if game_uuid == "closed"
            response = gameservice.post("/game/join", URI.encode_www_form({ player_uuid: player_uuid }))
            if response.success?
              game_uuid = response.body[:game_uuid]
              puts({ service: "playerservice", event: "joined_game", name: name, game_uuid: game_uuid }.to_json)
            end
          else
            response = gameservice.post("/game/play", URI.encode_www_form({ player_uuid: player_uuid, game_uuid: game_uuid }))
            game_uuid = response.body[:game_uuid]
          end
          sleep 1
        rescue StandardError => e
          puts({ service: "playerservice", event: "error", error: e.message }.to_json)
          sleep 2
        end
      end

      run proc { [200, { "content-type" => "text/plain" }, ["playerservice\\n"]] }
    RUBY
  end

  %w[accountservice gameservice achievementservice bigboard playerservice].each do |svc|
    connect from: svc, to: "otel-collector"
  end

  connect from: "accountservice", to: "gameredis"
  connect from: "gameservice", to: "gameredis"
  connect from: "gameservice", to: "accountservice"
  connect from: "gameservice", to: "achievementservice"
  connect from: "bigboard", to: "accountservice"
  connect from: "bigboard", to: "gameservice"
  connect from: "bigboard", to: "achievementservice"
  connect from: "playerservice", to: "accountservice"
  connect from: "playerservice", to: "gameservice"
end
