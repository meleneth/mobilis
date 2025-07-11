# frozen_string_literal: true

module Mobilis
  module Node
    class Localstack < Mobilis::Base::Node
      include Mobilis::PrettyPrint::PrettyPrintable

      def sns_sqs(sns, sqs)
        model = Mobilis::Model::LocalstackSNSSQS.new(sns, sqs)
        models << model
        model
      end

      def ppx_fields(dsl)
        dsl.instance_value "name", name
      end
    end
  end
end
