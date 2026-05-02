# Métra — Icon Asset Specification

Re-export to these exact sizes and the build pipeline picks them up directly with no resizing.

## Directory tree

Place every re-exported file at the path shown below. Folders and filenames must match exactly.

```
design/icons/
├── ios/
│   ├── light/
│   │   ├── icon-20x20.png
│   │   ├── icon-29x29.png
│   │   ├── icon-40x40.png
│   │   ├── icon-58x58.png
│   │   ├── icon-60x60.png
│   │   ├── icon-76x76.png
│   │   ├── icon-80x80.png
│   │   ├── icon-87x87.png
│   │   ├── icon-120x120.png
│   │   ├── icon-152x152.png
│   │   ├── icon-167x167.png
│   │   ├── icon-180x180.png
│   │   └── icon-1024x1024.png
│   └── dark/
│       ├── icon-20x20.png
│       ├── icon-29x29.png
│       ├── icon-40x40.png
│       ├── icon-58x58.png
│       ├── icon-60x60.png
│       ├── icon-76x76.png
│       ├── icon-80x80.png
│       ├── icon-87x87.png
│       ├── icon-120x120.png
│       ├── icon-152x152.png
│       ├── icon-167x167.png
│       ├── icon-180x180.png
│       └── icon-1024x1024.png
└── android/
    ├── light/
    │   ├── circle/
    │   │   ├── icon-48x48.png
    │   │   ├── icon-72x72.png
    │   │   ├── icon-96x96.png
    │   │   ├── icon-144x144.png
    │   │   ├── icon-192x192.png
    │   │   └── icon-512x512.png
    │   ├── squircle/
    │   │   ├── icon-48x48.png
    │   │   ├── icon-72x72.png
    │   │   ├── icon-96x96.png
    │   │   ├── icon-144x144.png
    │   │   ├── icon-192x192.png
    │   │   └── icon-512x512.png
    │   ├── foreground/
    │   │   ├── icon-108x108.png
    │   │   ├── icon-162x162.png
    │   │   ├── icon-216x216.png
    │   │   ├── icon-324x324.png
    │   │   └── icon-432x432.png
    │   └── monochrome/                  # optional — Android 13+ themed icons
    │       ├── icon-108x108.png
    │       ├── icon-162x162.png
    │       ├── icon-216x216.png
    │       ├── icon-324x324.png
    │       └── icon-432x432.png
    └── dark/                            # optional — documentation/reference only
        ├── circle/
        │   └── (same 6 sizes as light/circle/)
        ├── squircle/
        │   └── (same 6 sizes as light/squircle/)
        └── foreground/
            └── (same 5 sizes as light/foreground/)
```

## iOS — `design/icons/ios/{light,dark}/`

13 sizes, identical filenames in both `light/` and `dark/`. Brand mark can fill the icon edge-to-edge (iOS convention).

| Filename | Pixel size |
|---|---|
| `icon-20x20.png` | 20 |
| `icon-29x29.png` | 29 |
| `icon-40x40.png` | 40 |
| `icon-58x58.png` | 58 |
| `icon-60x60.png` | 60 |
| `icon-76x76.png` | 76 |
| `icon-80x80.png` | 80 |
| `icon-87x87.png` | 87 |
| `icon-120x120.png` | 120 |
| `icon-152x152.png` | 152 |
| `icon-167x167.png` | 167 |
| `icon-180x180.png` | 180 |
| `icon-1024x1024.png` | 1024 |

iOS App Store icon (`1024x1024`) **must be opaque** — no alpha channel.

## Android — `design/icons/android/light/`

Two distinct size families. Adaptive icons use a 108dp canvas, **not** 48dp.

### Legacy launcher icons (pre-API 26 fallback, also used as the round-icon resource)

`circle/` and `squircle/` — brand fills the shape, transparent outside the shape.

| Filename | Pixel size | Density |
|---|---|---|
| `icon-48x48.png` | 48 | mdpi |
| `icon-72x72.png` | 72 | hdpi |
| `icon-96x96.png` | 96 | xhdpi |
| `icon-144x144.png` | 144 | xxhdpi |
| `icon-192x192.png` | 192 | xxxhdpi |
| `icon-512x512.png` | 512 | Play Store |

### Adaptive icon foreground (API 26+, what you actually see on modern Android)

`foreground/` — full-bleed cream (no transparent corners).

| Filename | Pixel size | Density |
|---|---|---|
| `icon-108x108.png` | 108 | mdpi |
| `icon-162x162.png` | 162 | hdpi |
| `icon-216x216.png` | 216 | xhdpi |
| `icon-324x324.png` | 324 | xxhdpi |
| `icon-432x432.png` | 432 | xxxhdpi |

**Critical design spec for `foreground/`:**
- Canvas: full-bleed cream `#F4EDE2` to all four edges (no transparency anywhere).
- Brand mark (moon + dots): centered, occupying **~80% of canvas width** (~86 px in the 108 canvas, scaled proportionally for higher densities). Anything smaller produces a visible "mustard ring" around the brand on Pixel Launcher's circle mask.
- The brand should be visually centered including any optical compensation (the moon's mass might need a slight upward bias).

## Optional but recommended

- **`design/icons/android/light/monochrome/`** at the same 5 adaptive sizes (108–432) — solid white silhouette of the brand on transparent background. Unlocks Android 13+ themed-icon support (the launcher tints it with the user's wallpaper colors).
- **`design/icons/android/dark/`** — same structure as `light/`, useful for documentation but Android doesn't natively use it for app icons (themed icons are colored from `monochrome/`, not from a dark variant).
- `icon_master.png` and `icon_512.png` at the root of `design/icons/` can be dropped — neither is used by the build anymore.

## Where each file lands in the build

| Source | Destination | Used by |
|---|---|---|
| `ios/light/icon-*.png` | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Light/` | iOS (default) |
| `ios/dark/icon-*.png` | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Dark/` | iOS 18+ dark icon style |
| `android/light/squircle/icon-{48..192}.png` | `android/app/src/main/res/mipmap-{mdpi..xxxhdpi}/ic_launcher.png` | Android API <26 fallback |
| `android/light/circle/icon-{48..192}.png` | `android/app/src/main/res/mipmap-{mdpi..xxxhdpi}/ic_launcher_round.png` | Round icon resource |
| `android/light/foreground/icon-{108..432}.png` | `android/app/src/main/res/mipmap-{mdpi..xxxhdpi}/ic_launcher_foreground.png` | Adaptive icon foreground (API 26+) |
| (background color `#F4EDE2`) | `android/app/src/main/res/values/ic_launcher_background.xml` | Adaptive icon background |
