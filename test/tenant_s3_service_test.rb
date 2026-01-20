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

    # Ensure we have a blob without tenant for tests that need it
    # Find the fixture blob by looking for one with the expected filename
    @blob_without_tenant = ActiveStorage::Blob.find_by(filename: "old_file.pdf") ||
                           ActiveStorage::Blob.where(tenant_id: nil).first

    # If still not found, create one
    unless @blob_without_tenant
      @blob_without_tenant = ActiveStorage::Blob.create!(
        key: SecureRandom.base58(24),
        filename: "old_file.pdf",
        content_type: "application/pdf",
        service_name: "tenant_s3",
        byte_size: 512,
        checksum: Digest::MD5.base64digest("old"),
        tenant_id: nil,
        tenant_type: nil
      )
    end

    # Reset tenant info in case previous test modified it
    @blob_without_tenant.update_columns(tenant_id: nil, tenant_type: nil) if @blob_without_tenant.tenant_id.present?

    Current.tenant = nil
  end

  def teardown
    Current.tenant = nil
  end

  test "builds S3 path with tenant structure" do
    # Use a blob that doesn't have an attachment, so it uses "ActiveStorage" fallback
    # Create a temporary blob without attachments for this test
    blob = ActiveStorage::Blob.create!(
      key: SecureRandom.base58(24),
      filename: "test_no_attachment.pdf",
      content_type: "application/pdf",
      service_name: "tenant_s3",
      byte_size: 1024,
      checksum: Digest::MD5.base64digest("test"),
      tenant_id: @account.id,
      tenant_type: "Account"
    )

    object = @service.send(:object_for, blob.key)

    expected_path = "#{blob.tenant_type}/#{blob.tenant_id}/ActiveStorage/#{blob.key}"
    assert_equal expected_path, object.key
  end

  test "builds S3 path with record type when attachment exists" do
    attachment = active_storage_attachments(:attachment_one)
    account = accounts(:one)
    # Get the blob and ensure it has tenant info in the database
    blob = ActiveStorage::Blob.find(attachment.blob_id)
    blob.update_columns(tenant_id: account.id, tenant_type: "Account")
    # Clear any caches
    blob.association(:attachments).reset if blob.association(:attachments).loaded?

    # Verify blob has tenant info in DB
    db_blob = ActiveStorage::Blob.find(blob.id)
    assert db_blob.tenant_id.present?, "Blob must have tenant_id in database"
    assert db_blob.tenant_type.present?, "Blob must have tenant_type in database"

    # Call object_for which will find the blob fresh from DB
    object = @service.send(:object_for, blob.key)
    # The path will use the sanitized record type (pluralized)
    expected_path = "#{db_blob.tenant_type}/#{db_blob.tenant_id}/accounts/#{blob.key}"
    assert_equal expected_path, object.key
  end

  test "extracts tenant info from blob" do
    tenant_info = @service.send(:extract_tenant_info, @blob)

    assert_equal @blob.tenant_type, tenant_info[:type]
    assert_equal @blob.tenant_id, tenant_info[:id]
  end

  test "extracts tenant info from Current.tenant when blob has no tenant" do
    # Reset tenant info to ensure test starts with clean state
    @blob_without_tenant.update_columns(tenant_id: nil, tenant_type: nil)

    Current.tenant = @account

    tenant_info = @service.send(:extract_tenant_info, @blob_without_tenant)

    assert_equal "Account", tenant_info[:type]
    assert_equal @account.id, tenant_info[:id]

    # Verify blob was updated
    @blob_without_tenant.reload
    assert_equal @account.id, @blob_without_tenant.tenant_id
    assert_equal "Account", @blob_without_tenant.tenant_type
  end

  test "returns nil tenant info when no tenant available" do
    # Ensure blob has no tenant info
    @blob_without_tenant.update_columns(tenant_id: nil, tenant_type: nil)
    tenant_info = @service.send(:extract_tenant_info, @blob_without_tenant)

    assert_nil tenant_info
  end

  test "extracts record type from attachment" do
    attachment = active_storage_attachments(:attachment_one)
    blob = attachment.blob

    record_type = @service.send(:extract_record_type, blob)
    assert_equal attachment.record_type, record_type
  end

  test "returns nil record type when no attachment exists" do
    # Ensure blob has no tenant info and no attachments
    @blob_without_tenant.update_columns(tenant_id: nil, tenant_type: nil)
    record_type = @service.send(:extract_record_type, @blob_without_tenant)
    assert_nil record_type
  end

  test "sanitizes record type correctly" do
    assert_equal "accounts", @service.send(:sanitize_record_type, "Account")
    assert_equal "inventory/inventory_items", @service.send(:sanitize_record_type, "Inventory::InventoryItem")
    assert_nil @service.send(:sanitize_record_type, nil)
    assert_nil @service.send(:sanitize_record_type, "")
  end

  test "builds path with fallback to ActiveStorage when record type is nil" do
    tenant_info = { type: @blob.tenant_type, id: @blob.tenant_id }

    object = @service.send(:build_s3_path, @blob.key, tenant_info, nil, use_fallback: true)
    expected_path = "#{@blob.tenant_type}/#{@blob.tenant_id}/ActiveStorage/#{@blob.key}"

    assert_equal expected_path, object.key
  end

  test "builds path with record type when available" do
    tenant_info = { type: @blob.tenant_type, id: @blob.tenant_id }

    object = @service.send(:build_s3_path, @blob.key, tenant_info, "Account", use_fallback: false)
    # tableize converts "Account" to "accounts" (plural)
    expected_path = "#{@blob.tenant_type}/#{@blob.tenant_id}/accounts/#{@blob.key}"

    assert_equal expected_path, object.key
  end

  test "builds root path when no tenant info available" do
    # Ensure blob has no tenant info
    @blob_without_tenant.update_columns(tenant_id: nil, tenant_type: nil)
    object = @service.send(:build_s3_path, @blob_without_tenant.key, nil, nil, use_fallback: false)
    assert_equal @blob_without_tenant.key, object.key
  end

  test "find_object_with_fallback builds correct paths" do
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
      result = @service.send(:find_object_with_fallback, @blob.key)
      # Should return nil when object doesn't exist
      assert_nil result
    end
  end
end
