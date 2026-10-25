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
| `scripts/wheel_rider.gd` | 3D Vehicle | `primitive` | Godot TorusMesh tire, BoxMesh spokes/fork, CapsuleMesh seat with PBR materials | Active placeholder; mesh pipeline pending #4 |
| `scripts/canyon.gd` (gate) | 3D Prop | `primitive` | BoxMesh post/beam and Label3D number with direction arrow; crossing detected along the course path in code | Active placeholder |
| `scripts/canyon.gd` (rail) | 3D Course | `primitive` | MultiMesh CylinderMesh rail striped by track kind (blue/green, red/blue, yellow/orange, red/yellow), white PrismMesh chevrons, green SphereMesh goo, emissive BoxMesh boost pads; one-way landing is path math, ConcavePolygonShape3D kept for queries | Active placeholder |
| `scripts/canyon.gd` (backdrop) | 3D Background | `procedural` | Unshaded spatial shader of geometric triangles/diamonds on a QuadMesh | Active placeholder |
