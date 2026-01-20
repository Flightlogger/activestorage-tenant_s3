# frozen_string_literal: true

# ActiveStorage service adapter for TenantS3
# This file exists so ActiveStorage can find the service when storage.yml specifies service: TenantS3
# The actual implementation is in ActiveStorage::TenantS3::Service::TenantS3Service

require "active_storage/service/s3_service"
# Require the main module first so ActiveStorage::TenantS3 is available
require "activestorage/tenant_s3"

module ActiveStorage
  # TenantS3Service - Multi-tenant S3 service that organizes files by tenant structure
  # This inherits from ActiveStorage::TenantS3::Service::TenantS3Service
  # Files are stored in: {tenant_type}/{tenant_id}/ActiveStorage/{key}
  # Note: Service is a class, not a module, so we use Service::ClassName syntax
  class Service::TenantS3Service < ActiveStorage::TenantS3::Service::TenantS3Service
    # The implementation is inherited from ActiveStorage::TenantS3::Service::TenantS3Service
  end
end
