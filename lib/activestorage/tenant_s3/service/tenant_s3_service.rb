# frozen_string_literal: true

require "active_storage/service/s3_service"

module ActiveStorage
  module TenantS3
    module Service
      # TenantS3Service
      # Extends ActiveStorage::Service::S3Service to organize files by tenant and record type on S3
      #
      # Files are stored in: {tenant_type}/{tenant_id}/{namespace}/{class_name}/{key}
      # Example: Account/123/inventory/inventory_items/abc123def456
      # Falls back to: {tenant_type}/{tenant_id}/ActiveStorage/{key} if record type unavailable
      # Note: Record types are split by namespace (e.g., "Inventory::InventoryItem" -> "inventory/inventory_items")
      #
      # Usage in config/storage.yml:
      #   amazon:
      #     service: TenantS3
      #     access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
      #     secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
      #     region: eu-west-1
      #     bucket: my-bucket
      #
      # Or configure via initializer:
      #   ActiveStorage::Blob.service = ActiveStorage::TenantS3::Service::TenantS3Service.new(
      #     access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      #     secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      #     region: 'eu-west-1',
      #     bucket: 'my-bucket'
      #   )
      class TenantS3Service < ActiveStorage::Service::S3Service
        # Override download to check both new path and fallback "ActiveStorage" path
        def download(key, &block)
          object = find_object_with_fallback(key)
          return object.get(&block) if object

          # If no object found, raise error (matching parent behavior)
          raise ActiveStorage::FileNotFoundError
        end

        # Override exist? to check both new path and fallback "ActiveStorage" path
        def exist?(key)
          object = find_object_with_fallback(key)
          object&.exists? || false
        end

        # Override url to check both new path and fallback "ActiveStorage" path
        def url(key, expires_in:, filename:, content_type:, disposition:, **options)
          # Try to find existing object with fallback
          object = find_object_with_fallback(key)

          # If found, use that object; otherwise use object_for to get the path (for new uploads)
          object ||= object_for(key)

          # Convert expires_in to seconds (handles ActiveSupport::Duration objects)
          expires_seconds = expires_in.respond_to?(:to_i) ? expires_in.to_i : expires_in

          object.presigned_url(
            :get,
            expires_in: expires_seconds,
            response_content_disposition: content_disposition_with(filename: filename, type: disposition),
            response_content_type: content_type
          )
        end

        private

        def object_for(key)
          blob = ActiveStorage::Blob.find_by(key: key)
          tenant_info = extract_tenant_info(blob)
          record_type = extract_record_type(blob)

          build_s3_path(key, tenant_info, record_type)
        end

        def extract_tenant_info(blob)
          if blob&.tenant_type.present? && blob&.tenant_id.present?
            { type: blob.tenant_type, id: blob.tenant_id }
          elsif ::Current.tenant.present?
            tenant = ::Current.tenant
            tenant_info = { type: tenant.class.name, id: tenant.id }

            # Update blob with tenant info if it's missing (for future lookups)
            if blob && (blob.tenant_id.nil? || blob.tenant_type.nil?)
              blob.update_columns(tenant_id: tenant_info[:id], tenant_type: tenant_info[:type])
            end

            tenant_info
          end
        end

        def extract_record_type(blob)
          return nil unless blob

          # Get the first attachment to determine record type
          attachment = blob.attachments.first
          attachment&.record_type
        end

        def sanitize_record_type(record_type)
          return nil unless record_type.present?

          record_type.tableize.gsub(/[^a-zA-Z0-9_\/]/, "")
        end

        def build_s3_path(key, tenant_info, record_type, use_fallback: false)
          if tenant_info&.dig(:type).present? && tenant_info&.dig(:id).present?
            path_parts = [tenant_info[:type], tenant_info[:id].to_s]

            # Add sanitized record type if available, otherwise use "ActiveStorage" as fallback
            # If use_fallback is true, always use "ActiveStorage" (for backward compatibility)
            if use_fallback || record_type.blank?
              path_parts << "ActiveStorage"
            else
              sanitized_type = sanitize_record_type(record_type)
              # Split the sanitized type by "/" to add each part as a separate path segment
              # Example: "inventory/inventory_items" -> ["inventory", "inventory_items"]
              path_parts.concat(sanitized_type.split("/"))
            end

            path_parts << key

            bucket.object File.join(*path_parts)
          else
            # Log warning if no tenant information available
            blob = ActiveStorage::Blob.find_by(key: key)
            Rails.logger.warn "ActiveStorage::TenantS3::Service::TenantS3Service: No tenant information available for key #{key}. Using root path." if blob.present?
            # Fallback to root path
            bucket.object key
          end
        end

        # Find object by checking both new path (with record type) and fallback "ActiveStorage" path
        def find_object_with_fallback(key)
          blob = ActiveStorage::Blob.find_by(key: key)
          tenant_info = extract_tenant_info(blob)
          record_type = extract_record_type(blob)

          # Try new path first (with record type)
          if record_type.present? && tenant_info.present?
            object = build_s3_path(key, tenant_info, record_type, use_fallback: false)
            return object if object.exists?
          end

          # Fallback to "ActiveStorage" path for backward compatibility with existing files
          if tenant_info.present?
            object = build_s3_path(key, tenant_info, nil, use_fallback: true)
            return object if object.exists?
          end

          # Final fallback: try root path (for files uploaded before tenant support)
          root_object = bucket.object(key)
          return root_object if root_object.exists?

          nil
        end
      end
    end
  end
end
