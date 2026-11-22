<!-- REUSE-IgnoreStart -->
# BAR — Art & Audio Contribution FAQ

## Who is this for?

BAR Team B.V., or BAR for short.

## Do I keep ownership of my work?

Yes. You always keep copyright.

## What does BAR get?

A permanent, non-exclusive license to use your work **as part of the game**, including
streams, trailers, and promotional material.

## Can streamers and reviewers show my work?

Yes — but only **as it naturally appears inside the game**.

## Can BAR modify my work?

Yes - but only for technical or artistic reasons needed for integration into BAR.

## Can my work be used in mods?

Yes. Your work can be used in third-party mods that run within the BAR game engine and are distributed through BAR-approved modding platforms like Steam Workshop. Your work cannot be extracted for standalone asset packs or used in unrelated games.

## Can I publish my own OST?

Yes. You retain all external music rights.

## Why must I confirm I'm not using a collecting society?

Collecting societies (for example, Buma/Stemra, GEMA, ASCAP) can block YouTube/Twitch streaming
and platform distribution. BAR needs to ensure this never happens.

## Can I release my art elsewhere?

Yes. The license is non-exclusive.

## What if I want my art to be open to everyone?

Choose the **CC-BY-SA 4.0** opt-in when submitting your PR.

## What about BOS/COB behavior scripts?

BOS and COB files (`.bos`, `.cob`) are treated as **code** and licensed under GPL, even when
they contain animation data exported from modeling tools. The underlying models, rigs, and
animations you used to generate those scripts remain **art assets** under the BAR Art License.

If you export animation data into a behavior script, you confirm that you have the right to
license any included animation data under the code license.

## What about shaders?

Shader code (`.glsl`, `.frag`, `.vert`) is **code** and must be GPLv2-or-later compatible.
Textures and other creative files used by shaders remain **art** and follow the normal
CLA / CC-BY-SA-4.0 choice.

## What about visual effects (particles, explosions)?

Visual effects are hybrid — they contain both code and art components. Each part is
licensed according to its nature:

- **Effect logic scripts** (Lua gadgets that trigger/control effects) → **Code (GPL)**
- **Effect definition files** (Lua tables with particle parameters like CEG defs) → **Code (GPL)**
- **Effect textures** (smoke.png, flame.dds, spark atlases) → **Art (CLA or CC-BY-SA)**
- **Effect models** (debris meshes, shockwave geometry) → **Art (CLA or CC-BY-SA)**
- **Effect shaders** (.glsl, .frag, .vert) → **Code (GPL)**

A single explosion effect might have a Lua definition (GPL), a particle texture (CLA),
and a shader (GPL) — each component keeps its own license.

## What are SPDX identifiers?

SPDX identifiers are short, standardized strings that identify licenses in a machine-readable
way. The project uses them in file headers, directory notices, and workflow outputs:

- Code: `SPDX-License-Identifier: GPL-2.0-or-later`
- Art (CLA): `SPDX-License-Identifier: LicenseRef-BAR-CLA-1.0`
- Art (CC-BY-SA): `SPDX-License-Identifier: CC-BY-SA-4.0`

For text files, add the identifier as the first comment line. For binary art assets
(models, textures, audio), the license is tracked via directory-level notices or
sidecar `.license` files.

## Is this a legal contract?

Yes — the CLA is a lightweight contributor agreement like KDE, and Canonical use.

## How do I license my past contributions?

If you have previously contributed art or audio to the repository, you can formalize
the license for your past work by making any new contribution (even a blank commit)
and accepting the CLA during the pull request process. The CLA explicitly covers
all past contributions.

## Who is the original author when multiple artists work on an asset?

The original creator of an asset remains the owner, even when new contributors make
modifications. New contributors can be listed separately, but the original author
stays the same unless the asset has been completely remade from scratch.

## What if I want to submit artwork on behalf of an artist who doesn't usually use GitHub?

A contributor with a GitHub account (typically a developer or integration maintainer) can
submit and license artwork on behalf of artists that don't want to bother with making PRs themselves.

Here is how the process works:

1. The **submitter** opens a PR with the art files and ticks the license choice as normal.
2. In the **License Selection** section added by the bot, the submitter also ticks
   **"I am submitting this artwork on behalf of another person"** and fills in the
   artist's GitHub handle (the artist must have at least a basic GitHub account).
3. After posting `/confirm-license`, the bot records the license as *pending* and tags
   the original artist in a comment, asking them to reply `/confirm-authorship`.
4. The **artist** replies `/confirm-authorship` to confirm the files are their work and
   that they approve the chosen license.
5. The PR status turns green and the license record credits the artist, not the submitter.

**Important constraints:**
- Only one proxy artist is supported per PR. If files from multiple artists are being
  submitted together, split them into separate PRs.
- The submitter cannot list themselves as the original artist via this mechanism.
- The artist's authorship confirmation is required before the PR can merge.

## What if an artist cannot or will not confirm on GitHub?

Contact a project maintainer. In documented exceptional cases a maintainer can verify
authorship off-platform (e.g. a direct email or forum post from the artist with the
file names and license choice stated explicitly) and apply a manual override. This
requires maintainer sign-off and an explanatory note in the PR.

## What happens if an art file is moved or renamed?

Moving or renaming an existing art file is **not** a re-licensing event. The bot reads
rename information from Git (via the GitHub PR API) and:

- During PR review, a renamed file whose previous path is already licensed counts as
  already-covered — the bot will not prompt for a new license.
- On merge, the bot rewrites the file path in `.github/cla-signatures.json` and
  `.github/file-license-assignments.json` so the record points at the new location.
  The license, original contributor, and source PR are preserved.
- Both the old and new directory's `LICENSE_MANIFEST.md` are regenerated to reflect
  the move.

This means routine reorganisation — moving a model from one unit folder to another,
renaming a texture to match a unit-id change — needs no extra licensing action.

Wholesale rewrites or replacements (a new asset committed under an existing path) are
handled by the separate **modified existing art** flow, which prompts you to declare
whether you replaced the file from scratch.
<!-- REUSE-IgnoreEnd -->
