# Missions

Campaign and mission definitions for the Mission API.

## Layout

```
data/singleplayer/
├── campaigns/
│   ├── manifest.json             campaign order
│   └── <campaign>/
│       ├── campaign.json
│       ├── <asset>.jpg|png       campaign art (background, logo)
│       ├── shared/               assets shared by this campaign's missions
│       │   ├── language/         translations
│       │   ├── maps/             maps shipped with the campaign
│       │   ├── media/            images, video, audio
│       │   └── mutators/         tweakdefs and tweakunits
│       └── <mission>/            any other subfolder is a mission
│           ├── mission.json      lobby data: title, briefing, start script
│           ├── <mission>.lua     in-game logic
│           └── language/, media/, mutators/    same roles, mission-only
├── scenarios/                    missions belonging to no campaign
│   ├── manifest.json             scenario order
│   └── <mission>/                same contract as a campaign mission
└── schemas/
    ├── manifest.schema.json
    ├── campaign.schema.json
    └── mission.schema.json
```

Everything a mission owns lives in its own folder, so it can be added, moved or removed as a single directory. Assets
used by more than one mission of a campaign go in the campaign's `shared/`; `shared` is therefore reserved and is not
read as a mission.

`mission.json` is read by the lobby before launch. The Lua is read by the engine and returns `Stages`, `Objectives`,
`Triggers`, `Actions`, `UnitLoadout`, `FeatureLoadout`. Set `$schema` in `mission.json` for editor completion —
`../../../schemas/…` in a campaign, `../../schemas/…` in `scenarios/`.

## Presentation order

Order is declared, and always by ID rather than by path:

| List         | Lives in                  | Orders                        |
|--------------|---------------------------|-------------------------------|
| `campaigns`  | `campaigns/manifest.json` | campaigns                     |
| `scenarios`  | `scenarios/manifest.json` | campaign-less missions        |
| `missions`   | each `campaign.json`      | missions within that campaign |

The lists are optional. The lobby should display the items in listed order, and unlisted items
on disk should be appended, sorted by ID or name.

## Several files per mission

**Every `*.lua` directly inside the mission folder is a mission part**, combined into one mission.

| Key                                           | Combined by                              |
|-----------------------------------------------|------------------------------------------|
| `Stages`, `Objectives`, `Triggers`, `Actions` | merged by ID; a duplicate ID is an error |
| `UnitLoadout`, `FeatureLoadout`               | appended, in file name order             |
| `InitialStage`                                | only one file may set it                 |

Files are sorted by name before merging. Duplicate IDs and unknown keys fail at load time, naming both files.

## Shared names and inherited settings

Team and ally team names come from `startScript.allyTeams` in `mission.json`; the Lua refers to them as `teamName` and
`allyTeamName`.

`unlocks` in `campaign.json` maps `missionId` to its prerequisites. Missions not listed there are available from the
start.

`players` and `authors` are campaign level. A campaign mission may override them; a scenario must set `players` itself.
`authors` is optional everywhere.

## Validating

```sh
lua tools/validate_mission.lua data/singleplayer/campaigns/armada/sound_test
```

Runs the same loader and validation as `luarules/gadgets/api_missions.lua` and exits non-zero on errors.
`--permissive-defs` skips weapon and feature def checks, `--verbose` adds informational output.

`armada/validation_test` fails on purpose: it exercises every error path.
