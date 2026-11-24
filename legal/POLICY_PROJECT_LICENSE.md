<!-- REUSE-IgnoreStart -->
# BAR Project License Policy (Contributions Only)

## Who is this for?

BAR Team B.V., or BAR for short. This policy explains how creative contributions to the BAR project
are handled.

## 1. Code Contributions

- Default: GPLv2 (`SPDX: GPL-2.0-or-later`)
- Optional: MIT (`SPDX: MIT`) (GPLv2-compatible)

Contributors retain ownership. Contribution licensing is governed by repository notices.

### Behavior Scripts (BOS/COB)

Files defining unit movement, animation triggers, and behavioral logic (`.bos`, `.cob`) are
considered **code**, even if they contain animation data exported from modeling tools.
These files are licensed under the project's code license (GPL).

The underlying models, rigs, and animations used to generate these scripts remain **art assets**
and are licensed under the BAR Art License / Contributor Agreement.

**Safety clause:** Contributors who export animation data into behavior scripts confirm that they
have the right to license any included animation data under the code license.

### Shaders

Shader code files (`.glsl`, `.frag`, `.vert`) are **code** and must be GPLv2-or-later compatible.
Texture files and other creative dependencies used by shaders remain **art assets** and fall
under the art licensing buckets below.

### Visual Effects (Hybrid Licensing)

Visual effects are composed systems that may include scripts, configuration data, shaders,
textures, and models. Each component is licensed according to its nature. A single visual
effect may contain components that fall under multiple license categories simultaneously.

| Component | Examples | License | SPDX Identifier |
|---|---|---|---|
| Effect logic scripts | `LuaRules/Gadgets/explosions.lua` | Code (GPL) | `GPL-2.0-or-later` |
| Effect definition files | `effects/antinuke.lua`, particle config tables | Code / Gameplay Data (GPL) | `GPL-2.0-or-later` |
| Effect textures | `effects/smoke.png`, `effects/flame.dds` | Art Asset (CLA or CC-BY-SA) | `LicenseRef-BAR-CLA-1.0` or `CC-BY-SA-4.0` |
| Effect models | `effects/debris.obj`, `effects/shockwave.dae` | Art Asset (CLA or CC-BY-SA) | `LicenseRef-BAR-CLA-1.0` or `CC-BY-SA-4.0` |
| Effect shaders | `shaders/explosion_gl4.vert` | Code (GPL) | `GPL-2.0-or-later` |

**Classification rules:**

1. Files that define logic, behavior, or engine configuration are **code** (GPL).
2. Files that contain visual content (textures, models) are **art assets** (CLA or CC-BY-SA).
3. Lua configuration tables defining particle systems or effect composition (e.g. CEG
   definitions with `class`, `count`, `properties` fields) are **code / gameplay data** (GPL).

## 2. Art & Audio Contributions

Contributors select one of two buckets:

### A. BAR Project License (default) — `SPDX: LicenseRef-BAR-CLA-1.0`

- Contributor retains ownership
- BAR receives a non-exclusive license to use the work **as part of the game**
- Includes use in gameplay, streams/Let's Plays, trailers, reviews, and promotion
- Includes use in **third-party** mods that run within the BAR game engine and are distributed through BAR-approved modding platforms
- Restricted to BAR and BAR-derived projects
- Prevents assets drifting into unrelated games
- Music/audio contributors must confirm the work is **not** controlled by collecting societies

### B. CC-BY-SA 4.0 Opt-In — `SPDX: CC-BY-SA-4.0`

- Contributor must explicitly opt in
- Allows open reuse with attribution + share-alike
- Contributor still retains ownership

## 3. Internal Metadata / Tracking

The project uses a manifest and automated workflow to track:

- contributor names
- chosen license bucket
- asset locations

This is an internal tool and does not affect contributor rights.

## 4. SPDX Convention

The project uses [SPDX license identifiers](https://spdx.dev/learn/handling-license-info/)
as the standard machine-readable format for expressing license information.

- **Text source files** should include an `SPDX-License-Identifier:` comment as the
  first line (using the file's native comment syntax).
- **Binary files** (models, textures, audio) are covered by directory-level notices
  or `REUSE.toml` / `.license` sidecar files.
- **Custom licenses** (BAR CLA) use the `LicenseRef-` prefix per the SPDX spec.

The full SPDX identifier mapping is in the table above and in `legal/README.md`.
<!-- REUSE-IgnoreEnd -->
