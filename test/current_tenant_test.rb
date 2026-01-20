# frozen_string_literal: true

require "test_helper"

class CurrentTenantTest < ActiveSupport::TestCase
  def setup
    @account = Account.first
    Current.tenant = nil
  end

  def teardown
    Current.tenant = nil
  end

  test "sets tenant_id and tenant_type on blob creation when Current.tenant is set" do
    Current.tenant = @account

    blob = ActiveStorage::Blob.create!(
      key: SecureRandom.base58(24),
      filename: "test.pdf",
      content_type: "application/pdf",
      service_name: "tenant_s3",
      byte_size: 1024,
      checksum: Digest::MD5.base64digest("test")
    )

    assert_equal @account.id, blob.tenant_id
    assert_equal "Account", blob.tenant_type
  end

  test "does not override existing tenant_id and tenant_type" do
    other_account = Account.second || @account
    Current.tenant = @account

    blob = ActiveStorage::Blob.create!(
      key: SecureRandom.base58(24),
      filename: "test.pdf",
      content_type: "application/pdf",
      service_name: "tenant_s3",
      byte_size: 1024,
      checksum: Digest::MD5.base64digest("test"),
      tenant_id: other_account.id,
      tenant_type: "Account"
    )

    assert_equal other_account.id, blob.tenant_id
    assert_equal "Account", blob.tenant_type
  end

  test "sets tenant_id and tenant_type on blob save when missing" do
    blob = ActiveStorage::Blob.new(
      key: SecureRandom.base58(24),
      filename: "test.pdf",
      content_type: "application/pdf",
      service_name: "tenant_s3",
      byte_size: 1024,
      checksum: Digest::MD5.base64digest("test")
    )

    Current.tenant = @account
    blob.save!

    assert_equal @account.id, blob.tenant_id
    assert_equal "Account", blob.tenant_type
  end

  test "does not set tenant when Current.tenant is nil" do
    blob = ActiveStorage::Blob.create!(
      key: SecureRandom.base58(24),
      filename: "test.pdf",
      content_type: "application/pdf",
      service_name: "tenant_s3",
      byte_size: 1024,
      checksum: Digest::MD5.base64digest("test")
    )

    assert_nil blob.tenant_id
    assert_nil blob.tenant_type
  end

  test "sets tenant on attachment creation" do
    Current.tenant = @account

    blob = ActiveStorage::Blob.create!(
      key: SecureRandom.base58(24),
      filename: "test.pdf",
      content_type: "application/pdf",
      service_name: "tenant_s3",
      byte_size: 1024,
      checksum: Digest::MD5.base64digest("test")
    )

    attachment = ActiveStorage::Attachment.create!(
      name: "documents",
      record: @account,
      blob: blob
    )

    assert_equal @account.id, attachment.tenant_id
    assert_equal "Account", attachment.tenant_type
  end

  test "creates polymorphic tenant association" do
    blob = ActiveStorage::Blob.where.not(tenant_id: nil).first
    skip "No blob with tenant found" unless blob
    assert blob.respond_to?(:tenant)
    assert_not_nil blob.tenant
    assert_equal blob.tenant_id, blob.tenant.id
    assert_equal blob.tenant_type, blob.tenant.class.name
  end
end
