# frozen_string_literal: true

module Mobilis
  module Realized
    class GoHTTP < HTTPApplication
      def service_writer
        Mobilis::ServiceWriter::GoHTTP
      end
    end
  end
end
