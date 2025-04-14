require "mobilis"

system = Mobilis::System.new

rails = Mobilis::Node::Rails.new("user")
user_db = Mobilis::Node::PostgreSQL.new("user-db")

system << rails
system << user_db

rails.primary_database = user_db

execution_env = Mobilis::ExecutionEnvironment.new(:test)

realized_env = Mobilis::RealizedEnv.new(system, execution_env)

puts realized_env.pp
