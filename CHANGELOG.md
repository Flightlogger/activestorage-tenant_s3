# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-01-20

### Changed
- Upgraded `simplecov-cobertura` from 2.1 to 3.1 for compatibility with newer `rexml` versions
- Replaced MD5 with SHA256 in test fixtures for improved security compliance

### Fixed
- Fixed SimpleCov XML coverage generation in CI
- Improved test reliability by ensuring proper fixture data setup
- Fixed CI workflow to properly collect coverage from all test matrix combinations

## [0.1.0] - 2026-01-20

### Added
- Initial release
- Multi-tenant support for ActiveStorage
- Automatic tenant scoping via `Current.tenant`
- Tenant-aware S3 storage paths
- Support for polymorphic tenants
- Railtie for automatic setup
