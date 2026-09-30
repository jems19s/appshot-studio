# Changelog

All notable changes to appshot-studio are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-09-30

### Added

- Caption auto-fit, off by default: with `"captionFit": "shrink"` in `theme`, a caption that would run into the device shrinks — title and subtitle together, re-wrapping as it goes — until it keeps `captionFitGap` (40px) clear, per locale and per slot, tilted devices included. It never goes below `captionMinScale` (70%); a caption that still collides there renders at that floor and `render` prints a warning naming the app, locale and slot.
- `appshot render` without `--app` renders the only app in `apps/`; with several it lists them.
- Unit tests (`swift test`), run in CI.
- This changelog.

### Changed

- The Homebrew formula installs the prebuilt universal binary from the GitHub release instead of compiling, so Xcode is no longer needed.
- `devices fetch` and the `init` wizard report unknown or ambiguous device names with the candidate models.
- The wizard's number prompts say why an answer was rejected instead of asking again silently.
- The demo's German home caption is longer, and the demo turns auto-fit on to show it.
- The README states macOS as the requirement.

### Fixed

- `devices fetch` matched device names as substrings: "iPhone 17 Pro" also collected the iPhone 17 Pro Max frames as extra colors, and "iPhone 17" collected the Pro models. Names now match whole words and only that model's colors, so "iPhone 16" never matches "iPhone 16e".
- A failed `devices fetch` could leave a half-written pack that `devices` silently skipped. Packs are now built in a temporary directory and moved into `devices/` once complete.
- `appshot render` in a fresh studio failed looking for an app called `demo`.
- The wizard's linear-gradient angle rejected 0 and negative values; it now takes −360 to 360.
- The README's clone URL pointed at the wrong account.

## [1.0.0] - 2026-07-15

### Added

- `appshot init`: interactive wizard (arrow-key selects, esc goes back) that scaffolds an app — device fetch with automatic screen measurement, screenshots to slots, locales, captions, theme.
- `appshot render`: config-driven rendering of real screenshots in real bezels, with localized captions (title and optional subtitle), mesh, linear, solid or image backgrounds, and per-slot device size, position, tilt and cropping at any edge.
- `appshot devices`: fetch any Apple frame from fastlane/frameit-frames, with the screen cutout measured automatically.
- Two templates: `caption-top` and `caption-bottom`.
- Rendering through headless Chrome.

[1.1.0]: https://github.com/jems19s/appshot-studio/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/jems19s/appshot-studio/releases/tag/v1.0.0
