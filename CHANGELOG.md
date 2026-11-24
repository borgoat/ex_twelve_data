# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-11-24

### Fixed

- `subscribe/2` and `unsubscribe/2` accept a list of strings again: it is sent as a
  comma-delimited string, since Twelve Data rejects arrays of strings with
  `Cant parse message` ([#3](https://github.com/borgoat/ex_twelve_data/pull/3)).
- A failed unsubscribe or reset no longer crashes the client with a `WebSockex.BadResponseError`.
  A failed heartbeat now exits with `{:heartbeat_failed, status}` instead, so the supervisor restarts it.
- Status events (`ok`, `warning`, `error`) now log the failed symbols and server messages.
- Prices no longer stop silently after a reconnect: Twelve Data drops subscriptions with the
  connection, and `SubscriptionsManager` now resubscribes everything when told by the new
  `RealTimePrices.notify_on_reconnect/2`.
- Reconnect attempts back off (1, 2, then 3s) instead of looping as fast as possible,
  and each reconnect no longer starts an additional heartbeat loop.
- `SubscriptionsManager` no longer sends empty unsubscribe requests (burning the 100 events/minute
  quota) when the provider returns more symbols than `max_subscriptions`: it subscribes up to the limit.

### Changed

- Requires `castore ~> 1.0` and `websockex ~> 0.5`.
- `SubscriptionsManager` no longer needs the `:symbols_extended` option (it is ignored):
  string symbols are joined by `RealTimePrices` itself.
- Development environment is a Nix flake devshell (`nix develop` or direnv `use flake`),
  replacing `shell.nix` and lorri.
- GitHub Actions CI tests every pull request and releases from `main` (Hex, tag and GitHub release)
  whenever `mix.exs` declares a version that has no tag yet.

## [0.4.0] - 2023-11-22

### Added

- `ExTwelveData.Supervisor`, running `RealTimePrices` and `SubscriptionsManager` together.

### Fixed

- A failed subscription (e.g. an unknown symbol) no longer stops the client.

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

[unreleased]: https://github.com/borgoat/ex_twelve_data/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/borgoat/ex_twelve_data/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/borgoat/ex_twelve_data/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/borgoat/ex_twelve_data/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/borgoat/ex_twelve_data/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/borgoat/ex_twelve_data/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/borgoat/ex_twelve_data/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/borgoat/ex_twelve_data/releases/tag/v0.1.0
