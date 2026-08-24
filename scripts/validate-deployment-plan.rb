# frozen_string_literal: true

require "yaml"

plan_path, expected_network, expected_deployer = ARGV

if plan_path.nil? || expected_network.nil? || expected_deployer.nil? || ARGV.length != 3
  abort "usage: ruby scripts/validate-deployment-plan.rb PLAN_PATH NETWORK DEPLOYER"
end

unless %w[testnet mainnet].include?(expected_network)
  abort "deployment plan network must be testnet or mainnet"
end

begin
  plan = YAML.safe_load_file(plan_path, permitted_classes: [], aliases: false)
rescue StandardError
  abort "deployment plan could not be parsed safely"
end

abort "deployment plan must be a YAML object" unless plan.is_a?(Hash)
abort "deployment plan network mismatch" unless plan["network"] == expected_network
abort "deployment plan deployer mismatch" unless plan["deployer"] == expected_deployer

expected_prefix_pattern = expected_network == "testnet" ? "(?:ST|SN)" : "(?:SP|SM|ST|SN)"
canonical_address_pattern = /\A#{expected_prefix_pattern}[0-9A-Z]{39}\z/
unless expected_deployer.match?(canonical_address_pattern)
  abort "deployment plan deployer is not a canonical-format address for the selected network"
end

publish_entries = []
walk = nil
walk = lambda do |value|
  case value
  when Hash
    publish_entries << value["contract-publish"] if value.key?("contract-publish")
    value.each_value { |child| walk.call(child) }
  when Array
    value.each { |child| walk.call(child) }
  end
end
walk.call(plan)

abort "deployment plan must contain at least one contract-publish entry" if publish_entries.empty?

publish_entries.each do |publish|
  unless publish.is_a?(Hash) && publish["expected-sender"] == expected_deployer
    abort "deployment plan contract-publish expected-sender mismatch"
  end
end

puts "Deployment plan semantic binding passed"
