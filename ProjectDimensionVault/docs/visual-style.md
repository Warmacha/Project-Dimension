# Visual Style Guide — Retro-3D / PS1-SNES Aesthetic

## Overview

Project Dimension targets a first-person perspective rendered in the style of mid-90s 3D accelerator games and SNES Mode-7 3D — think early PlayStation, SNES Starfox, or Windows 95 era screensavers. The look is deliberately uncanny: bold flat geometry, heavy scanlines, vertex wobble, and dithered colors. This complements the dreamlike, EarthBound/Yume Nikki tone of the game.

**Reference images are in `../StyleReference/`.** See annotations below.

---

## Style Reference Annotations

| File | What to Extract |
|---|---|
| `maxresdefault.jpg` | The primary target. Heavy horizontal CRT scanlines across the entire screen (including sky). Bold flat-shaded red geometry with zero smoothing. Neon green ground with visible dithering/pixelation. Blue scan-interlaced sky with no texture. |
| `snes.webp` | SNES-era 3D. Severe color banding — ground is just 2–3 greens dithered together. Gold/yellow columns fully unlit. Green checkered sphere with no shading. Scanlines even stronger here. No anti-aliasing anywhere. |
| `FpLzeO5WAAAXIYC.jpg` | Mid-90s CGI pre-render quality. Geometric primitives with simple environment/reflection maps on a flat reflective water plane. Pastel gradient sky. No hard shadows. Shows the "shiny" variant of the look. |
| `images.jpg` | Dark studio background, high-contrast. Two-tone checkered floor (classic retro pattern). Shiny primitives with tight specular but no realism. Good reference for interior/void-style environments (Prison World, etc.). |

---

## Core Visual Elements

### A. Low Resolution / Pixelation
**The single highest-impact effect.** Everything else stacks on top of this.

Render the scene to a small RenderTexture, then upscale using nearest-neighbor (point) filtering so pixels stay hard and chunky.

- Target resolution: `320×240` for maximum retro feel, `480×270` for a slightly cleaner look
- Filter mode on the output: `FilterMode.Point` — never bilinear
- MSAA: **Off** — anti-aliasing defeats the whole effect

### B. Scanlines
Horizontal dark bands every other pixel row, blended at 30–50% multiply. Applied as a full-screen overlay *after* pixelation so the lines align to final screen pixels, not the low-res buffer.

- Every other screen-space row: `frac(screenUV.y * _ScreenParams.y) < 0.5`
- Blend: multiply or darken, opacity ~0.35
- Optional: add very subtle vertical shimmer noise (1–2% per frame) for CRT interlace feel

### C. Vertex Snapping (PS1 Wobble)
Snap world-space vertex positions to a coarse grid in the vertex shader before transforming to clip space. When the camera moves, vertices subtly "pop" between grid positions, creating the signature PS1 swimming/wobble on surfaces.

```hlsl
float precision = 64.0; // lower = more wobble
float4 snappedWorld = round(worldPos * precision) / precision;
```

Expose `precision` as a per-material float. Use ~64–128 for subtle wobble; ~16–32 for aggressive PS1 look.

### D. Flat Shading
No smooth normals. Every triangle face has a single uniform color under lighting — hard edges everywhere, no gradient across a polygon.

Two approaches:
- **Mesh-level (preferred):** Import meshes with 0° smoothing angle so every face has its own split normals. This works with any shader.
- **Shader-level:** In the fragment stage, reconstruct face normal via `normalize(cross(ddx(worldPos), ddy(worldPos)))` and use that instead of the interpolated vertex normal.

### E. Color Banding / Ordered Dithering
Quantize the final fragment color to a small number of steps per channel, and use a 4×4 Bayer matrix dither pattern to break up gradients with a structured pixel pattern instead of banding hard.

```hlsl
// 4x4 Bayer matrix threshold
float bayer[16] = { 0,8,2,10, 12,4,14,6, 3,11,1,9, 15,7,13,5 };
float threshold = bayer[(px.x % 4) + (px.y % 4) * 4] / 16.0;
color = floor(color * colorSteps + threshold) / colorSteps;
```

- `colorSteps`: 4–8 steps per channel. 4 gives strong banding; 8 is softer.
- Apply in the same post pass as scanlines.

### F. Affine Texture Mapping
PS1 didn't do perspective-correct UV interpolation — textures "swim" as the camera moves. Simulate this by passing UVs through the vertex shader without perspective correction.

```hlsl
// Vertex
o.uvAffine = IN.uv;
o.clipW = clipPos.w;

// Fragment — use uvAffine directly (no divide by w)
float2 uv = i.uvAffine; // affine (swimming) look
// vs.
float2 uv = i.uvAffine / i.clipW; // perspective-correct (normal look)
```

Expose a `_AffineBlend` float (0 = correct, 1 = full affine) to blend between them per material.

### G. Lighting — Lambert / Cel, No PBR
- Use URP **Simple Lit** or a custom shader — not Lit/BRDF
- Lighting model: Lambert diffuse (`NdotL`) only, no specular unless doing the shiny variant (FpLzeO5 reference)
- Cel ramp: 2 steps only — lit and shadow, no midtone gradients
- One strong directional light. No ambient occlusion. No real-time shadows, or use simple blob shadows
- Colors: fully saturated primaries and secondaries. Use a restricted palette per world

### H. Fog
Linear fog at a short distance to hide draw distance with a solid color wall — not a soft gradient.

- URP: `Window → Rendering → Lighting → Environment → Fog`
- Mode: **Linear** (or Exponential Squared for a slightly softer cut)
- Color: world-specific (see worlds.md). Platform World = bright sky blue; Prison = near-black; void worlds = black

### I. Sky
Solid color or simple two-band gradient. No HDR, no procedural clouds, no skybox texture with detail.

- Use a custom `Skybox/Gradient` material or just set a solid background color
- The scanline pass applies over the sky too — so the sky gets scanlines for free

---

## Unity URP Implementation

### Key Assets

| Asset | Role |
|---|---|
| `Assets/Settings/PC_Renderer.asset` | Add all Renderer Features here |
| `Assets/Settings/Mobile_Renderer.asset` | Same features; use a lower-res RT for mobile |
| `Assets/Settings/DefaultVolumeProfile.asset` | Volume-driven overrides for per-scene tuning |
| `Assets/Settings/PC_RPAsset.asset` | Global URP settings — disable MSAA, HDR here |

### Implementation Steps (in priority order)

#### 1. Pixelation Renderer Feature
Create a `ScriptableRendererFeature` + `ScriptableRenderPass` that:
1. Allocates a `RenderTexture` at target low resolution (e.g. 320×240) with `FilterMode.Point`
2. Blits the camera color target into it
3. Blits it back to the camera target at full screen size (point filter = hard pixels)

Add to both `PC_Renderer.asset` and `Mobile_Renderer.asset`.

> URP 17 ships with `FullScreenPassRendererFeature` — use it with a custom blit material if writing a full custom feature feels like overkill. Set the material's texture sampler to `Point`.

#### 2. Full-Screen Post Pass (Scanlines + Dither + Quantize)
One `FullScreenPassRendererFeature` using a single unlit shader/material. Handles:
- Scanline bands (screen UV modulo)
- Bayer dithering
- Color step quantization

Expose these as shader properties so you can tune per-scene via a Volume custom component:
- `_ScanlineOpacity` (0–1)
- `_ColorSteps` (2–16)
- `_DitherStrength` (0–1)

Run this pass **after** pixelation so it operates on final screen pixels.

#### 3. Vertex Snapping Shader
Create a custom URP Unlit or SimpleLit ShaderGraph (or HLSL `.shader`):
- In the vertex stage, snap world position to grid, then transform to clip
- Expose `_SnapPrecision` float
- Use this as the base material for all world geometry

#### 4. Flat Shading
- Option A: Import all meshes with 0° smoothing. Works with any shader.
- Option B: Add the DDX/DDY face-normal reconstruction to the vertex snapping shader above.

Option A is simpler and more robust — do that first.

#### 5. Fog Per World
Set scene-level fog in each scene's Lighting settings. Use a Volume override if you need to blend fog color during transitions.

#### 6. Affine UV (Optional Polish)
Add affine UV toggle to the vertex snapping shader material. Use `_AffineBlend = 1.0` on large flat surfaces (floors, walls) where the swimming effect is most visible and most authentic.

---

## What to Turn Off

| Feature | Why |
|---|---|
| MSAA | Anti-aliasing destroys the chunky pixel look |
| HDR Rendering | Keeps colors in [0,1] — banding and dithering work correctly |
| SSAO | Not retro; adds too much realism |
| TAA / SMAA | Temporal smoothing defeats vertex wobble |
| Bloom | Avoid unless doing a neon/glow world variant |
| Shadow Maps | Use blob shadows or none; shadow maps are too modern |

Disable MSAA and HDR in `PC_RPAsset.asset` (`Assets/Settings/`).

---

## Per-World Color Notes

Each world should have a dominant palette of 2–3 saturated colors. The retro look comes partly from *not* mixing many colors. Examples drawn from the references:

| World Type | Sky | Ground | Geometry |
|---|---|---|---|
| Platform World | Bright blue | Neon green (dithered) | Red, yellow, white |
| Prison World | Near-black | Dark gray | Black, deep red |
| Void/dream worlds | Black | None | White, electric blue |
| Indoor/studio | Off-black void | Two-tone checkerboard | High-contrast primaries |

See `worlds.md` for full world descriptions.

---

## Verification Checklist

Open `Assets/Scenes/FirstPersonTesting.unity` in Play Mode and confirm:

- [ ] Pixels are hard and chunky — no anti-aliasing blur on edges
- [ ] Horizontal scanline bands visible across the full screen including sky
- [ ] Moving the camera causes subtle vertex wobble on world geometry
- [ ] Geometry faces show hard flat shading (no smooth gradient across a polygon)
- [ ] Distance fog cuts off with a solid color wall, not a soft fade
- [ ] Color palette looks saturated and banded, not photorealistic
