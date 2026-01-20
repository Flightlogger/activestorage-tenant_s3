# frozen_string_literal: true

module ActiveStorage
  module TenantS3
    # Railtie to automatically setup ActiveStorage::TenantS3 when Rails loads
    class Railtie < Rails::Railtie
      initializer "activestorage.tenant_s3.setup" do
        ActiveStorage::TenantS3.setup!
      end
    end
  end
end
