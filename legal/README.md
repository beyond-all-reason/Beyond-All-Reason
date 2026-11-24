# /legal — BAR Licensing Documents

This directory contains the licensing and contribution agreement documents for
the Beyond All Reason project.

## Files

| File | Purpose |
|------|---------|
| [CLA.md](CLA.md) | The full Contributor License Agreement for art & audio contributions |
| [CLA_SUMMARY.md](CLA_SUMMARY.md) | A short, contributor-friendly explanation of the CLA |
| [CC-BY-SA-OPT-IN.md](CC-BY-SA-OPT-IN.md) | Instructions for contributors who prefer open licensing |
| [POLICY_PROJECT_LICENSE.md](POLICY_PROJECT_LICENSE.md) | Internal overview of the BAR licensing buckets and SPDX convention |
| [FAQ_CONTRIBUTING_ART.md](FAQ_CONTRIBUTING_ART.md) | Practical guidance for artists and composers |

## How it works

When a pull request contains art or audio assets, our automated CLA workflow will:

1. Detect the presence of non-code files (models, textures, audio, etc.)
2. Post a comment asking the contributor to choose a license
3. The contributor accepts the **BAR Project License (CLA)** or opts for **CC-BY-SA 4.0**
4. The choice is recorded and the PR check passes

For code-only contributions, the existing GPLv2 license applies automatically
(`SPDX: GPL-2.0-or-later`).

## SPDX Identifiers

The project uses SPDX license identifiers for machine-readable license metadata:

| License | SPDX Identifier |
|---|---|
| Code (default) | `GPL-2.0-or-later` |
| BAR CLA (art default) | `LicenseRef-BAR-CLA-1.0` |
| CC-BY-SA 4.0 (art opt-in) | `CC-BY-SA-4.0` |

See [POLICY_PROJECT_LICENSE.md](POLICY_PROJECT_LICENSE.md) for full details.
