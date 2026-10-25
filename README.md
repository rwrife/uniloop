# Uniloop

Offline 3D momentum-racing game for players who like mastering a single-wheel machine: carve original sculpted courses, chain safe landings, and beat local time-trial records on Windows, tablets, and phones.

**Status:** playable Canyon Ribbon practice course, custom adaptive UI, local save/settings, GUT tests, Windows CI export. More courses, generated 3D mesh, mobile exports, and public release pending real verification.

## Why and for whom

Arcade racers often gate progress behind accounts, currency, or ads. Uniloop is a self-contained skill game for solo racers. A run starts at a course gate, lets the player accelerate/brake, lean and jump through banked turns, then judges completion time and trick/landing quality. Unlock a harder course by finishing earlier ones; replay with split times, local records and repeatable ghost inputs. No licensed brands, copyrighted tracks, or imported characters.

## Intended workflow and MVP

1. Choose one of three original courses on phone, tablet, or desktop; learn controls via a replayable practice lap.
2. Ride with deterministic InputMap actions (keyboard, gamepad, and touch overlays), landing on wheels rather than simply avoiding traffic.
3. Finish before a generous par time; save local best time and clean-landing streak, then retry for medals.
4. Unlock courses and optional stunt line challenges; adjust audio, camera shake, contrast, motion, and input bindings.
5. Export a versioned JSON record and import it after validating schema/version and offering a backup of current records.

Game content targets sculpted terrain, authored jumps and banked corners, route-specific sound and visual identity, medals/meta progression, pause/settings, particles, transitions, local saves and accessibility. No multiplayer, accounts, ads, live leaderboards, real-money upgrades, traffic simulation, licensed art, or gyro-only controls.

## Platform and graphics

Godot **4.7.2-stable**, GDScript; Windows Desktop primary CI/release. Android and iOS phone/tablet builds committed milestones; Linux/macOS/Web planned only after real export evidence. Desktop uses Forward+ with PBR `StandardMaterial3D`, baked LightmapGI or SDFGI where worthwhile, glow, SSAO and GPUParticles3D. Mobile uses Mobile renderer and scaled effects/geometry. Web uses Compatibility renderer if later supported. Asset process: `spark-media image` (OpenAI Images API) for reference, then `spark-media mesh --image` (Hunyuan3D/ComfyUI on Sparky), inspect topology, decimate/UV/PBR/collide/LOD and track accepted binaries with Git LFS in `assets/models/`. If generated topology is unusable, use a clean primitive and open an `art-asset` manual-model issue with failure details; never ship broken meshes as complete art. `assets/README.md` records origins.

Custom Godot Control design system (strategy B), not Material or Cupertino: safe areas, platform back/quit/pause, touch targets and input prompts adapted to touch/keyboard/gamepad, high contrast, scalable labels, remapping and reduced shake. Windows supports keyboard/mouse and gamepad. Phone and tablet support touch and optional gamepad, with no mandatory motion sensor. Scope iOS icons/IDs to iPhone **and iPad**; Android tablets enabled.

## Privacy and data

Local `user://` versioned save (course medals, settings, records, optional ghost inputs); explicit user-owned JSON export/import. No analytics, network, account, location, microphone, or camera permission. No cloud backup by default. Game should remain playable without connectivity. Identifier: `com.infinityball.uniloop` for iOS bundle ID, Android `application/unique_name`, and Windows identity when applicable. App Store Connect bundle ID: CREATED `com.infinityball.uniloop`. ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID are repository secret **names**, not committed credentials.

## Build and milestones

Install exact editor and export templates from official [Godot 4.7.2-stable release](https://godotengine.org/download/archive/4.7.2-stable/). `godot --headless --path . --import --quit` validates project loading; see PLAN.md for CI/tests and `docs/toolchain.json` for pin. Install Git LFS before clone/pull. Remaining generated assets, extended gameplay, and mobile exports are tracked in GitHub issues. `AppStore/icon.png` is genuine OpenAI-generated art. `AppStore/icon.ico` is its Windows size-optimized derivative, wired into Windows native/executable icon; Android and iOS preset slots point at original PNG. `AppStore/description.txt` describes shipped versus planned features. No claim that a Windows release zip, APK, IPA, or store submission is available until linked CI/release evidence exists.

Release milestone: `.github/workflows/release.yml` on `v*` tags/manual dispatch builds a zipped Windows Desktop export on `windows-latest` and publishes it as GitHub release asset. Android export and iOS macOS runner compile are separate gates; TestFlight/Play submission later and opt-in.
