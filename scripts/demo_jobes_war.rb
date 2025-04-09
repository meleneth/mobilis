#!/usr/bin/env ruby
# frozen_string_literal: true

require "tty-screen"
require "pastel"
require "mobilis"

pastel = Pastel.new

jw = Mobilis::PrettyPrint::JobesWar.new(label: "ENV Vars", label_align: :center, footer_label: "End of ENV",
                                        footer_align: :right)

jw.define_columns do
  column :resolved, width: 24, mode: :fixed
  column :name,     mode: :auto
  column :value,    mode: :flex
  column :memo,     width: 12, mode: :fixed
end

jw.add_row(
  pastel.cyan("USERDB_POSTGRES_URL"),
  pastel.cyan("POSTGRES_URL"),
  pastel.dim("postgres://user:password@localhost:5432/very_long_database_name_that_needs_clipping"),
  pastel.magenta("primary DB")
)

jw.add_row(
  pastel.cyan("USERDB_REDIS_URL"),
  pastel.cyan("REDIS_URL"),
  pastel.dim("redis://localhost:6379"),
  pastel.magenta("cache")
)

jw.nest("Rails App") do |rails|
  rails.define_columns do
    column :key, mode: :fixed, width: 12
    column :val, mode: :flex
  end

  rails.add_row("App",  pastel.yellow("myapp"))
  rails.add_row("Port", pastel.green("11000"))
  rails.add_row("Mode", pastel.cyan("development"))
end

puts jw.render_to_lines.join("\n")
