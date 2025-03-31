# frozen_string_literal: true

module Mobilis
  module Nodes
    # Base class for Ruby on Rails
    class Rails < Mobilis::Nodes::Ruby
      ref_attr :primary_database
    end
  end
end
