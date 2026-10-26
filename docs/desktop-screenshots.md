# Desktop screenshot captures

The seven screenshots embedded in the README are actual macOS game renders at
2560 × 1600, captured with Godot 4.7.2-stable using Forward+. Gameplay captures
stage the rider at selected positions on the existing courses and preserve
the game's HUD. They do not show a timed run in progress.

## Reproduce the captures

Use the pinned Godot editor on macOS with a graphical desktop session:

```sh
godot --path . --import --quit
godot --path . --resolution 2560x1600 --position 0,0 --script res://tools/capture_macos_appstore.gd
```

The capture script writes RGB PNG files to `AppStore/screenshots/macos/`:

| File | View |
| --- | --- |
| `01-canyon-ribbon.png` | Canyon Ribbon loop |
| `02-neon-night.png` | Neon Night loop |
| `03-sunny-sprint.png` | Sunny Sprint rail |
| `04-goo-gauntlet.png` | Goo Gauntlet goo section |
| `05-choose-your-wheel.png` | Six unicycle colours |
| `06-four-original-tracks.png` | Track selection |
| `07-title-screen.png` | Desktop title menu |

The script uses a separate gameplay save file,
`user://macos_appstore_capture.json`. Inspect the resulting images before
committing them. Git LFS tracks PNG assets; install it before adding or pulling
screenshots. Keep the filenames stable so README image links remain valid.

These captures document the desktop UI and keyboard prompts. They do not
verify physical gamepad operation or represent Windows-specific screenshots.
