# frozen_string_literal: true

require_relative "lib/activestorage/tenant_s3/version"

Gem::Specification.new do |spec|
  spec.name = "activestorage-tenant_s3"
  spec.version = ActiveStorage::TenantS3::VERSION
  spec.authors = [ "FlightLogger" ]
  spec.email = [ "dev@flightlogger.net" ]

  spec.summary = "Multi-tenant support for ActiveStorage with automatic tenant scoping and tenant-aware S3 storage paths"
  spec.description = <<~DESC
    ActiveStorage::TenantS3 adds multi-tenant support to ActiveStorage by:
    - Automatically setting tenant_id/tenant_type on ActiveStorage records
    - Organizing files by tenant structure on S3: {tenant_type}/{tenant_id}/ActiveStorage/{key}
    - Supporting polymorphic tenants
  DESC
  spec.homepage = "https://github.com/Flightlogger/activestorage-tenant_s3"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  # Dependencies
  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "aws-sdk-s3", ">= 1.0"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "sqlite3", "~> 2.0"
end
