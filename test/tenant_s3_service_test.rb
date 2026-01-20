# frozen_string_literal: true

require "test_helper"

class TenantS3ServiceTest < ActiveSupport::TestCase
  def setup
    @service = ActiveStorage::TenantS3::Service::TenantS3Service.new(
      access_key_id: "test",
      secret_access_key: "test",
      region: "us-east-1",
      bucket: "test-bucket"
    )

    @account = Account.first
    @blob = ActiveStorage::Blob.where.not(tenant_id: nil).first
    Current.tenant = nil
  end

  def teardown
    Current.tenant = nil
  end

  test "builds S3 path with tenant structure" do
    object = @service.send(:object_for, @blob.key)

    expected_path = "#{@blob.tenant_type}/#{@blob.tenant_id}/ActiveStorage/#{@blob.key}"
    assert_equal expected_path, object.key
  end

  test "builds S3 path with record type when attachment exists" do
    attachment = ActiveStorage::Attachment.first
    skip "No attachments found" unless attachment

    blob = attachment.blob
    skip "Blob not found" unless blob

    # Mock the attachment lookup to ensure it's found
    ActiveStorage::Blob.stub(:find_by, ->(key) { key == blob.key ? blob : nil }) do
      object = @service.send(:object_for, blob.key)
      # The path will use the sanitized record type (pluralized)
      expected_path = "#{blob.tenant_type}/#{blob.tenant_id}/accounts/#{blob.key}"
      assert_equal expected_path, object.key
    end
  end

  test "extracts tenant info from blob" do
    tenant_info = @service.send(:extract_tenant_info, @blob)

    assert_equal @blob.tenant_type, tenant_info[:type]
    assert_equal @blob.tenant_id, tenant_info[:id]
  end

  test "extracts tenant info from Current.tenant when blob has no tenant" do
    blob = ActiveStorage::Blob.where(tenant_id: nil).first
    skip "No blob without tenant found" unless blob

    Current.tenant = @account

    tenant_info = @service.send(:extract_tenant_info, blob)

    assert_equal "Account", tenant_info[:type]
    assert_equal @account.id, tenant_info[:id]

    # Verify blob was updated
    blob.reload
    assert_equal @account.id, blob.tenant_id
    assert_equal "Account", blob.tenant_type
  end

  test "returns nil tenant info when no tenant available" do
    blob = ActiveStorage::Blob.where(tenant_id: nil).first
    skip "No blob without tenant found" unless blob

    tenant_info = @service.send(:extract_tenant_info, blob)

    assert_nil tenant_info
  end

  test "extracts record type from attachment" do
    attachment = ActiveStorage::Attachment.first
    skip "No attachments found" unless attachment

    blob = attachment.blob
    skip "Blob not found" unless blob

    record_type = @service.send(:extract_record_type, blob)
    assert_equal attachment.record_type, record_type
  end

  test "returns nil record type when no attachment exists" do
    blob = ActiveStorage::Blob.where(tenant_id: nil).first
    skip "No blob without tenant found" unless blob

    record_type = @service.send(:extract_record_type, blob)
    assert_nil record_type
  end

  test "sanitizes record type correctly" do
    assert_equal "accounts", @service.send(:sanitize_record_type, "Account")
    assert_equal "inventory/inventory_items", @service.send(:sanitize_record_type, "Inventory::InventoryItem")
    assert_nil @service.send(:sanitize_record_type, nil)
    assert_nil @service.send(:sanitize_record_type, "")
  end

  test "builds path with fallback to ActiveStorage when record type is nil" do
    blob = ActiveStorage::Blob.where.not(tenant_id: nil).first
    tenant_info = { type: blob.tenant_type, id: blob.tenant_id }

    object = @service.send(:build_s3_path, blob.key, tenant_info, nil, use_fallback: true)
    expected_path = "#{blob.tenant_type}/#{blob.tenant_id}/ActiveStorage/#{blob.key}"

    assert_equal expected_path, object.key
  end

  test "builds path with record type when available" do
    blob = ActiveStorage::Blob.where.not(tenant_id: nil).first
    tenant_info = { type: blob.tenant_type, id: blob.tenant_id }

    object = @service.send(:build_s3_path, blob.key, tenant_info, "Account", use_fallback: false)
    # tableize converts "Account" to "accounts" (plural)
    expected_path = "#{blob.tenant_type}/#{blob.tenant_id}/accounts/#{blob.key}"

    assert_equal expected_path, object.key
  end

  test "builds root path when no tenant info available" do
    # Find or create a blob without tenant (previous tests may have updated fixtures)
    blob = ActiveStorage::Blob.where(tenant_id: nil).first
    unless blob
      # Create a blob without tenant for this test
      blob = ActiveStorage::Blob.create!(
        key: SecureRandom.base58(24),
        filename: "test_no_tenant.pdf",
        content_type: "application/pdf",
        service_name: "tenant_s3",
        byte_size: 1024,
        checksum: Digest::MD5.base64digest("test")
      )
    end

    object = @service.send(:build_s3_path, blob.key, nil, nil, use_fallback: false)
    assert_equal blob.key, object.key
  end

  test "find_object_with_fallback builds correct paths" do
    blob = ActiveStorage::Blob.where.not(tenant_id: nil).first
    skip "No blob found" unless blob

    # Create a simple mock bucket class that returns objects that don't exist
    mock_bucket_class = Class.new do
      def object(_path)
        mock_obj = Minitest::Mock.new
        mock_obj.expect :exists?, false
        mock_obj
      end
    end

    @service.stub :bucket, mock_bucket_class.new do
      # This will try to find the object but won't make actual S3 calls
      result = @service.send(:find_object_with_fallback, blob.key)
      # Should return nil when object doesn't exist
      assert_nil result
    end
  end
end
