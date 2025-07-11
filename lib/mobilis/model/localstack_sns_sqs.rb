# frozen_string_literal: true

module Mobilis
  module Model
    class LocalstackSNSSQS
      attr_reader :sns, :sqs

      def initialize(sns, sqs)
        @sns = sns
        @sqs = sqs
      end

      def to_h
        {
          type: self.class.name,
          sns: @sns,
          sqs: @sqs
        }
      end

      def self.from_h(hash)
        new(hash[:sns], hash[:sqs])
      end

      def ppx_fields(dsl)
        dsl.simple_value "sns", sns
        dsl.simple_value "sqs", sqs
      end
    end
  end
end
