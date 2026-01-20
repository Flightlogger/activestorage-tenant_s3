# frozen_string_literal: true

# ActiveStorage::TenantS3
# Adds multi-tenant support to ActiveStorage with automatic tenant scoping
# and tenant-aware S3 storage paths
#
# Usage:
#   1. Add tenant_id and tenant_type to ActiveStorage tables via migration
#   2. Include CurrentTenant concern in initializer
#   3. Configure TenantS3Service in storage.yml
#
module ActiveStorage
  module TenantS3
    require "activestorage/tenant_s3/version"
    require "activestorage/tenant_s3/current_tenant"
    require "activestorage/tenant_s3/service/tenant_s3_service"

    class Error < StandardError; end

    # Configure ActiveStorage models to include CurrentTenant
    def self.setup!
      ActiveSupport.on_load(:active_storage_blob) do
        include ActiveStorage::TenantS3::CurrentTenant
      end

      ActiveSupport.on_load(:active_storage_attachment) do
        include ActiveStorage::TenantS3::CurrentTenant
      end

      ActiveSupport.on_load(:active_storage_variant_record) do
        include ActiveStorage::TenantS3::CurrentTenant
      end
    end
  end
end

# Auto-load Railtie if Rails is available
require "activestorage/tenant_s3/railtie" if defined?(Rails)
