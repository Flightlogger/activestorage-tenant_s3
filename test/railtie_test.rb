# frozen_string_literal: true

require "test_helper"

class RailtieTest < ActiveSupport::TestCase
  test "railtie is defined" do
    assert defined?(ActiveStorage::TenantS3::Railtie)
    assert_equal Rails::Railtie, ActiveStorage::TenantS3::Railtie.superclass
  end

  test "railtie automatically sets up on Rails initialization" do
    # The setup should have been called during test_helper initialization
    assert_includes ActiveStorage::Blob.included_modules, ActiveStorage::TenantS3::CurrentTenant
  end
end
