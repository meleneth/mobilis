# frozen_string_literal: true

module Mobilis
  module Node
    class S3Storage < Mobilis::Base::Node
      include Mobilis::PrettyPrint::PrettyPrintable

      attr_reader :buckets

      def initialize(name, buckets: [], **kwargs)
        super(name, **kwargs)
        @buckets = []
        Array(buckets).each { |bucket_name| bucket(bucket_name) }
      end

      def bucket(name)
        bucket_name = name.to_s
        raise ArgumentError, "S3 bucket name cannot be empty" if bucket_name.empty?

        buckets << bucket_name unless buckets.include?(bucket_name)
        self
      end

      def default_bucket
        buckets.first
      end

      def to_h
        super.merge(buckets: buckets)
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
        dsl.instance_value "buckets", buckets
      end
    end
  end
end
