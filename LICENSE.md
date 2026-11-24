# Licensing

Beyond All Reason is made of code, which is free software, and of art and
audio, each file of which carries the license its author chose. This file is
the map; the authoritative records are listed below.

## Code

All code in this repository is licensed under the GNU General Public License,
version 2 or later (`SPDX-License-Identifier: GPL-2.0-or-later`), unless a
file or directory notice says otherwise. Individual files may carry a more
permissive, GPL-compatible license such as MIT in their header or in
`GetInfo()`. The Recoil engine requires that everything the game loads be
compatible with GPL-2.0-or-later. Full texts are in [LICENSES/](LICENSES/).

Behavior scripts (`.bos`, `.cob`), shaders, Lua definition tables and other
configuration are code; see [legal/POLICY_PROJECT_LICENSE.md](legal/POLICY_PROJECT_LICENSE.md)
for how hybrid content such as visual effects is split.

## Art and audio

Every art and audio file is recorded individually in
`.github/file-license-assignments.json`, and each art directory lists its
files in a generated `LICENSE_MANIFEST.md`. A file is under one of:

| License | SPDX identifier | Meaning |
|---|---|---|
| BAR Project License (CLA) | `LicenseRef-BAR-CLA-1.0` | Use within Beyond All Reason and BAR-approved projects, including streams, trailers and mods on approved platforms. No reuse elsewhere. The author keeps copyright. [Summary](legal/CLA_SUMMARY.md), [full text](legal/CLA.md). |
| Creative Commons BY-SA 4.0 | `CC-BY-SA-4.0` | Free reuse with attribution and share-alike. [Opt-in](legal/CC-BY-SA-OPT-IN.md). |
| Other listed licenses | `GPL-2.0-or-later`, `CC0-1.0`, `CC-BY-4.0`, `CC-BY-SA-3.0`, `OFL-1.1`, `WTFPL`, ... | As recorded for that file; texts in [LICENSES/](LICENSES/). |

Files recorded as *awaiting license* have a known author but no license grant
yet. They remain their author's copyright, are distributed only as part of the
game, and may not be reused outside it. The project is collecting those
licenses; see [legal/FAQ_CONTRIBUTING_ART.md](legal/FAQ_CONTRIBUTING_ART.md).

Purchased and stock material (store sound effects, models and textures) is not
kept in this repository. It ships only inside the game archive from a private
companion repository under the stores' licenses, and nothing in this repository
grants rights to it.

## Contributing

New art and audio is licensed in the pull request: the CLA bot adds a choice
between the BAR Project License and CC-BY-SA 4.0 to the PR description. Code is
GPL-2.0-or-later by contribution. Details in [CONTRIBUTING.md](CONTRIBUTING.md)
and [legal/](legal/).
