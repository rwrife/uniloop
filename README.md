# Uniloop

Offline 3D momentum-racing game for players who like mastering a single-wheel machine: carve original sculpted courses, chain safe landings, and beat local time-trial records on Windows, tablets, and phones.

**Status:** playable Canyon Ribbon practice course, custom adaptive UI, local save/settings, GUT tests, Windows CI export and a universal macOS build. More courses, generated 3D mesh, mobile exports, and public release pending real verification.

## Why and for whom

Arcade racers often gate progress behind accounts, currency, or ads. Uniloop is a self-contained skill game for solo racers. It is a high-speed 2.5D side-scroller in the spirit of Uni Racers: a 3D-rendered unicycle races along a striped rail viewed side-on. Courses zig-zag upward through 360° loops, helix U-turns and vertical launches that shoot up through the underside of the rail above (rails are one-way: you only land on them from above). Rail colors signal what is coming: blue/green normal, red/blue direction changes, red/yellow jumps, kickers, pitfalls and goo. The rail forks into long, unmarked alternate routes (hold Up at a junction to take the upper rail, or stay low), and dripping goo pits are forward-only crawls unless you clear them at full speed. Riders hop, brake, and in the air flip, roll, twist, z-flip and tabletop; clean landings award points and a speed burst, wipeouts stop the rider and cost points, and falling drops you onto the rail below. Rare unmarked rocket bumps at the end of a straight fire you skyward unless you hop them. From the title menu (Quick Race, Multiplayer - coming soon, League, Options, Quit on desktop) you pick one of six unicycle colours and one of four tracks (Sunny Sprint, Canyon Ribbon, Neon Night, Goo Gauntlet) of varying length, speed and difficulty, then a 3-2-1-RACE! countdown starts the clock. A run lasts roughly 1.5–5 minutes and ends with a roll-out and stats screen (time, medal, score, stunts, top speed, wipeouts); the League screen lists your best time and medal per track. Unlock a harder course by finishing earlier ones; replay with split times, local records and repeatable ghost inputs. No licensed brands, copyrighted tracks, or imported characters.

## Intended workflow and MVP

1. Choose one of three original courses on phone, tablet, or desktop; learn controls via a replayable practice lap.
2. Ride with deterministic InputMap actions (keyboard, gamepad, and touch overlays), landing on wheels rather than simply avoiding traffic.
3. Finish before a generous par time; save local best time and clean-landing streak, then retry for medals.
4. Unlock courses and optional stunt line challenges; adjust audio, camera shake, contrast, motion, and input bindings.
5. Export a versioned JSON record and import it after validating schema/version and offering a backup of current records.

Game content targets sculpted terrain, authored jumps and banked corners, route-specific sound and visual identity, medals/meta progression, pause/settings, particles, transitions, local saves and accessibility. No multiplayer, accounts, ads, live leaderboards, real-money upgrades, traffic simulation, licensed art, or gyro-only controls.

## Platform and graphics

Godot **4.7.2-stable**, GDScript; Windows Desktop primary CI/release. Android and iOS phone/tablet builds committed milestones; macOS builds target Apple Silicon and Intel; Linux/Web remain planned. Desktop uses Forward+ with PBR `StandardMaterial3D`, baked LightmapGI or SDFGI where worthwhile, glow, SSAO and GPUParticles3D. Mobile uses Mobile renderer and scaled effects/geometry. Web uses Compatibility renderer if later supported. Asset process: `spark-media image` (OpenAI Images API) for reference, then `spark-media mesh --image` (Hunyuan3D/ComfyUI on Sparky), inspect topology, decimate/UV/PBR/collide/LOD and track accepted binaries with Git LFS in `assets/models/`. If generated topology is unusable, use a clean primitive and open an `art-asset` manual-model issue with failure details; never ship broken meshes as complete art. `assets/README.md` records origins.

Custom Godot Control design system (strategy B), not Material or Cupertino: safe areas, platform back/quit/pause, touch targets and input prompts adapted to touch/keyboard/gamepad, high contrast, scalable labels, remapping and reduced shake. Windows supports keyboard/mouse and gamepad. Phone and tablet support touch and optional gamepad, with no mandatory motion sensor. Scope iOS icons/IDs to iPhone **and iPad**; Android tablets enabled.

## Privacy and data

Local `user://` versioned save (course medals, settings, records, optional ghost inputs); explicit user-owned JSON export/import. No analytics, network, account, location, microphone, or camera permission. No cloud backup by default. Game should remain playable without connectivity. Identifier: `com.infinityball.uniloop` for iOS bundle ID, Android `application/unique_name`, and Windows identity when applicable. App Store Connect bundle ID: CREATED `com.infinityball.uniloop`. ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID are repository secret **names**, not committed credentials.

## Build and milestones

Install exact editor and export templates from official [Godot 4.7.2-stable release](https://godotengine.org/download/archive/4.7.2-stable/). `godot --headless --path . --import --quit` validates project loading; see PLAN.md for CI/tests and `docs/toolchain.json` for pin. Install Git LFS before clone/pull. Remaining generated assets, extended gameplay, and mobile exports are tracked in GitHub issues. `AppStore/icon.png` is genuine OpenAI-generated art. `AppStore/icon.ico` is its Windows size-optimized derivative, wired into Windows native/executable icon; Android and iOS preset slots point at original PNG. `AppStore/description.txt` describes shipped versus planned features. A zipped Windows release exists at `v0.1.0`; no APK or IPA is available.

Release pipeline: `.github/workflows/release.yml` on `v*` tags/manual dispatch builds a zipped Windows Desktop export on `windows-latest` and publishes it as GitHub release asset. Manual dispatch must run from `main` with `release_tag` (e.g. `v0.1.0`). First verified run: release `v0.1.0` from main commit `ecc861c`, run 40233624693, asset `uniloop-windows-v0.1.0.zip`. Android export and iOS macOS runner compile are separate gates; TestFlight/Play submission later and opt-in.

### iOS verification

With Xcode, Godot 4.7.2 and its matching export templates installed, run
`GODOT_BIN=/path/to/Godot.app/Contents/MacOS/Godot tools/build_ios.sh`.
This exports `build/ios/uniloop.xcodeproj` and builds unsigned device and
simulator apps. The script repairs the pinned template's missing arm64
simulator library using matching Godot source; its first run requires Python,
network access and a short engine compilation. Open the generated project in
Xcode to run on a simulator. Physical-device installation requires signing.
Both build configurations use automatic signing with `Apple Development`.
Archive in Xcode, then choose Distribute App → App Store Connect; Xcode handles
distribution signing at that stage. Do not force `Apple Distribution` in the
Release build settings while automatic signing is enabled.

The iOS Compatibility path uses simpler materials, disables sun shadows and
uses a 1x framebuffer without glow for the simulator's software OpenGL driver.
Physical devices use the Mobile renderer. Touch inputs clear on cancellation,
pause and backgrounding, and controls respect the scaled display safe area.

Course render instances are grouped into 24-unit spatial batches, so offscreen
rail sections can be culled independently. The Canyon Ribbon starting view
submits approximately 2,248 rail triangles instead of the course-wide 595,548.
For a repeatable local race benchmark, launch with the environment variable
`UNILOOP_BENCHMARK=1`. It drives Canyon Ribbon for 15 seconds after warmup and
writes `user://performance_probe.json` with FPS, frame-time percentiles and
render counts. It uses a separate benchmark save file and is disabled normally.

### macOS build and controls

With the pinned Godot editor and matching macOS export template installed, run:

```sh
GODOT_BIN=/path/to/Godot.app/Contents/MacOS/Godot tools/build_macos.sh
open build/macos/Uniloop.app
```

The script produces a universal (Apple Silicon + Intel) app and
`build/macos/uniloop-macos.zip`. The macOS workflow runs tests and uploads the
zip on pull requests, pushes to main, and manual dispatch. Builds are ad-hoc
signed for local use; public distribution still requires Developer ID signing
and notarization.

Use arrows or WASD to steer and flip, Space to jump, Shift to brake, Q/E for
side flips, X for tabletop, and Escape to pause. Navigate menus with arrows or
Tab and Enter/Space. A connected gamepad uses the D-pad or left stick, bottom
face button to jump/confirm, left face button to brake, shoulder buttons for
side flips, top face button for tabletop, and Start/Menu to pause. The right
face button goes back in menus. Prompts adapt to the last input device.
