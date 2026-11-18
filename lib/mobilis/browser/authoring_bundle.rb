# frozen_string_literal: true

module Mobilis
  module Browser
    class AuthoringBundle
      def initialize(source, system)
        @source = source
        @system = system
      end

      def files
        {
          "mobilis.rb" => @source,
          "mobilis-system.json" => @system.to_json,
          "README.md" => readme
        }
      end

      private

      def readme
        <<~MARKDOWN
          # Mobilis definition

          The Ruby definition is directly executable from a Mobilis checkout:

          ```sh
          bundle install
          bundle exec ruby mobilis.rb
          ```

          The equivalent serialized declaration uses Mobilis's existing CLI:

          ```sh
          bundle exec mobilis generate mobilis-system.json
          ```

          Both commands materialize into `generate/` and may invoke Docker for services such as Rails.
        MARKDOWN
      end
    end
  end
end
