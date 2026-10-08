# appshot config reference

## apps/<app>/config.json

| Key | Meaning |
| --- | --- |
| `device` / `deviceColor` | device pack id under `devices/` and one of its colors |
| `output` | `{width, height}` canvas in px — the store's required size |
| `layout.deviceWidth` | rendered device width in px |
| `layout.deviceTop` | device y-offset in px. Negative crops the device at the top edge; past the canvas height crops it at the bottom |
| `layout.deviceLeft` | device x-offset in px (default: centered). Negative or large values crop at the left or right edge |
| `fonts` | optional. `{family, dir, faces: [{weight, style?, file}], localeFallbacks: {locale: family}}`; `dir` is absolute or relative to the app folder |
| `locales` | locale codes; each needs `captions/<locale>.json` |
| `theme` | styling tokens (below) |
| `background` | one of the background types (below) |
| `slots` | ordered shots: `{name, template, screenshot, tilt, caption}`, optionally with their own `deviceWidth` / `deviceTop` / `deviceLeft`. `name` is the output file name, `screenshot` a file in `assets/`, `caption` the key in the captions files |

Example slot list — a flat shot, then a tilted one with a smaller device so its corners stay inside the canvas:

```json
"slots": [
  { "name": "01-home", "template": "caption-top", "screenshot": "home.png", "tilt": 0, "caption": "home" },
  { "name": "02-care", "template": "caption-bottom", "screenshot": "care.png", "tilt": -6, "caption": "care",
    "deviceWidth": 1040, "deviceTop": 130 }
]
```

## theme keys and defaults

```
accent #4f7df9 · headlineColor #181a20 · captionTop 150px · captionBottom 150px
captionPadding 0 90px · captionSize 108px · captionWeight 800 · captionLineHeight 1.05
captionLetterSpacing -0.03em · subtitleSize 46px · subtitleWeight 600
subtitleColor #4b5563 · deviceShadow 0 56px 90px rgba(10,12,24,.4)
captionFit none · captionMinScale 70% · captionFitGap 40px
```

Any key set in `theme` overrides its default; extra keys are passed to templates as `{{THEME.<key>}}`.

- `captionFit: "shrink"` checks every locale × slot: a caption closer than `captionFitGap` to the device (tilted
  ones included) shrinks, title and subtitle together, down to `captionMinScale`. Captions that fit are untouched;
  one that still collides at the floor makes `render` print a warning.

## background types

- `{"type": "mesh", "colors": [9 hex colors, row by row on a 3×3 grid], "scale"?: number, "blur"?: number}`
- `{"type": "solid", "color": "#f2f4f8"}`
- `{"type": "linear", "stops": ["#e8ecf4", "#d5dcef"], "angle": 90}` — 90 runs top to bottom
- `{"type": "image", "file": "background.png"}` — a ready-made PNG in `assets/`

## templates

- `caption-top`: caption at `theme.captionTop`, device below.
- `caption-bottom`: device at the top, caption anchored at `theme.captionBottom`.

A new layout is a new `templates/<name>.html` referenced from a slot. Templates are HTML/CSS filled with
`{{W}} {{H}} {{FONT_FACES}} {{FONT_STACK}} {{BG_IMG}} {{FRAME}} {{MASK}} {{SCREEN}} {{TILT}} {{DEV_W}} {{DEV_H}}
{{DEV_TOP}} {{DEV_LEFT}} {{SX}} {{SY}} {{SW}} {{SH}}`, every `{{THEME.<key>}}` and every caption field as
`{{cap.<key>}}`; `render` fails if a token is left unfilled. Copy a shipped template as the starting point.

## devices

```bash
appshot devices                                   # installed packs and their colors
appshot devices list                              # every frame available
appshot devices fetch "iPad Pro (11-inch)" --colors silver
appshot devices add iphone-duo "star-white=Star White Inner Landscape.png"   # frames you downloaded
```

Frames come from fastlane/frameit-frames (Apple's marketing images); the screen cutout is measured automatically.
A pack is a folder: `device.json` (`frameSize`, `screen` [x, y, w, h], `mask`, `colors`, `default`), the
`frame-<color>.png` files and `hole-mask.png`.
