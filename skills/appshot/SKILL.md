---
name: appshot
description: Make App Store screenshots with appshot — it frames an app's real screenshots in Apple device bezels, puts localized marketing captions over a generated background and writes store-ready PNGs for every locale. Use when the user wants to create, restyle, translate or re-render App Store screenshots for an iPhone, iPad or Mac app.
---

# appshot: App Store screenshots

appshot (https://github.com/jems19s/appshot-studio) is a command-line tool. One `appshot render` turns a
folder called a **studio** into finished store screenshots:

```
apps/<app>/config.json             device, output size, theme, background, slots
apps/<app>/captions/<locale>.json  caption text per locale
apps/<app>/assets/                 the app's real screenshots (assets/<locale>/ overrides per locale)
templates/<name>.html              layouts: caption-top, caption-bottom
devices/<id>/                      device frames, downloaded on demand
output/<app>/<locale>/<slot>.png   results
```

The user's instructions always win over the defaults below.

## 1. Check the tool

```bash
appshot --version
```

- Needs **1.2.0 or later** (that's when `init` gained the options used below), **1.4.0** for the iPhone Duo.
  Older: `brew upgrade appshot`.
- Missing: ask the user before installing anything, then `brew install jems19s/tap/appshot`.
- Renders through headless Google Chrome or Chromium, found automatically; otherwise pass `--chrome PATH` or set
  `$CHROME`. macOS 13 or later.

## 2. Find or create the studio

- Look for an existing studio first: a folder holding `apps/*/config.json`, often `appshot/` or `screenshots/` at
  the repository root. If there is one, work in it and **edit** its files. Don't run `init` again: it refuses an
  existing app, and `--overwrite` replaces its config and captions.
- Otherwise create one where the user wants it (suggest `appshot/` at the repository root):
  `mkdir appshot && cd appshot`, then add `devices/` and `output/` to its `.gitignore`. Both are re-created on
  demand, and the frame art is Apple's.
- Run commands inside the studio, or pass `--root <studio>` to any of them.

## 3. Get the raw screenshots

appshot frames screenshots; it doesn't capture them. Use what the user gives you, fastlane snapshot output
(`fastlane/screenshots/<locale>/`) or simulator captures (`xcrun simctl io booted screenshot home.png`).

- Capture at the size of the device you frame: 1320×2868 for the 6.9″ iPhone (iPhone 16/17 Pro Max simulator),
  2048×2732 for the 13″ iPad, 2853×2007 for the iPhone Duo's inner screen in landscape.
- Screenshots are taken in file name order, and each becomes a slot named `01-<file name>`, `02-…`. Plain names
  (`home.png`, `search.png`) read best; a numeric prefix is kept, giving `01-01-home`.
- `--screenshots` takes one folder. fastlane snapshot names files like `iPhone 17 Pro Max-01_map.png`, one folder
  per locale: copy the primary locale's set into a scratch folder under plain names (`map.png`, …) in the order you
  want and pass that to `init`. Then copy every locale's set, under the same plain names, into
  `apps/<app>/assets/<locale>/`.
- Localized app screens go in `assets/<locale>/` under the same file name; locales without their own folder use
  the files in `assets/`. Once every locale has its own folder, the copies in `assets/` itself are unused.
- Check which language the captures show. If all of them come from one language's build, every other locale will
  show that language's app screens under its translated captions. Tell the user and ask for captures from each
  locale's build; until they exist, keep the files in `assets/` (render needs a fallback for every locale).

## 4. Create the app

**Never run a bare `appshot init`.** It is an interactive wizard for a person at a terminal; without one it stops
with "input ended". Pass every answer as an option:

```bash
appshot init --name myapp --device "iPhone 17 Pro Max" --screenshots ./raw \
  --locale en-US --locale de-DE \
  --caption 'Every plant,\n*happily watered*' --caption 'Care plans *that stick*'
```

- `--device` takes the frame name fastlane uses and downloads it if needed. `appshot devices list` prints every
  name. Names match whole words: "iPhone 17" is not the 17 Pro. It also takes the id of an installed pack, such as
  one made with `appshot devices add` (the iPhone Duo, below).
- `--caption`: one per screenshot, in file name order; the rest start empty. Every locale starts with the same
  text, so translate afterwards (step 5).
- `--color`: the color part of the frame name, lowercase with hyphens: "Apple iPhone 17 Pro Max Deep Blue" →
  `--color deep-blue`. Without it you get the pack's default (silver where there is one). A wrong color fails
  after the download and lists the colors the pack has.
- Optional: `--size WIDTHxHEIGHT` (default: the device's screen size, which is the size App Store Connect asks
  for), `--overwrite`.
- Each slot's caption key is its screenshot's file name without `.png`, lowercase with hyphens: `map.png` →
  `map`. `config.json` lists them under `slots`.

### iPhone Duo

fastlane's frame collection has no iPhone Duo, and Apple's Duo bezels can't be passed on (Apple's design resources
license), so they come from Apple, downloaded by the user:

1. Ask the user to download **iPhone Duo** from the product bezels on https://developer.apple.com/design/resources/
   and open the DMG. Don't download it yourself or accept Apple's license on their behalf.
2. Make a pack from the bezel matching the captures, one `<color>=<file>` per color:
   `appshot devices add iphone-duo "star-white=<…>/iPhone Duo - Star White - Inner Open Landscape.png"`.
   Sizes App Store Connect takes: inner screen 2853×2007 or 2007×2853 (*Inner Open Landscape* / *Portrait*),
   outer screen 2034×1398 or 1398×2034 (*Outer Closed Landscape* / *Portrait*); one pack id per bezel.
3. `appshot init --name <app> --device iphone-duo --screenshots <duo captures> …` as above; the size and the
   device's fit follow from the pack.
4. Keep `devices/` out of git. fastlane deliver can't upload Duo screenshots yet; the user uploads them in App Store
   Connect.

## 5. Write the captions

`apps/<app>/captions/<locale>.json` maps each slot's `caption` key to its text:

```json
{
  "home": { "title": "Every plant,\n*happily watered*" },
  "care": { "title": "Care plans\n*that stick*", "subtitle": "Reminders that match each plant's rhythm" }
}
```

`*…*` colors a span with the theme's accent, `\n` breaks the line, `subtitle` is optional.

What makes a caption work:
- One idea per screenshot: the benefit the screen shows, not a list of features.
- Short: two lines of 2–4 words. People see the first two or three screenshots in search results, so lead
  with the strongest.
- True: describe only what the app really does and what that screen really shows.
- Translate for each market, not word for word, and keep lengths close to the original. Ask the user for
  existing App Store copy or app strings first; reuse their wording.
- For long languages, set `"captionFit": "shrink"` in `theme` (step 6) rather than shortening the meaning away.
- `init` leaves room for a two-line title only. If you add subtitles, make room for them (step 6): at the default
  caption sizes on 1320×2868, a two-line title plus a one-line subtitle fits with `layout.deviceWidth` 1080 and
  `layout.deviceTop` 550 (`caption-top`). Moving the device down without shrinking it pushes it off the bottom.

## 6. Style it

Everything is in `apps/<app>/config.json`; the full key list is in [reference.md](reference.md). Usual edits:

- `theme.accent` and `theme.headlineColor`: take them from the app (the asset catalog's AccentColor, brand
  colors in code or design files) instead of inventing a palette. Given only an accent, keep the default dark
  headline color: the accent goes on the `*…*` span.
- `background`: `mesh` (9 colors on a 3×3 grid), `solid`, `linear` (stops + angle) or `image` (a PNG in
  `assets/`). With only one brand color to go on, build the mesh from very light tints of it (roughly 85–95%
  white) mixed with one or two neutral or neighboring tints, so the headline keeps strong contrast.
- Device placement: `layout.deviceWidth` / `deviceTop` / `deviceLeft`. Push `deviceTop` past the canvas to crop
  the phone at the bottom; go negative to crop at the top.
- Per slot: `template` (`caption-top` or `caption-bottom`), `tilt` in degrees, and its own `deviceWidth` /
  `deviceTop` / `deviceLeft`. Render a tilted device smaller so its corners stay inside the canvas.
- Fonts: `fonts` points at the app's own TTF/OTF files; without it the system font is used.

## 7. Render and look at every image

```bash
appshot render                                 # every locale and slot (--app NAME when apps/ holds several)
appshot render --locale de-DE --slot 01-home   # one image while iterating
```

Open the PNGs in `output/<app>/<locale>/` and check each one yourself before calling it done:
- the caption doesn't touch or overlap the device, in every locale;
- nothing is cut off that shouldn't be (device edges, caption lines, tilted corners);
- the headline is readable when the image is shrunk to about 200 px wide, the size of a search-result thumbnail
  (subtitles may be small there; they are read on the product page);
- `render`'s output: `caption scaled to N%` after an image means auto-fit shrank that caption. Below about 90%,
  make room (move the device down, step 6) or shorten the text instead of shipping small captions. A warning that
  a caption still collides at the floor means it must change.

## 8. Hand off

appshot doesn't upload. Copy only the `*.png` files (`output/` also holds a hidden `.bg.bmp` scratch file).
They have no alpha channel (App Store Connect rejects screenshots with transparency); keep it that way.

- fastlane deliver uploads everything in `fastlane/screenshots/<locale>/` (App Store locale codes: `en-US`,
  `de-DE`, …). If fastlane snapshot also writes its raw captures there, deliver would upload raw and framed images
  together, and the next snapshot run may clear the framed ones. Ask the user before moving anything; the usual fix
  is raw captures in their own folder (`output_directory` in the Snapfile) and only appshot's output in
  `fastlane/screenshots/`.
- Without fastlane, the user uploads the files in App Store Connect.

Tell the user where the files are, what you changed, and anything wrong you noticed in the app screens themselves
(untranslated text, cut-off content): appshot frames what it's given.

## When something fails

- `Chrome not found`: install Google Chrome, or pass `--chrome PATH`.
- `no frame matches "…"`: the error lists the candidates; use one of those names.
- macOS says "'Terminal' was prevented from modifying apps on your Mac": harmless. Chrome's auto-updater tried to
  update Chrome itself. Renders are unaffected.
- `apps/<app> already exists`: edit that app instead, or pass `--overwrite` only if the user agrees to replace
  its config and captions.
