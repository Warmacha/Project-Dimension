---

kanban-plugin: board

---

## Backlog

- [ ] **Scanline + Dither Post Pass** — full-screen shader for the CRT look
	- [ ] Create `FullScreenPassRendererFeature` + unlit shader/material
	- [ ] Implement scanline bands: `frac(screenUV.y * _ScreenParams.y) < 0.5` at ~35% multiply opacity
	- [ ] Implement 4×4 Bayer ordered dither + color step quantization (`_ColorSteps` 4–8)
	- [ ] Expose `_ScanlineOpacity`, `_ColorSteps`, `_DitherStrength` as material properties for per-scene tuning
- [ ] **Retro Geometry Shader** — vertex snapping, flat shading, affine UV in one custom URP shader
	- [ ] Create custom URP shader (ShaderGraph or HLSL) with vertex-stage world-position grid snap (`round(pos * precision) / precision`)
	- [ ] Add flat shading via DDX/DDY face-normal reconstruction in fragment, OR import all meshes at 0° smoothing angle
	- [ ] Add `_AffineBlend` float to lerp between affine and perspective-correct UV interpolation
	- [ ] Apply as base material to all world geometry
- [ ] **Fog & Sky Per World** — solid color fog walls and gradient/flat skies
	- [ ] Set Linear fog in each scene (`Lighting → Environment → Fog`) with world-specific color (see `docs/visual-style.md`)
	- [ ] Create solid-color or two-band gradient skybox material for each world


## In Progress

- [ ] **Pixelation + Base Rendering Setup** — render to low-res RT with point filter; kill modern rendering features
	- [ ] Create `ScriptableRendererFeature` that blits scene → 320×240 `RenderTexture` (FilterMode.Point) → screen
	- [ ] Add feature to `Assets/Settings/PC_Renderer.asset` and `Mobile_Renderer.asset`
	- [ ] In `PC_RPAsset.asset`: disable MSAA, disable HDR, disable SSAO
- [ ] 


## Review

- [ ] 


## Done

- [ ] 




%% kanban:settings
```
{"kanban-plugin":"board","list-collapse":[false,false,false,false]}
```
%%