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
│       ├── language/             translations for the campaign
│       ├── shared/               assets shared by this campaign's missions
│       │   ├── language/         translations shared by all missions
│       │   ├── maps/             maps shipped with the campaign
│       │   ├── media/            images, video, audio
│       │   └── mutators/         tweakdefs and tweakunits
│       └── <mission>/            a subfolder listed in campaign.json
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
used by more than one mission of a campaign go in the campaign's `shared/`.

`mission.json` is read by the lobby before launch. The Lua is read by the engine and returns `Stages`, `Objectives`,
`Triggers`, `Actions`, `UnitLoadout`, `FeatureLoadout`. Set `$schema` in `mission.json` for editor completion —
`../../../schemas/…` in a campaign, `../../schemas/…` in `scenarios/`.

## What loads, and in what order

Content is loaded only if it is listed, in the order it is listed:

| List        | Lives in                  | Loads and orders              |
|-------------|---------------------------|-------------------------------|
| `campaigns` | `campaigns/manifest.json` | campaigns                     |
| `scenarios` | `scenarios/manifest.json` | campaign-less missions        |
| `missions`  | each `campaign.json`      | missions within that campaign |

A folder on disk that no list names is ignored. An archive at higher VFS priority may replace a manifest to reorder
content or add its own.

This is why `shared/` needs no special handling: it is never named as a mission, so it is never read as one.

## Text

Campaign and mission files hold no display text, only I18N keys, in properties named `…Key`. Strings live in
`language/<language>.json` next to the content that uses them, so a campaign carries its own translations:

| Strings for | Read from                                           |
|-------------|-----------------------------------------------------|
| a campaign  | `<campaign>/language/<language>.json`               |
| a mission   | its own `<mission>/language/…`, else its campaign's |
| a scenario  | its own `<mission>/language/…`                      |

A campaign or mission folder is named after its ID, so a listed ID is also the path to look in.

`briefing.newUnits` is keyed by UnitDefName rather than by position, so reordering the list does not rewrite keys.

A team's `nameKey` resolves to the start script `Name`, so its string must obey player name rules.

## Several files per mission

**Every `*.lua` directly inside the mission folder is a mission part**, combined into one mission.

| Key                                           | Combined by                              |
|-----------------------------------------------|------------------------------------------|
| `Stages`, `Objectives`, `Triggers`, `Actions` | merged by ID; a duplicate ID is an error |
| `UnitLoadout`, `FeatureLoadout`               | appended, in file name order             |
| `InitialStage`                                | only one file may set it                 |

Files are sorted by name before merging, so the result never depends on the order the filesystem returns. A duplicate ID
fails at load time naming both files; an unknown key fails naming the file that returned it. Subfolders are not scanned,
so shared Lua helpers can live in one.

## Shared names and inherited settings

Team names come from `mission.json`, and the Lua refers to them as `teamName`.

`unlocks` in `campaign.json` maps `missionId` to its prerequisites. Missions not listed there are available from the
start.

`players` and `authors` are campaign level. A campaign mission may override them; a scenario must set `players` itself.
`authors` is optional everywhere.

## Validating

```sh
lua tools/validate_mission.lua data/singleplayer/campaigns/armada-main/sound_test
```

Runs the same loader and validation as `luarules/gadgets/api_missions.lua` and exits non-zero on errors.
`--permissive-defs` skips weapon and feature def checks, `--verbose` adds informational output.

`armada/validation_test` fails on purpose: it exercises every error path.
