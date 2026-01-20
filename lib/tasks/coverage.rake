# frozen_string_literal: true

namespace :coverage do
  desc "Generate XML coverage report for Codacy"
  task :xml do
    require "simplecov"
    require "simplecov-cobertura"

    # Load SimpleCov results
    resultset_path = "coverage/.resultset.json"
    unless File.exist?(resultset_path)
      puts "Error: Coverage results not found at #{resultset_path}"
      puts "Run tests with COVERAGE=true first"
      exit 1
    end

    # Configure SimpleCov
    SimpleCov.configure do
      command_name "Unit Tests"
    end

    # Load and format results
    begin
      result = SimpleCov::ResultMerger.merge_results(resultset_path)
      formatter = SimpleCov::Formatter::CoberturaFormatter.new
      formatter.format(result)
      puts "✓ XML coverage generated at coverage/coverage.xml"
    rescue => e
      puts "Error generating XML: #{e.message}"
      puts e.backtrace.first(5)
      exit 1
    end
  end
end
