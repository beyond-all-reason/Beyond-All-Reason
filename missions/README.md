# Missions

Campaign and mission definitions for the Mission API.

## Layout

```
missions/
├── campaigns/
│   └── <NN_campaign>/            NN_ prefix sets display order
│       ├── campaign.json
│       ├── <asset>.jpg|png       campaign art (background, logo)
│       └── <NN_mission>/         any subfolder is a mission
│           ├── mission.json      lobby data: title, briefing, start script
│           ├── <mission>.lua     in-game logic
│           └── <asset>.jpg
├── standalone/                   missions with no campaign
│   └── <NN_mission>/             same contract as a campaign mission
└── schemata/
    ├── campaign.schema.json
    └── mission.schema.json
```

Everything a mission owns lives in its own folder, so it can be added, moved or removed as a single directory.

`mission.json` is read by the lobby before launch. The Lua is read by the engine and returns `Stages`, `Objectives`,
`Triggers`, `Actions`, `UnitLoadout`, `FeatureLoadout`. Set `$schema` in `mission.json` for editor completion —
`../../../schemata/…` in a campaign, `../../schemata/…` in `standalone/`.

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
standalone mission must set the first three itself. `authors` is optional everywhere.

## Validating

```sh
lua tools/validate_mission.lua missions/campaigns/01_armada/03_sound_test
```

Runs the same loader and validation as `luarules/gadgets/api_missions.lua` and exits non-zero on errors.
`--permissive-defs` skips weapon and feature def checks, `--verbose` adds informational output.

`01_armada/05_validation_test` fails on purpose: it exercises every error path.
