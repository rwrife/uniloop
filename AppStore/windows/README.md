# Windows Store listing art

| File | Dimensions | Purpose |
| --- | --- | --- |
| `store-logo-720x1080.png` | 720 x 1080 | Portrait Store logo |
| `app-tile-300x300.png` | 300 x 300 | App tile icon |
| `app-tile-150x150.png` | 150 x 150 | App tile icon |
| `app-tile-72x72.png` | 72 x 72 | App tile icon |
| `hero-wallpaper-1920x1080.png` | 1920 x 1080 | Hero wallpaper |

All files are opaque RGB PNGs derived from the existing approved artwork.
The portrait logo preserves the entire square icon beneath a branded header
using the project's Bangers font. The hero wallpaper uses the title-screen
artwork with a minimal centered edge crop, without stretching.

These are Partner Center listing assets, not replacements for the separately
generated MSIX package logos.

Listing copy is in `AppStore/short-description.txt` (under 100 characters) and
`AppStore/description.txt` (the longer app description). Both describe currently
available desktop features, not planned mobile or multiplayer features.

To regenerate, fetch the source artwork with Git LFS, install Pillow in your
Python environment (`python -m pip install Pillow`), and run:

```sh
python tools/gen_windows_store_art.py
```
