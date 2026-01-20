# ActiveStorage::TenantS3

Multi-tenant support for ActiveStorage with automatic tenant scoping and tenant-aware S3 storage paths.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'activestorage-tenant_s3'
```

And then execute:

```bash
$ bundle install
```

## Usage

### 1. Run the installation generator

```bash
rails generate activestorage:tenant_s3:install
```

Or manually add the migration:

```bash
rails generate migration AddTenantToActiveStorage tenant_id:bigint tenant_type:string
```

### 2. Configure storage.yml

```yaml
amazon:
  service: TenantS3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: eu-west-1
  bucket: my-bucket
```

### 3. Setup (automatic via Railtie)

The gem automatically sets up tenant support via a Railtie. No manual setup required!

If you need manual setup:

```ruby
# config/initializers/active_storage_tenant.rb
ActiveStorage::TenantS3.setup!
```

## How It Works

- Automatically sets `tenant_id` and `tenant_type` on ActiveStorage records based on `Current.tenant`
- Organizes files on S3 by tenant: `{tenant_type}/{tenant_id}/{record_type}/{key}`
- Supports polymorphic tenants (any model can be a tenant)

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
