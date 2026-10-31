# Uniloop

An offline, single-player momentum racer for **macOS and Windows**. Ride a unicycle along twisting striped rails, tackle loops and vertical launches, choose alternate routes, and land tricks to earn points and speed boosts.

## Download and play

**[Uniloop v0.2.0 — macOS and Windows](https://github.com/rwrife/uniloop/releases/tag/v0.2.0)**

| Platform | Download | Run |
| --- | --- | --- |
| macOS — Apple Silicon and Intel | [Universal Mac app](https://github.com/rwrife/uniloop/releases/download/v0.2.0/uniloop-macos-v0.2.0.zip) | Unzip and open `Uniloop.app`. |
| Windows — x86_64 | [Windows app](https://github.com/rwrife/uniloop/releases/download/v0.2.0/uniloop-windows-v0.2.0.zip) | Unzip and run `windows/uniloop.exe`. Keep its `.pck` file beside it. |

Both desktop apps support keyboard and gamepad controls. The Mac app is ad-hoc signed and has not been Developer ID signed or notarized; macOS may require approval in **System Settings → Privacy & Security** before opening it.

The v0.2.0 Windows release passed export, icon/metadata, and headless test checks in GitHub Actions. The universal Mac app passed architecture and signature checks and launched on macOS. All 52 local GUT tests passed. Physical gamepad operation has not yet been verified.

## Desktop screenshots

Captured from the actual game running on macOS with Godot 4.7.2 and the Forward+ renderer. Gameplay views use staged positions on the existing courses with the original HUD; these are game renders, not concept art. See the [capture instructions](docs/desktop-screenshots.md) to reproduce them.

![Uniloop desktop title screen with Quick Race, League, Options, and Quit](AppStore/screenshots/macos/07-title-screen.png)

| Canyon Ribbon | Neon Night |
| --- | --- |
| ![Unicycle riding a striped loop in Canyon Ribbon](AppStore/screenshots/macos/01-canyon-ribbon.png) | ![Unicycle inside a loop on the purple Neon Night course](AppStore/screenshots/macos/02-neon-night.png) |

| Sunny Sprint | Goo Gauntlet |
| --- | --- |
| ![Unicycle on a blue and green rail in Sunny Sprint](AppStore/screenshots/macos/03-sunny-sprint.png) | ![Unicycle above a dripping green goo section in Goo Gauntlet](AppStore/screenshots/macos/04-goo-gauntlet.png) |

| Choose your unicycle | Choose your track |
| --- | --- |
| ![Six unicycle colour options in the desktop selection menu](AppStore/screenshots/macos/05-choose-your-wheel.png) | ![Four tracks with length, speed, and difficulty ratings](AppStore/screenshots/macos/06-four-original-tracks.png) |

## What you can play

Choose **Quick Race**, pick one of six unicycle colours, select a track, and race after the countdown:

- **Sunny Sprint:** a short warm-up with gentle forks and a few goo pits.
- **Canyon Ribbon:** the classic zig-zag climb with loops, helix turns, launches, forks, and brown mud with matching wheel splatter and chunky mud particles. The extra clumps appear only while riding through mud and are disabled by Reduced Camera Shake. Mud keeps the same slow, forward-only handling as the green slime on other tracks.
- **Neon Night:** a faster course with boost pads and back-to-back loops, luminous cyan/lime and pink/violet LED-textured rails, neon-pink unicycle sparks, and sweeping nightclub lasers and flowing ribbons behind the track. Warm red/yellow hazard stripes stay distinct. Reduced Camera Shake freezes the background effects; High Contrast Mode dims them. The background effects use a single opaque backdrop shader without extra lights or particles, including on mobile.
- **Goo Gauntlet:** a longer, harder course with extra forks, goo, and rocket bumps.

Rails are one-way: land on them from above. Hold Up at a fork to choose the upper route. Jump over obstacles and goo, or use momentum to clear them. Flip, roll, side-flip, and tabletop in the air; clean landings earn points and a speed burst, while wipeouts cost points and stop the rider.

Finish a run to see your time, medal, points, stunt count, top speed, and wipeouts. The League screen shows local best times and medals. Options include keyboard remapping, text scaling, high contrast, reduced motion, camera shake, and audio settings.

Multiplayer is a disabled “coming soon” menu item. Android and iOS are development targets; the release above contains desktop apps only. Linux and Web builds are not available.

## Controls

| Action | Keyboard | Gamepad position (Xbox label) |
| --- | --- | --- |
| Move left / right | A / D or Left / Right | D-pad or left stick left / right |
| Backflip / upper route | W or Up | D-pad or left stick up |
| Forward roll | S or Down | D-pad or left stick down |
| Jump | Space | Bottom face button (A) |
| Brake | Shift | Left face button (X) |
| Side-flip left / right | Q / E | Left / right shoulder (LB / RB), or triggers |
| Tabletop | X | Top face button (Y) |
| Pause | Escape | Start / Menu |
| Navigate menus | Arrows or Tab | D-pad or left stick |
| Select | Enter or Space | Bottom face button (A) |
| Back | Escape | Right face button (B) |

Prompts adapt to keyboard, Xbox, PlayStation, and Nintendo input. Keyboard gameplay bindings can be changed in Options.

Options has independent **Music Volume** and **Sound Effects Volume** sliders alongside Master Volume; changes apply immediately and are saved. New saves default music to 80% and effects to 50%. Gameplay effects are mixed 6 dB quieter, including for existing saves, without changing music loudness. Menu navigation plays a soft tick and selection plays a short beep, including while paused; both follow the Sound Effects and Master settings. D-pad/left-stick navigation and A confirm work in title, Options, pause, and results menus.

Race music starts as soon as the race scene opens, before the countdown, and continues without restarting at "RACE!". The orchestral intro, two carnival sections, and reprise play in shuffled order, with every section heard before the playlist reshuffles and no back-to-back repeats. Sections overlap with a three-second crossfade, keep playing until the finish, and pause together with the race. Title music still loops separately.

Each accepted checkpoint crossing plays a short boom under the race music and launches a large multicolor confetti plume high above the gate. The boom is mixed 3 dB below other gameplay effects and follows Sound Effects and Master volume. Its uncompressed PCM audio and the confetti emitters are prepared before racing, avoiding first-use file loading, decoding, or particle setup. The burst uses 96 larger pieces with a wide upward arc, clears after 1.5 seconds, and pauses with the game; Reduced Motion uses 24 gentler pieces lasting 0.8 seconds.

Finishing a valid race stops the race music and plays the finish cue with a crowd-cheering clip fading in over 0.6 seconds to -3 dB, 3 dB above other gameplay effects, then fading to silence over its final 0.5 seconds. The cheer plays once through the celebration/results, follows Sound Effects and Master volume, pauses with the game, and stops on restart or exit.

The rider's cosmetic lean follows travel through tricks and direction changes, easing up to 20 degrees at normal top speed and progressively increasing to 35 degrees at maximum boosted speed, with a smaller airborne lean. Losing desktop focus pauses the race. Space or controller A on Resume only resumes: release and press again to jump, without reopening Pause or triggering an unintended air pump.

## Privacy and saves

The game runs offline without accounts, ads, analytics, telemetry, or live leaderboards. Records and settings are stored locally in Godot's `user://` directory. No location, microphone, or camera permission is required.

## Build from source

Install **Godot 4.7.2-stable** and its matching export templates from the [official release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable). Install [Git LFS](https://git-lfs.com/) before cloning, then fetch the art assets:

```sh
git clone https://github.com/rwrife/uniloop.git
cd uniloop
git lfs pull
godot --headless --path . --import --quit
godot --path .
```

Run the test suite:

```sh
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

### macOS

On a Mac with the matching macOS template installed:

```sh
GODOT_BIN=/path/to/Godot.app/Contents/MacOS/Godot tools/build_macos.sh
open build/macos/Uniloop.app
```

This produces a universal Apple Silicon/Intel app and `build/macos/uniloop-macos.zip`, with architecture and signature verification. The [macOS workflow](.github/workflows/macos.yml) runs tests and uploads the zip on pull requests, pushes to main, and manual dispatch.

### Windows

With the matching Windows export template installed:

```sh
mkdir -p build/windows
godot --headless --path . --export-release "Windows Desktop" build/windows/uniloop.exe
```

The [release workflow](.github/workflows/release.yml) builds and publishes the Windows zip on `v*` tags or manual dispatch. For manual dispatch, use `main` and supply a `release_tag`, such as `v0.2.0`. The macOS workflow uploads a build artifact; attaching the Mac zip to a release is a separate step.

### Windows Store MSIX submission artifact

Use the [Windows Store MSIX workflow](.github/workflows/windows-store-msix.yml) for manual Store-submission builds. It exports `build/windows` and packages an unsigned `.msix` artifact using your explicit Partner Center identity metadata.

Required dispatch inputs:

- `package_version` in `major.minor.build.revision` format (numeric, each segment 0-65535)
- `store_identity_name` = Partner Center `Package/Identity/Name` (override; otherwise repository variable default)
- `store_publisher` = Partner Center `Package/Identity/Publisher` (override; otherwise repository variable default)
- `publisher_display_name` = Partner Center `Package/Properties/PublisherDisplayName` (override; otherwise repository variable default)

Recommended repository Actions variable defaults: `WINDOWS_STORE_IDENTITY_NAME`, `WINDOWS_STORE_PUBLISHER`, `WINDOWS_STORE_PUBLISHER_DISPLAY_NAME`, and optional `WINDOWS_STORE_PACKAGE_DISPLAY_NAME`. The workflow accepts the same names as repository secrets for compatibility, with precedence input → variable → secret. `PFN`, `SID`, and Store ID are not substitutes for these manifest identity fields.

Signing note: for Microsoft Store distribution, you do not need to buy or inject a signing certificate in this workflow. The Store signs submitted packages during certification/distribution. The generated MSIX is an unsigned submission artifact and is not intended as a directly installable local test package. See [docs/windows-store-msix.md](docs/windows-store-msix.md) for full setup/run/download steps.

### iOS development

With Xcode, the pinned Godot editor, and its matching iOS template installed:

```sh
GODOT_BIN=/path/to/Godot.app/Contents/MacOS/Godot tools/build_ios.sh
```

This exports `build/ios/uniloop.xcodeproj` and builds unsigned device and simulator apps. The script repairs the pinned template's missing arm64 simulator library using matching Godot source; its first run requires Python, network access, and an engine compilation. Open the project in Xcode to run on a simulator. Device installation and distribution require signing. Automatic signing uses `Apple Development`; Xcode handles distribution signing when archiving and distributing through App Store Connect.

The iOS simulator uses a simplified Compatibility rendering path; physical devices use the Mobile renderer. Touch controls clear on cancellation, pause, and backgrounding and respect the display safe area. No mobile installer is attached to v0.2.0.

## Development notes

Godot/GDScript with a custom adaptive Control UI. Desktop rendering uses Forward+; rail instances are grouped into spatial batches so offscreen sections can be culled independently.

For a repeatable local benchmark, launch with `UNILOOP_BENCHMARK=1`. It drives Canyon Ribbon for 15 seconds after warmup and writes `user://performance_probe.json` with FPS, frame-time percentiles, and render counts. It uses a separate save file and is disabled normally.

- [Toolchain and platform configuration](docs/toolchain.json)
- [Roadmap and original project plan](PLAN.md)
- [Asset origins](assets/README.md)
- [License](LICENSE)
