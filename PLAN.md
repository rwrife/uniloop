# Uniloop implementation plan

## Scope and architecture

Build original 3D single-wheel momentum-racing game in Godot 4.7.2-stable (GDScript). Vehicle motion is ground-contact-driven: lean controls torque; speed and jump arc affect landing stability; authored checkpoints and forgiving resets keep courses learnable. Avoid imitation of any existing game's names, levels, artwork, soundtrack or exact handling. Pure gameplay state for checkpoint order, time, trick/landing score and medals stays separate from scene rendering, input adaptation and persistent records. Deterministic fixtures and GUT/gdUnit4 tests should gate domain logic.

One `project.godot` with `export_presets.cfg` checked in; addon/test harness arrives with first issue. `docs/toolchain.json` pins 4.7.2-stable. Git LFS tracks binary art and audio. No network service. App identifier `com.infinityball.uniloop` for iOS bundle ID, Android `application/unique_name`, Windows/MSIX identity if used. ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8, ASC_TEAM_ID secret names reserved for later opt-in iOS publishing. App Store Connect bundle ID CREATED.

## Product milestones, in dependency order

1. Godot project boot, input actions, export presets, exact pinned editor; CI Windows headless import and Windows Desktop export; Linux/Docker headless checks; Android export gate when feasible. Check clean `.godot/` exclusion.
2. Pure GDScript race rules, checkpoints/medals/landing calculations, repeatable tests and save schema.
3. Playable practice and first sculpted course with predictable single-wheel controls, touch and keyboard/gamepad, camera and checkpoint resets.
4. Generated art route end to end: OpenAI Images reference (`spark-media image`) -> Hunyuan3D mesh (`spark-media mesh --image`) -> visual/topology review -> Git LFS `assets/models/` -> PBR `StandardMaterial3D`, collision and LOD. Track origin in `assets/README.md`. For failed AI topology, substitute clean Godot primitives and create open `art-asset` issue specifying reference, scale/pivot, materials/LOD, tri budget, collision/animation requirements and exact failure; never ship broken mesh.
5. Two more distinct courses, optional stunt routes, medal unlocks, time-trial ghost, saved progression, audio, GPUParticles3D, camera polish and transition polish.
6. Strategy **B: fully custom branded Godot Control UI**. Responsive menus and touch overlay for phone/tablet, keyboard/mouse/gamepad prompts for Windows. Mobile safe areas, back/pause semantics, text scaling, high contrast, reduced shake, remap/settings. No platform-themed Material-on-iOS or Cupertino-on-Android crossovers. Validate key views on each target.
7. Validated export/import for versioned local records, overwrite preview/backup and no-network privacy audit; update `AppStore/description.txt` and wire genuine `AppStore/icon.png` to project and all target export icons.
8. `.github/workflows/release.yml` triggered by `v*` tag or manual dispatch: pinned editor/templates, headless tests, Windows Desktop export on `windows-latest`, zip and GitHub release attachment. iOS compile/export on macOS later; store submissions explicitly later/opt-in. No claims before actual CI runs.

## Renderer/export matrix

| Target | Renderer | Commitment / verification state |
|---|---|---|
| Windows | Forward+ | Primary CI/release, planned; no build yet |
| Android phone + tablet | Mobile | Committed build gate, planned; no build yet |
| iOS iPhone + iPad | Mobile | Committed macOS export milestone, planned; no build yet |
| Linux/macOS | Forward+ / Mobile fallback | Future exports, untested |
| Web | Compatibility | Future feasibility check, untested |

Desktop modern-3D target: PBR, dynamic lights + LightmapGI/SDFGI where measured, glow, SSAO, reflections where affordable, particles, tonemapping. Mobile scales geometry/light/particle budgets down. No ray-tracing promise. Course quality measured with screenshots and frame-time captures on real devices, not declarations.

## Tests and risks

GUT or gdUnit4 for deterministic rules, save migration, import rejection, unlock logic, checkpoint order; headless `--import --quit` project-load check and Windows export under pinned editor. Input and UI walkthrough on Windows with keyboard/gamepad and Android/iOS touch, tablet layouts/safe areas. Windows CI uses `windows-latest`; Linux tooling runs in Docker when needed. Disclose Apple runner, signing, Android SDK and physical-device gaps. Risks: realistic-feeling one-wheel handling, mesh topology, art generation availability, mobile performance, LFS limits; fail explicitly and keep related issues open when blocked. Avoid copying another game's track layouts or visual IP.

Non-goals: multiplayer, purchases, live leaderboard, camera/mic/location permissions, online auth, motion-only input, clinical/wellness claims, licensed vehicles, and fake build/art evidence.
