# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

# Start SimpleCov before requiring any application code
if ENV["COVERAGE"]
  require "simplecov"

  # Clean up any existing malformed coverage files that might cause issues
  # This prevents the Cobertura formatter from trying to merge with corrupted XML
  coverage_xml = File.join(Dir.pwd, "coverage", "coverage.xml")
  if File.exist?(coverage_xml)
    begin
      # Try to validate the XML file - if it's malformed, delete it
      require "rexml/document"
      content = File.read(coverage_xml)
      # Check if file has content and is valid XML
      if content.strip.empty? || content.strip !~ /<\?xml/
        File.delete(coverage_xml)
      else
        REXML::Document.new(content)
      end
    rescue REXML::ParseException, Errno::ENOENT
      # File is malformed or doesn't exist, delete it
      File.delete(coverage_xml) if File.exist?(coverage_xml)
    end
  end

  # Always try to include XML formatter for Codacy
  begin
    require "simplecov-cobertura"
    xml_formatter_available = true
  rescue LoadError
    xml_formatter_available = false
  end

  SimpleCov.start do
    # Set command name for SimpleCov
    command_name "Unit Tests"

    add_filter "/test/"
    add_filter "/config/"
    add_filter "/vendor/"

    # Track coverage for lib directory
    add_group "Lib", "lib"

    # Configure formatters
    # In CI, don't use XML formatter during test execution to avoid conflicts.
    # XML is generated separately in CI workflow after tests complete.
    if ENV["CI"]
      # In CI, only use HTML formatter (or none) to avoid XML parsing issues
      # The XML will be generated in a separate CI step using the resultset JSON
      formatter SimpleCov::Formatter::HTMLFormatter
    elsif xml_formatter_available
      # Locally, use both HTML and XML
      formatter SimpleCov::Formatter::MultiFormatter.new([
        SimpleCov::Formatter::HTMLFormatter,
        SimpleCov::Formatter::CoberturaFormatter
      ])
    else
      # Fallback to HTML only if XML formatter not available
      formatter SimpleCov::Formatter::HTMLFormatter
    end

    # Minimum coverage threshold (optional)
    # Only enforce if we have actual coverage data
    minimum_coverage 80
  end
end

require "rails"
require "active_support"
require "active_storage/engine"
require "active_record"
require "minitest/autorun"
require "securerandom"
require "digest"

require_relative "../lib/activestorage/tenant_s3"

begin
  require "minitest/reporters"
  Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
rescue LoadError
  # minitest/reporters not available, use default reporter
end

# Set up a minimal Rails application for testing
module TestApp
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.active_support.deprecation = :stderr
    config.active_storage.service = :test
    config.active_storage.service_configurations = {
      test: {
        service: "Disk",
        root: Rails.root.join("tmp/storage")
      },
      tenant_s3: {
        service: "TenantS3",
        access_key_id: "test",
        secret_access_key: "test",
        region: "us-east-1",
        bucket: "test-bucket"
      }
    }
  end
end

# Initialize Rails
TestApp::Application.initialize!

# Set up database
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:"
)

# Create tables
ActiveRecord::Schema.define do
  create_table :accounts, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :active_storage_blobs, force: true do |t|
    t.string :key, null: false
    t.string :filename, null: false
    t.string :content_type
    t.text :metadata
    t.string :service_name, null: false
    t.bigint :byte_size, null: false
    t.string :checksum
    t.datetime :created_at, null: false
    t.bigint :tenant_id
    t.string :tenant_type
    t.index [ :key ], unique: true
  end

  create_table :active_storage_attachments, force: true do |t|
    t.string :name, null: false
    t.string :record_type, null: false
    t.bigint :record_id, null: false
    t.bigint :blob_id, null: false
    t.datetime :created_at, null: false
    t.bigint :tenant_id
    t.string :tenant_type
    t.index [ :blob_id ], name: "index_active_storage_attachments_on_blob_id"
    t.index [ :record_type, :record_id, :name, :blob_id ], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table :active_storage_variant_records, force: true do |t|
    t.bigint :blob_id, null: false
    t.string :variation_digest, null: false
    t.bigint :tenant_id
    t.string :tenant_type
    t.index [ :blob_id, :variation_digest ], name: "index_active_storage_variant_records_uniqueness", unique: true
  end
end

# Define test models
class Account < ActiveRecord::Base
  has_many_attached :documents
end

# Set up Current object for tenant tracking
class Current < ActiveSupport::CurrentAttributes
  attribute :tenant
end

# Load ActiveStorage
ActiveStorage::Blob.connection.schema_cache.clear!
ActiveStorage::Attachment.connection.schema_cache.clear!

# Include the gem's functionality
ActiveStorage::TenantS3.setup!

# Load fixtures - Rails will auto-load them from test/fixtures
# We need to make them available to test classes
module FixtureHelper
  def accounts(name)
    Account.find_by!(name: name.to_s.humanize)
  end

  def active_storage_blobs(name)
    ActiveStorage::Blob.find_by!(key: fixture_blob_key(name))
  end

  def active_storage_attachments(name)
    ActiveStorage::Attachment.find_by!(name: fixture_attachment_name(name))
  end

  private

  def fixture_blob_key(name)
    case name.to_s
    when "blob_one"
      ActiveStorage::Blob.first&.key
    when "blob_two"
      ActiveStorage::Blob.second&.key
    when "blob_without_tenant"
      ActiveStorage::Blob.where(tenant_id: nil).first&.key
    end
  end

  def fixture_attachment_name(name)
    case name.to_s
    when "attachment_one"
      "documents"
    when "attachment_two"
      "documents"
    end
  end
end

# Load fixtures manually
fixture_path = File.expand_path("fixtures", __dir__)
ActiveRecord::FixtureSet.create_fixtures(fixture_path, [ :accounts, :active_storage_blobs, :active_storage_attachments ])

# Make fixtures available to test classes
class ActiveSupport::TestCase
  include FixtureHelper
end

# Note: In CI, XML coverage is generated separately after tests complete
# (see .github/workflows/ci.yml) to avoid XML parsing conflicts during test execution.
