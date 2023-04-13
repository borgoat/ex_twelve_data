# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2023-04-13

### Added

- Support for extended format for symbols.

### Changed

- `subscribe` and `unsubscribe` now pass symbols as is (as string or array of objects).
  SubscriptionsManager can still handle a list of strings in Elixir,
  and turn it into a comma-separated string for Twelve Data.

## [0.2.1] - 2023-03-16

### Fixed

- Removed some unneeded logs.

## [0.2.0] - 2023-03-16

### Added

- This Changelog.
- `RealTimePrices.SubscriptionsManager` to comply with
  [Twelve Data rate limiting](https://support.twelvedata.com/en/articles/5194610-websocket-faq).

## [0.1.1] - 2022-10-11

### Added

- [Credo](https://github.com/rrrene/credo) and [Dyalixir](https://github.com/jeremyjh/dialyxir).

### Removed

- Documentation boilerplate.

## [0.1.0] - 2022-10-08

### Added

- `RealTimePrices` client for [Twelve Data WebSocket](https://twelvedata.com/docs#real-time-price-websocket) endpoint.

[unreleased]: https://github.com/borgoat/ex_twelve_data/compare/v0.1.0...HEAD
[0.1.1]: https://github.com/borgoat/ex_twelve_data/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/borgoat/ex_twelve_data/releases/tag/v0.1.0
