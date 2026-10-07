# Changelog

All notable changes to appshot-studio are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-10-07

### Added

- A skill for AI coding agents in `skills/appshot/`, installable with `npx skills add jems19s/appshot-studio`: it walks the agent through finding the raw screenshots, setting up the app without the wizard, writing and translating captions, styling, rendering and checking every image.

### Fixed

- `init --color` and `devices fetch --colors` take color names the way `devices list` prints them ("Deep Blue") as well as `deep-blue`.
- With output piped (CI logs, coding agents), progress lines appeared only when the command ended, after any error. Output is now line-buffered, so it shows up as it happens and in order.

## [1.2.2] - 2026-10-07

### Changed

- Device frames are read, and the screen mask written, with macOS's own ImageIO instead of the swift-png package, which is no longer a dependency. Masks are pixel-identical (checked on iPhone, iPad, MacBook and Pixel frames) and 10–18% smaller.

### Fixed

- `devices fetch` from a debug build — `swift run`, as in CI and when running from a clone — spent 2–8 minutes compressing the screen mask. It now takes about 2 seconds, as the Homebrew build already did.

## [1.2.1] - 2026-10-07

### Fixed

- `devices fetch`, `devices list` and the wizard's device step read the frame list from GitHub's API, which allows 60 requests an hour per network address without a login. On shared machines such as GitHub Actions runners that limit runs out: the fetch failed with "HTTP 403" or took minutes. The list now comes from the `files.json` that fastlane publishes next to the frames (the same file fastlane's frameit uses), which has no such limit.

## [1.2.0] - 2026-10-07

### Added

- `appshot init --name <app> --device <name> --screenshots <folder>` scaffolds an app without the wizard, for scripts, CI and coding agents. Optional `--color`, `--size WIDTHxHEIGHT`, repeatable `--locale` and `--caption`, and `--overwrite`; the device is fetched when it isn't installed.

### Changed

- The README's quick start begins with the Homebrew install; running from a clone moved below it.

### Fixed

- The wizard asked the same question forever when its input ended (a script or pipe that ran out of answers). It now stops with an error naming the question.
- With output piped, menu options appeared after the prompt that asks for them, so a piped run saw "Enter a number" with no list.

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

[1.3.0]: https://github.com/jems19s/appshot-studio/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/jems19s/appshot-studio/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/jems19s/appshot-studio/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/jems19s/appshot-studio/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/jems19s/appshot-studio/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/jems19s/appshot-studio/releases/tag/v1.0.0
