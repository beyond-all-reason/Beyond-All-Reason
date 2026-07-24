# HDR rendering contract

BAR uses the RecoilEngine HDR output API when
`Engine.FeatureSupport.hdrOutputApiVersion >= 1`. Older engines and
`HDRMode=off` retain the legacy SDR rendering path.

## Color-space stages

- World geometry and material shaders write scene-linear extended-sRGB values
  to the engine scene target. The `hdrSceneLinear` material uniform disables
  BAR's legacy per-material tone mapping in this path.
- Scene-space post-processing runs in `DrawScreenEffects`. Bloom samples the
  resolved `$scene_color` texture, uses scene-linear Rec.709 luminance for its
  threshold, and writes its result back before engine presentation.
- The engine applies the SDR or HDR presentation transform once, after
  `DrawScreenEffects`.
- Engine and Lua UI are composited by Recoil after scene presentation at the
  configured SDR reference-white level. UI assets and colors remain sRGB.

The shared screen-copy API returns `$scene_color` and `$scene_depth` while the
HDR scene target is active. These are engine-owned, read-only named textures;
consumers must not delete them. On older engines and in the legacy SDR path,
the API retains its per-frame `gl.CopyToTexture` behavior.

## Audited effects

Bloom is scene-linear and HDR-aware. Depth of field, contrast-adaptive
sharpening, distortion, glass, sepia/color filtering, and GUI background blur
remain scene-space effects through `DrawScreenEffects`; their shared
screen-copy inputs preserve HDR values when they use the screen-copy manager.
Effects that allocate private color copies still use their declared texture
formats and should be converted separately before being enabled as part of the
validated HDR preset.

Changing `HDRMode` (`off`, `auto`, or `on`) requires an engine restart. The
graphics options query `Spring.GetHDRInfo()` and show display capability, OS
HDR state, current-window HDR state, effective output, and any fallback reason.
