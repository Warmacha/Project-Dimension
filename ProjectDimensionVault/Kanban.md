---

kanban-plugin: board

---

## Backlog



## In Progress

- [ ] **Fog & Sky Per World** — solid color fog walls and gradient/flat skies
	- [ ] Set Linear fog in each scene (`Lighting → Environment → Fog`) with world-specific color (see `docs/visual-style.md`)
	- [ ] Create solid-color or two-band gradient skybox material for each world


## Review

- [ ] **Retro Geometry Shader** — vertex snapping, flat shading, affine UV in one custom URP shader
	- [x] Create custom URP shader (HLSL) with screen-space vertex snap for PS1 wobble
	- [x] Add flat shading via DDX/DDY face-normal reconstruction in fragment
	- [x] Add `_AffineBlend` float to lerp between affine and perspective-correct UV interpolation
	- [x] Shadow casting + receiving with colored shadow tint (`_ShadowColor`) instead of Bayer dither
	- [x] Apply as base material to all world geometry
- [ ] **Pixelation + Base Rendering Setup** — render to low-res RT with point filter; kill modern rendering features
	- [x] Create `ScriptableRendererFeature` that blits scene → 320×240 `RenderTexture` (FilterMode.Point) → screen
	- [x] Add feature to `Assets/Settings/PC_Renderer.asset` and `Mobile_Renderer.asset`
	- [x] In `PC_RPAsset.asset`: disable MSAA, disable HDR, disable SSAO
- [ ] **Scanline + Dither Post Pass** — full-screen shader for the CRT look
	- [x] Merge with pixelation upsample: single full-screen pass that point-samples the 320×240 RT and applies scanlines/dither in the same shader (eliminates one full-screen blit vs. separate passes)
	- [x] Implement scanline bands: `frac(screenUV.y * _ScreenParams.y) < 0.5` at ~35% multiply opacity
	- [x] Implement 4×4 Bayer ordered dither + color step quantization (`_ColorSteps` 4–8)
	- [x] Expose `_ScanlineOpacity`, `_ColorSteps`, `_DitherStrength` as material properties for per-scene tuning
- [ ] 


## Done

- [ ] 




%% kanban:settings
```
{"kanban-plugin":"board","list-collapse":[false,false,false,false]}
```
%%