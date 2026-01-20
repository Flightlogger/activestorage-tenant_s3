# frozen_string_literal: true

require "test_helper"

class SetupTest < ActiveSupport::TestCase
  test "setup! includes CurrentTenant in ActiveStorage::Blob" do
    assert_includes ActiveStorage::Blob.included_modules, ActiveStorage::TenantS3::CurrentTenant
  end

  test "setup! includes CurrentTenant in ActiveStorage::Attachment" do
    assert_includes ActiveStorage::Attachment.included_modules, ActiveStorage::TenantS3::CurrentTenant
  end

  test "setup! includes CurrentTenant in ActiveStorage::VariantRecord" do
    assert_includes ActiveStorage::VariantRecord.included_modules, ActiveStorage::TenantS3::CurrentTenant
  end

  test "ActiveStorage::Blob has tenant association" do
    blob = ActiveStorage::Blob.where.not(tenant_id: nil).first
    skip "No blob with tenant found" unless blob
    assert blob.respond_to?(:tenant)
    assert_not_nil blob.tenant
    assert_equal blob.tenant_id, blob.tenant.id
    assert_equal blob.tenant_type, blob.tenant.class.name
  end

  test "ActiveStorage::Attachment has tenant association" do
    attachment = ActiveStorage::Attachment.where.not(tenant_id: nil).first
    skip "No attachment with tenant found" unless attachment
    assert attachment.respond_to?(:tenant)
    assert_not_nil attachment.tenant
    assert_equal attachment.tenant_id, attachment.tenant.id
    assert_equal attachment.tenant_type, attachment.tenant.class.name
  end
end
