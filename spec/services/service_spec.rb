# frozen_string_literal: true

require "rails_helper"

RSpec.describe Service do
  let(:service_class) do
    Class.new do
      include Service

      attr_reader :result

      def initialize(value)
        @value = value
      end

      def perform
        @result = @value * 2
      end

      def self.name = "DoublingService"
    end
  end

  it "builds the service, performs it and returns the instance" do
    service = service_class.perform(21)

    expect(service).to be_a(service_class)
    expect(service.result).to eq(42)
  end

  it "raises when a service doesn't implement perform" do
    unimplemented = Class.new { include Service }

    expect { unimplemented.perform }.to raise_error(NotImplementedError, /must implement #perform/)
  end

  it "gives each service a semantic logger named after its class" do
    expect(service_class.new(1).logger).to be_a(SemanticLogger::Logger)
    expect(service_class.logger.name).to eq("DoublingService")
  end
end
