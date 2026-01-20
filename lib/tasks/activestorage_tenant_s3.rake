# frozen_string_literal: true

namespace :activestorage_tenant_s3 do
  desc "Add tenant_id and tenant_type to ActiveStorage tables"
  task :install do
    puts "Generating migration to add tenant support to ActiveStorage..."
    system "bin/rails generate migration AddTenantToActiveStorage tenant_id:bigint tenant_type:string"
    puts "\nMigration generated. Please review and run: bin/rails db:migrate"
    puts "\nAfter migration, add indexes:"
    puts "  add_index :active_storage_blobs, [:tenant_type, :tenant_id]"
    puts "  add_index :active_storage_attachments, [:tenant_type, :tenant_id]"
  end
end
