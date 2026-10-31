# Uniloop Asset Origin Tracker

Every 3D mesh, texture, and audio asset in this project is tracked here with its provenance, license/generation parameters, and status.

## Asset pipeline rules

1. **AI-generated 3D meshes**: Reference images generated via `spark-media image` (OpenAI Images API) -> meshes generated via `spark-media mesh --image <reference>` (Hunyuan3D via ComfyUI on Sparky).
2. **Review & acceptance**: Inspect mesh geometry, polycount, and UVs. Acceptable meshes are imported to `assets/models/` and tracked with Git LFS.
3. **Manual fallback**: If an AI-generated mesh is unsuitable (unusable topology, excessive artifacts, poor deformation/collision), substitute a clean Godot primitive (`BoxMesh`, `CylinderMesh`, CSG shape, or simple placeholder), open a GitHub issue labeled `art-asset` titled "Manual 3D asset: <name>", and document the target dimensions, pivot, material needs, poly budget, collision needs, and why generation failed.
4. Broken AI meshes are never shipped as complete art.
5. All binary assets (`.png`, `.jpg`, `.webp`, `.glb`, `.fbx`, `.ogg`, `.wav`, `.mp3`) are tracked via Git LFS (`.gitattributes`).

## Registry

| Asset Path | Type | Origin | Generation details / source | Status |
|---|---|---|---|---|
| `AppStore/icon.png` | 2D Icon | `ai-generated` | spark-media image (gpt-image-2.5-flare, 1024x1024 RGB) | Accepted |
| `AppStore/icon.ico` | Windows icon | `ai-generated` | Pillow resize of `AppStore/icon.png`; 16, 32, 48, 64, 128, 256 px, no new generation | Accepted; Windows native + export icon |
| `AppStore/windows/store-logo-720x1080.png` | Store logo | `derived` | `tools/gen_windows_store_art.py`; entire approved icon below a branded header with the project's Bangers font, 720x1080 RGB PNG | Windows Store listing |
| `AppStore/windows/app-tile-*.png` | App tile icons | `derived` | Same generator; Lanczos resizes of `AppStore/icon.png` to 300x300, 150x150, 72x72 RGB PNGs | Windows Store listing |
| `AppStore/windows/hero-wallpaper-1920x1080.png` | Hero wallpaper | `derived` | Same generator; minimal centered edge crop and Lanczos resize of `assets/ui/splash.jpg` to 1920x1080 RGB PNG | Windows Store listing |
| `scripts/wheel_rider.gd` | 3D Vehicle + goo spray | `primitive` | Godot TorusMesh tire, BoxMesh spokes/fork, articulated CapsuleMesh seat-head with sphere eyes and spring-compression squash; PBR materials; contact-triggered SphereMesh CPUParticles3D droplets (brown mud in Canyon Ribbon, green slime elsewhere), plus 12 opaque low-poly mud clumps in Canyon Ribbon when reduced motion is off; world-space emission, no external art | Active stylized mechanical primitive; no AI mesh needed for this simple rig |
| `scripts/canyon.gd` (gate) | 3D Prop | `primitive` | BoxMesh post/beam and Label3D number with direction arrow; crossing detected along the course path in code | Active placeholder |
| `scripts/canyon.gd` (rail) | 3D Course | `primitive` | MultiMesh CylinderMesh rail striped by track kind (blue/green, red/blue, red/yellow; neon cyan/lime and pink/violet in Neon Night), white PrismMesh chevrons, CylinderMesh/SphereMesh goo coat with varied-width drip meshes shaped into curved broad shoulders, narrow necks and rounded hanging bulbs, embedded roots and matching color/glow across each join, shader stretching and CPUParticles3D droplets (brown mud in Canyon Ribbon, green slime elsewhere), emissive BoxMesh boost pads; one-way landing is path math, ConcavePolygonShape3D kept for queries | Active placeholder |
| `scripts/course_signature.gd` | Five exclusive mechanical obstacles | `primitive` | Original code-authored Godot BoxMesh spring pad with low-segment TorusMesh springs (Sunny), CylinderMesh beam and 96-instance MultiMesh coil (Canyon), emissive BoxMesh flux gate (Neon), striped low-poly SphereMesh binding bubble (Goo), strapped BoxMesh quota crate (Monopoly). StandardMaterial3D PBR; existing iOS unshaded fallback; no textures, generated art, new lights, particles or external dependencies. Matching box/sphere/cylinder query colliders and swept wheel contacts; analytic coil attachment plus query-only strip geometry. Label3D instructions. | Playable primitive designs, not AI-mesh fallbacks; no image/mesh generation attempted or claimed |
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
| `assets/audio/sfx/checkpoint_boom.mp3` | Checkpoint SFX source | `user-provided` | Exact supplied `boom.mp3`, unchanged; source/license not independently verified | Original retained as source; gameplay uses predecoded PCM below |
| `assets/audio/sfx/checkpoint_boom.wav` | Checkpoint SFX playback | `derived` | Supplied MP3 decoded with Godot AudioStreamPlayback.mix_audio at 44.1 kHz, stereo 16-bit PCM, 0.549 s; no normalization/gain change. Tracked `.wav.import` disables default QOA compression so samples stay ready to play | Preloaded before racing; -9 dB playback follows SFX/Master volume |
| `scripts/practice.gd` (checkpoint confetti) | 3D Effect | `primitive` | One-shot CPUParticles3D BoxMesh rectangles using the existing finish-celebration palette, 96 larger particles (24 gentler with Reduced Motion), automatic cleanup and no shadows; no external art | Active; wider local checkpoint celebration |
| `assets/audio/sfx/ui_tick.wav` | UI SFX | `procedural` | Same generator; softly enveloped 1050 Hz sine tick, 0.045 s; played 12 dB below source level | Active; navigation focus feedback |
| `assets/audio/sfx/ui_confirm.wav` | UI SFX | `procedural` | Same generator; rising 660/880 Hz two-note beep, 0.120 s; played 8 dB below source level | Active; option selection feedback |
| `assets/audio/sfx/finish_crowd.mp3` | Finish ambience | `user-provided` | Exact supplied `dennish18-crowd-cheering-143103.mp3`, unchanged; source/license not independently verified | Plays once at -3 dB with a 0.6 s fade-in and final 0.5 s fade-out during the finish celebration; follows SFX/Master volume |
| `assets/audio/music/title.ogg` | Audio Music | `ai-generated` | ACE-Step 1.5 XL Turbo (Spark-2, prompt: carnival fairground instrumental, calliope/brass/tuba/banjo, 60s) | Accepted; title screen bgm |
| `assets/audio/music/race_theme.ogg` | Audio Music source | `ai-generated` | ACE-Step 1.5 XL Turbo (Spark-2): 45 s dark orchestral intro at 86 BPM crossfaded into two 120 s 172 BPM neon-punk carnival passes (seeds 2661/7311) plus a 24 s reprise, 3 s tri crossfades, 300 s total | Retained unchanged as source; gameplay uses the split sections below |
| `assets/audio/music/race_intro.ogg` | Race music section | `derived` | Source interval 0-42 s of `race_theme.ogg`, 42 s orchestral intro | Shuffled playlist; Music/Master volume, 3 s runtime crossfades |
| `assets/audio/music/race_carnival_a.ogg` | Race music section | `derived` | Source interval 45-159 s of `race_theme.ogg`, 114 s first carnival section | Same playlist |
| `assets/audio/music/race_carnival_b.ogg` | Race music section | `derived` | Source interval 162-276 s of `race_theme.ogg`, 114 s second carnival section | Same playlist |
| `assets/audio/music/race_reprise.ogg` | Race music section | `derived` | Source interval 279-300 s of `race_theme.ogg`, 21 s reprise | Same playlist |

The split sections omit the source arrangement's already-mixed transitions at 42-45, 159-162, and 276-279 seconds so a shuffled section does not carry a fragment of its old neighbor. Each section is encoded as 48 kHz stereo Ogg Vorbis at quality 5 with no normalization or added fades. To reproduce a section with FFmpeg, substitute its start and duration from the table:

```sh
ffmpeg -ss 45 -i assets/audio/music/race_theme.ogg -t 114 -map_metadata -1 -c:a libvorbis -q:a 5 assets/audio/music/race_carnival_a.ogg
```
