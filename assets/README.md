# Uniloop Asset Origin Tracker

Every 3D mesh, texture, and audio asset in this project is tracked here with its provenance, license/generation parameters, and status.

## Asset pipeline rules

1. **AI-generated 3D meshes**: Reference images generated via `spark-media image` (OpenAI Images API) -> meshes generated via `spark-media mesh --image <reference>` (Hunyuan3D via ComfyUI on Sparky).
2. **Review & acceptance**: Inspect mesh geometry, polycount, and UVs. Acceptable meshes are imported to `assets/models/` and tracked with Git LFS.
3. **Manual fallback**: If an AI-generated mesh is unsuitable (unusable topology, excessive artifacts, poor deformation/collision), substitute a clean Godot primitive (`BoxMesh`, `CylinderMesh`, CSG shape, or simple placeholder), open a GitHub issue labeled `art-asset` titled "Manual 3D asset: <name>", and document the target dimensions, pivot, material needs, poly budget, collision needs, and why generation failed.
4. Broken AI meshes are never shipped as complete art.
5. All binary assets (`.png`, `.jpg`, `.webp`, `.glb`, `.fbx`, `.ogg`, `.wav`) are tracked via Git LFS (`.gitattributes`).

## Registry

| Asset Path | Type | Origin | Generation details / source | Status |
|---|---|---|---|---|
| `AppStore/icon.png` | 2D Icon | `ai-generated` | spark-media image (gpt-image-2.5-flare, 1024x1024 RGB) | Accepted |
| `AppStore/icon.ico` | Windows icon | `ai-generated` | Pillow resize of `AppStore/icon.png`; 16, 32, 48, 64, 128, 256 px, no new generation | Accepted; Windows native + export icon |
| `scripts/wheel_rider.gd` | 3D Vehicle + goo spray | `primitive` | Godot TorusMesh tire, BoxMesh spokes/fork, articulated CapsuleMesh seat-head with sphere eyes and spring-compression squash; PBR materials; contact-triggered SphereMesh CPUParticles3D droplets (brown mud in Canyon Ribbon, green slime elsewhere), plus 12 opaque low-poly mud clumps in Canyon Ribbon when reduced motion is off; world-space emission, no external art | Active stylized mechanical primitive; no AI mesh needed for this simple rig |
| `scripts/canyon.gd` (gate) | 3D Prop | `primitive` | BoxMesh post/beam and Label3D number with direction arrow; crossing detected along the course path in code | Active placeholder |
| `scripts/canyon.gd` (rail) | 3D Course | `primitive` | MultiMesh CylinderMesh rail striped by track kind (blue/green, red/blue, red/yellow; neon cyan/lime and pink/violet in Neon Night), white PrismMesh chevrons, CylinderMesh/SphereMesh goo coat with varied-width drip meshes shaped into curved broad shoulders, narrow necks and rounded hanging bulbs, embedded roots and matching color/glow across each join, shader stretching and CPUParticles3D droplets (brown mud in Canyon Ribbon, green slime elsewhere), emissive BoxMesh boost pads; one-way landing is path math, ConcavePolygonShape3D kept for queries | Active placeholder |
| `assets/shaders/neon_*.gdshader` | Neon Night rail + backdrop | `procedural` | LED-panel rail seams and an opaque world-space nightclub backdrop with sweeping lasers and flowing ribbons; no external textures | Active level-specific shaders |
| `scripts/canyon.gd` (backdrop) | 3D Background | `procedural` | Unshaded spatial shader of geometric triangles/diamonds on a QuadMesh, tinted per track | Active placeholder |
| `assets/ui/splash.jpg` | 2D Splash | `ai-generated` | Gemini-generated title art supplied by the project owner; cover-scaled behind the title menu | Accepted |
| `assets/ui/boot_splash.png` | 2D Splash | `derived` | `splash.jpg` resized to a 1600 px PNG for `application/boot_splash` (Cover stretch) | Accepted |
| `assets/fonts/Bangers-Regular.ttf` | Font | `third-party` | Bangers by Vernon Adams, SIL Open Font License 1.1 (`assets/fonts/OFL.txt`); menu buttons, titles and countdown | Accepted |
| `scripts/menu.gd` (UniIcon, StarBar) | 2D UI | `procedural` | Unicycle colour previews and difficulty stars drawn with `_draw` | Active |
| `assets/audio/sfx/countdown_tick.wav` | SFX | `procedural` | `tools/gen_sfx.py` (stdlib-only deterministic synth, seed 2600+n, 44.1 kHz mono 16-bit, peak -3 dBFS, 0.170 s) | Active; no external audio |
| `assets/audio/sfx/countdown_go.wav` | SFX | `procedural` | Same generator; rising two-layer blip, 0.470 s | Active; no external audio |
| `assets/audio/sfx/finish.wav` | SFX | `procedural` | Same generator; three brass-style notes plus held major chord, 1.550 s | Active; no external audio |
| `assets/audio/sfx/crash.wav` | SFX | `procedural` | Same generator; falling sine thud + filtered noise burst + ringing partial, 0.620 s | Active; no external audio |
| `assets/audio/sfx/jump.wav` | SFX | `procedural` | Same generator; upward pitch sweep with vibrato tail, 0.330 s | Active; no external audio |
| `assets/audio/sfx/land_clean.wav` | SFX | `procedural` | Same generator; short low thump with soft noise click, 0.220 s | Active; no external audio |
| `assets/audio/sfx/slime_land.wav` | SFX | `procedural` | Same generator; wobbly low squidgy drop over smoothed noise, 0.430 s | Active; no external audio |
| `assets/audio/sfx/boost.wav` | SFX | `procedural` | Same generator; filtered noise sweep with rising whistle, 0.530 s | Active; no external audio |
| `assets/audio/sfx/ui_tick.wav` | UI SFX | `procedural` | Same generator; softly enveloped 1050 Hz sine tick, 0.045 s; played 12 dB below source level | Active; navigation focus feedback |
| `assets/audio/sfx/ui_confirm.wav` | UI SFX | `procedural` | Same generator; rising 660/880 Hz two-note beep, 0.120 s; played 8 dB below source level | Active; option selection feedback |
| `assets/audio/music/title.ogg` | Audio Music | `ai-generated` | ACE-Step 1.5 XL Turbo (Spark-2, prompt: carnival fairground instrumental, calliope/brass/tuba/banjo, 60s) | Accepted; title screen bgm |
| `assets/audio/music/race_loop.ogg` | Audio Music | `ai-generated` | ACE-Step 1.5 XL Turbo (Spark-2, prompt: fast repetitive arcade racing loop, four-on-floor/banjo/tuba, 28s seamless wrap crossfade) | Accepted; in-race loop bgm |
