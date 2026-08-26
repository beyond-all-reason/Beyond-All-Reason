# Missions

Campaign and mission definitions for the Mission API.

## Layout

```
missions/
├── manifest.json                 order of campaigns and scenarios
├── campaigns/
│   └── <campaign>/
│       ├── campaign.json
│       ├── <asset>.jpg|png       campaign art (background, logo)
│       └── <mission>/            any subfolder is a mission
│           ├── mission.json      lobby data: title, briefing, start script
│           ├── <mission>.lua     in-game logic
│           └── <asset>.jpg
├── scenarios/                    missions belonging to no campaign
│   └── <mission>/                same contract as a campaign mission
└── schemata/
    ├── manifest.schema.json
    ├── campaign.schema.json
    └── mission.schema.json
```

Everything a mission owns lives in its own folder, so it can be added, moved or removed as a single directory.

`mission.json` is read by the lobby before launch. The Lua is read by the engine and returns `Stages`, `Objectives`,
`Triggers`, `Actions`, `UnitLoadout`, `FeatureLoadout`. Set `$schema` in `mission.json` for editor completion —
`../../../schemata/…` in a campaign, `../../schemata/…` in `scenarios/`.

## Presentation order

Order is declared, and always by ID rather than by path:

| List                      | Lives in             | Orders                            |
|---------------------------|----------------------|-----------------------------------|
| `campaigns`, `scenarios`  | `manifest.json`      | campaigns, campaign-less missions |
| `missions`                | each `campaign.json` | missions within that campaign     |

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

`players`, `difficulties`, `defaultDifficulty` and `authors` are campaign level. A campaign mission may override them; a
scenario must set the first three itself. `authors` is optional everywhere.

## Validating

```sh
lua tools/validate_mission.lua missions/campaigns/armada/sound_test
```

Runs the same loader and validation as `luarules/gadgets/api_missions.lua` and exits non-zero on errors.
`--permissive-defs` skips weapon and feature def checks, `--verbose` adds informational output.

`armada/validation_test` fails on purpose: it exercises every error path.
