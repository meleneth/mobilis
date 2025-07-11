module Mobilis
  module ServiceWriter
    class Localstack < Mobilis::Base::ServiceWriter
      def write
        write_main_tf
        File.write("README.md", <<~HERE)
          this isn't fully automated yet, sorry
          export TF_VAR_localstack_endpoint="http://localhost:11000"
          terraform plan
          terraform apply
          rm -Rf .terraform
        HERE
      end

      def write_main_tf
        file_contents = <<~HERE
          terraform {
            required_providers {
              aws = {
                source  = "hashicorp/aws"
                version = "~> 5.0"
              }
            }
          }

          variable "localstack_endpoint" {}

          provider "aws" {
            region                      = "us-east-1"
            access_key                  = "test"
            secret_key                  = "test"
            skip_credentials_validation = true
            skip_requesting_account_id  = true
            skip_metadata_api_check     = true

            endpoints {
              sqs = var.localstack_endpoint
              sns = var.localstack_endpoint
            }
          }

        HERE

        file_lines = file_contents.lines.map(&:chomp)
        realized_node.each_model_of_type(Mobilis::Model::LocalstackSNSSQS) do |model|
          file_lines << "resource \"aws_sns_topic\" \"#{model.sns}\" {"
          file_lines << "  name = \"#{model.sns}\""
          file_lines << "}"
          file_lines << ""
          model.sqs.each do |sqs|
            file_lines << "resource \"aws_sqs_queue\" \"#{sqs}\" {"
            file_lines << "  name = \"#{sqs}\""
            file_lines << "}"
            file_lines << ""
            file_lines << "resource \"aws_sns_topic_subscription\" \"#{model.sns}-#{sqs}\" {"
            file_lines << "  topic_arn = aws_sns_topic.#{model.sns}.arn"
            file_lines << "  protocol = \"sqs\""
            file_lines << "  endpoint = aws_sqs_queue.#{sqs}.arn"
            file_lines << "}"
            file_lines << ""
          end
        end

        File.write("main.tf", file_lines.join("\n"))
      end
    end
  end
end
