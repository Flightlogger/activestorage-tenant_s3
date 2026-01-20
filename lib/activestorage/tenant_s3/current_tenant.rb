# frozen_string_literal: true

module ActiveStorage
  module TenantS3
    # CurrentTenant concern
    # Automatically sets tenant_id and tenant_type on ActiveStorage records
    # based on Current.tenant
    #
    # Usage in initializer:
    #   ActiveStorage::TenantS3.setup!
    #
    # Or manually:
    #   ActiveSupport.on_load(:active_storage_blob) do
    #     include ActiveStorage::TenantS3::CurrentTenant
    #   end
    module CurrentTenant
      extend ActiveSupport::Concern

      included do
        # Polymorphic tenant support (tenant_id + tenant_type)
        if has_attribute?("tenant_id") && has_attribute?("tenant_type")
          belongs_to :tenant, polymorphic: true, optional: true

          # Set tenant_id and tenant_type using multiple hooks to catch all cases
          # ActiveStorage may bypass validations, so we use after_initialize and before_save
          after_initialize :set_tenant_from_current, if: :new_record?
          before_save :set_tenant_from_current, if: -> { tenant_id.nil? || tenant_type.nil? }

          private

          def set_tenant_from_current
            return unless ::Current.tenant.present?
            return if tenant_id.present? && tenant_type.present?

            tenant = ::Current.tenant
            self.tenant_id = tenant.id
            self.tenant_type = tenant.class.name
          end
        end
      end
    end
  end
end
