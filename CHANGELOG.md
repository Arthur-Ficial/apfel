# Changelog

All notable changes to this project will be documented in this file.

The format is based on [https://keepachangelog.com/en/1.1.0/](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [https://semver.org/](https://semver.org/).

## [Unreleased]

### Added

- `ApfelCore` is now exposed as a public Swift Package library product.
- Added downstream-consumer smoke coverage for importing `ApfelCore` from another package.
- Added smoke coverage for the runnable `Examples/` targets that back the public `ApfelCore` docs.
- Added DocC, examples, and package metadata needed to publish `ApfelCore` cleanly.

### Changed

- Replaced the unsafe global debug flag with `ApfelDebugConfiguration`.
- Serialized same-reader `BufferedLineReader` access so the type is safely `Sendable`.
- Narrowed package-only streaming and prompt-processing helpers out of the public semver surface.

## [1.0.5] - 2026-04-22

### Added

- Current released CLI, server, and chat functionality.
