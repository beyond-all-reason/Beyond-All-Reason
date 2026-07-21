# tileset_dev — Mars prototype layer textures

All textures CC0 from Poly Haven (https://polyhaven.com/license), fetched 2026-07-14, 2K JPG.

Active layers — Poly Haven "namaqualand" collection (same-session red-rock desert photogrammetry; 4K diffuse + 2K nor/arm):

| Layer | Asset | Maps | Source |
|---|---|---|---|
| 0 sand flats | sandy_gravel_02 | diff 4k, nor_gl 2k, arm 2k | https://polyhaven.com/a/sandy_gravel_02 |
| 1 gravel/talus | gravelly_sand | diff 4k, nor_gl 2k, arm 2k | https://polyhaven.com/a/gravelly_sand |
| 2 cliff walls (biplanar) | cliff_side | diff 4k, nor_gl 2k, arm 2k | https://polyhaven.com/a/cliff_side |
| 3 striated plateau tops | tiger_rock | diff 4k, nor_gl 2k, arm 2k | https://polyhaven.com/a/tiger_rock |

Spare in-collection: rock_face (https://polyhaven.com/a/rock_face).

Retired (files kept):

| Asset | Reason | Source |
|---|---|---|
| red_laterite_soil_stones | mixed-source clash | https://polyhaven.com/a/red_laterite_soil_stones |
| rocky_terrain_03 | baked-in green moss | https://polyhaven.com/a/rocky_terrain_03 |
| moon collection (moon_01, moon_dusted_01/02, moon_meteor_01) | too featureless at RTS zoom | https://polyhaven.com/collections/moon |
| aerial_sand | mixed-source clash | https://polyhaven.com/a/aerial_sand |
| rocks_ground_05 | mixed-source clash | https://polyhaven.com/a/rocks_ground_05 |
| rock_face_03 | mixed-source clash | https://polyhaven.com/a/rock_face_03 |
| rock_boulder_dry | mixed-source clash | https://polyhaven.com/a/rock_boulder_dry |

arm = packed AO (R), roughness (G), metalness (B). nor_gl = OpenGL-handedness normal map.

## PoC-only assets (NOT license-safe to ship)

| Asset | Purpose | Provenance | License note |
|---|---|---|---|
| quarry_cliff_chunky_nor_gl_2k.png | P2.8+ chunky cliff/foothills test normal (MrBob) | textures.com `TCom_Rock_QuarryCliff10_3x3_2K_normal.tif`, supplied by MrBob 2026-07-14; converted 8-bit PNG, green channel flipped DX->GL | textures.com EULA — prototype testing ONLY, replace before any release |
