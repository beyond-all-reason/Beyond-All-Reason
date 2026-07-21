# Special Thanks

The tileset terrain work in this directory builds on material generously shared by others.
Named here so the design docs themselves can stay focused on the technical record.

## MrBob

For the terrain revamp proposal that motivated this whole pipeline, and for the reference material and direction that shaped it:

- The **terrain revamp proposal** — the case for shader-driven, tileset-based terrain instead of per-map baked megatextures.
- The **two-phase angle-sorting technique** (sample → project → sort → flavor), demonstrated in a ~7:35 Unreal Engine walkthrough with a transcript, frame captures, and material-graph screenshots.
- The **HLSL reference implementation** used as the look target for the prototype.
- The **foothills intermediary-layer** insight — an explicit angle band carrying its own intense normal — and the "don't hybridize, go all the way" direction on committing to the tileset look.
- The **`Abstract_1.PNG` stagger mask** and the **`TCom_Rock_QuarryCliff10_3x3` chunky test normal** used to prototype the height-lerp stagger and pixel-normal scatter.
- The reserved **"mesh atlas + params"** spec section for the later mesh/prop-scattering phases.

## Beherith

For the **Advanced Mapping Guide** and the `springrts_smf_compiler` (pymapconv) toolchain, which grounded the tileset pipeline in the realities of the existing map-compiler flow — heightmap/diffuse conventions, DNTS as the runtime detail-layer precedent, lighting norms, and the engine quirks worth not re-importing (see `tileset-terrain-plan.md` §6b).

## Recoil documentation

For the engine and Lua-API documentation that made the map-shader contract, deferred G-buffer layout, and terraform/deform plumbing legible enough to build against.
