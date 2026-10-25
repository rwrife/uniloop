# Uniloop

Offline 3D momentum-racing game for players who like mastering a single-wheel machine: carve original sculpted courses, chain safe landings, and beat local time-trial records on Windows, tablets, and phones.

**Status:** planning scaffold. No playable scene, generated mesh, physics model, exports, CI result, or release exists yet. `project.godot` and export-preset definitions are included; they do not prove build success.

## Why and for whom

Arcade racers often gate progress behind accounts, currency, or ads. Uniloop is a self-contained skill game for solo racers. It is a high-speed 2.5D side-scroller in the spirit of Uni Racers: a 3D-rendered unicycle races along a striped rail viewed side-on. Courses zig-zag upward through 360° loops, helix U-turns and vertical launches that shoot up through the underside of the rail above (rails are one-way: you only land on them from above). Rail colors signal what is coming: blue/green normal, red/blue direction changes, red/yellow jumps, kickers, pitfalls and goo. The rail forks into long, unmarked alternate routes (hop onto the rail above or clear a kicker - or stay low), and dripping goo pits are forward-only crawls unless you clear them at full speed. Riders hop, brake, and in the air flip, roll, twist, z-flip and tabletop; clean landings award points and a speed burst, wipeouts stop the rider and cost points, and falling drops you onto the rail below. Rare unmarked rocket bumps at the end of a straight fire you skyward unless you hop them. From the title menu (Quick Race, Multiplayer - coming soon, League, Options, Quit on desktop) you pick one of six unicycle colours and one of four tracks (Sunny Sprint, Canyon Ribbon, Neon Night, Goo Gauntlet) of varying length, speed and difficulty, then a 3-2-1-RACE! countdown starts the clock. A run lasts roughly 1.5–5 minutes and ends with a roll-out and stats screen (time, medal, score, stunts, top speed, wipeouts); the League screen lists your best time and medal per track. Unlock a harder course by finishing earlier ones; replay with split times, local records and repeatable ghost inputs. No licensed brands, copyrighted tracks, or imported characters.

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

Install exact editor and export templates from official [Godot 4.7.2-stable release](https://godotengine.org/download/archive/4.7.2-stable/). `godot --headless --path . --import --quit` validates project loading; see PLAN.md for CI/tests and `docs/toolchain.json` for pin. Install Git LFS before clone/pull. Initial skeleton, gameplay, responsive UI, generated assets, persistence and Windows release are tracked in GitHub issues. App icon `AppStore/icon.png` is real OpenAI-generated art; icon wiring for export presets is issue #7. `AppStore/description.txt` is honest pre-release copy. No claim that a Windows zip, APK, IPA, or store submission is available yet.

Release milestone: `.github/workflows/release.yml` on `v*` tags/manual dispatch builds a zipped Windows Desktop export on `windows-latest` and publishes it as GitHub release asset. Android export and iOS macOS runner compile are separate gates; TestFlight/Play submission later and opt-in.
