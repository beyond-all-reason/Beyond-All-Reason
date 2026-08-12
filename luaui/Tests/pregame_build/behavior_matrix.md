# Build-placement behavior comparison

This is the manual behavior table used while developing the yardmap-aware queue change. The automated coverage following
the table explains which assertion checks each observation. “Yardmap-aware” and “rectangle compatibility” runs use the
same engine binary and fixtures; the latter sets `construction.useYardmapsForQueuedBuildOverlap = false`.

## Terminology

- **Queue overlap:** overlap with an earlier queued build.
- **Cancel region:** overlap large enough that clicking removes the earlier queued build.
- **Yardmap overlap:** occupied yardmap cells intersect.
- **Before 🟢 → after:** behavior before and after the yardmap-aware queue change. The green marker highlights changed
  behavior.
- **—:** no earlier queued build is involved.

The case “inside the cancel region without yardmap overlap” cannot be tested independently.

## Pregame

| Placement scenario                            | Earlier queued build   | Non-BuildSquare GL4 preview  | BuildSquare GL4 preview                                   | Click result                                          |
|-----------------------------------------------|------------------------|------------------------------|-----------------------------------------------------------|-------------------------------------------------------|
| Free space                                    | —                      | Green square                 | All cells green                                           | New build is queued                                   |
| Terrain obstruction, with yardmap overlap     | —                      | Red square                   | All cells red                                             | New build is not queued                               |
| Terrain obstruction, without yardmap overlap  | —                      | Green square                 | Overlapping cells red and rest yellow                     | New build is queued                                   |
| Slight queue overlap, with yardmap overlap    | Keeps its green square | Red square                   | All cells red, regardless of which cells overlap          | Nothing happens                                       |
| Slight queue overlap, without yardmap overlap | Keeps its green square | Red square 🟢 → green square | All cells red 🟢 → all cells green                        | Nothing happens 🟢 → new build is queued              |
| Inside cancel region, with yardmap overlap    | Gets a red square      | Green square                 | Red outline; overlapping cells red; remaining cells green | Earlier build is dequeued                             |
| Over commander/builder                        | —                      | Green square                 | All cells green                                           | A red square appears briefly; new build is not queued |

## In-game

| Placement scenario                                   | Earlier queued build         | Non-BuildSquare GL4 preview                                                                             | BuildSquare GL4 preview                                                                                       | Click result                             |
|------------------------------------------------------|------------------------------|---------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|------------------------------------------|
| Free space                                           | —                            | All cells green                                                                                         | All cells green                                                                                               | New build is queued                      |
| Terrain obstruction, with yardmap overlap            | —                            | Overlapping cells red and rest yellow                                                                   | Cells intersecting the footprint rectangle are red; rest yellow                                               | New build is not queued                  |
| Terrain obstruction, without yardmap overlap         | —                            | Overlapping cells red and rest yellow                                                                   | Cells intersecting the footprint rectangle are red; rest yellow                                               | New build is NOT queued                  |
| Completed building, with yardmap overlap             | —                            | Yardmap-conflicting cells red; rest yellow                                                              | Yardmap-conflicting cells red; rest yellow                                                                    | New build is not queued                  |
| Completed building, without yardmap overlap          | —                            | Same as free space                                                                                      | Same as free space                                                                                            | New build is queued                      |
| Slight queue overlap, with yardmap overlap           | Keeps its green square       | Cells intersecting the earlier build’s outline red; rest yellow 🟢 → only yardmap-conflicting cells red | Cells intersecting the earlier build’s outline red; rest yellow 🟢 → only yardmap-conflicting cells red       | Nothing happens                          |
| Slight queue overlap, without yardmap overlap        | Keeps its green square       | Cells intersecting the earlier build’s outline red; rest yellow 🟢 → all cells green                    | Cells intersecting the earlier build’s outline red; rest yellow 🟢 → all cells green                          | Nothing happens 🟢 → new build is queued |
| Inside cancel region, with yardmap overlap           | Green square 🟢 → red square | All cells green 🟢 → overlapping cells red; remaining cells green                                       | All cells green 🟢 → overlapping cells red; rest yellow                                                       | Earlier build is dequeued                |
| Building under construction, with yardmap overlap    | —                            | Cells intersecting the building outline red; rest yellow 🟢 → only yardmap-conflicting cells red        | Red outline; cells intersecting the building outline red; rest yellow 🟢 → only yardmap-conflicting cells red | Nothing happens                          |
| Building under construction, without yardmap overlap | —                            | Cells intersecting the building outline red; rest yellow 🟢 → all cells green                           | Cells intersecting the building outline red; rest yellow 🟢 → all cells green                                 | Nothing happens 🟢 → new build is queued |
| Over commander/builder/unit                          | —                            | Green square; unit-occupied cells yellow                                                                | Free cells green; unit-occupied cells yellow                                                                  | New build is queued                      |

## Pregame vs in-game differences

Cases that were consistent both before and after the change are omitted.

🟢 resolved · 🟡 preview difference only · 🔴 click/behavior difference

| Placement scenario | Before: pregame vs in-game | After: pregame vs in-game | Status |
|---|---|---|---|
| Terrain obstruction, with yardmap overlap | Both reject the build, but pregame shows the whole footprint red while in-game distinguishes red and yellow cells | Unchanged | 🟡 **Remains:** previews differ |
| Terrain obstruction, without yardmap overlap | Pregame queues the build with a green outline; in-game rejects it with a red/yellow preview | Unchanged | 🔴 **Remains:** click behavior differs |
| Slight queue overlap, with yardmap overlap | Both reject the build, but pregame shows the whole footprint red while in-game distinguishes yardmap-conflicting cells | Both still reject the build; pregame remains entirely red while in-game now marks only yardmap-conflicting cells red | 🟡 **Remains:** previews differ |
| Slight queue overlap, without yardmap overlap | Both reject the build, with different blocked previews | Both show a green preview and queue the new build | 🟢 **Resolved** |
| Inside cancel region, with yardmap overlap | Both dequeue the earlier build, but pregame and in-game highlight the cancellation differently | Both mark the earlier build and overlapping cells red and dequeue it, but outline and remaining-cell colors still differ | 🟡 **Remains:** previews differ |
| Over commander/builder | Pregame rejects the build despite a green preview; in-game marks occupied cells yellow and queues it | Unchanged | 🔴 **Remains:** intentional pregame restriction |

## Design notes

- Pregame placement over the commander/builder can be made configurable, but allowing it is probably undesirable.
- Allowing construction when invalid terrain intersects only open yardmap cells might be desirable, but would require a
  substantial change.

## Automated coverage

| Manual scenario | Automated check | With yardmap-aware queue | Rectangle compatibility |
|---|---|---|---|
| Pregame free space | Not automated: the current headless runner starts after frame zero. | Manual result only | Manual result only |
| Pregame terrain obstruction, either yardmap state | Not automated. The real in-game terrain fixtures below do not exercise the pregame widget. | Manual result only | Manual result only |
| Pregame slight queue overlap, with yardmap overlap | `test_yardmap_queue_behavior.lua` verifies the engine classification used by pregame, but not the pregame Lua queue mutation. | Engine result verified; click remains manual | Same |
| Pregame slight queue overlap, without yardmap overlap | The same test verifies that the API changes from rectangle overlap to no overlap. The pregame widget consumes this API, but its click remains manual. | Engine result verified; click remains manual | Engine result verified; click remains manual |
| Pregame cancel-region overlap | The same test verifies the engine cancellation classification. Actual pregame removal remains manual. | Engine result verified; click remains manual | Same |
| Pregame commander/builder restriction | Not automated. | Manual result only | Manual result only |
| In-game free space | `test_yardmap_queue_behavior.lua`: the first real constructor build command remains queued. | Accepted | Accepted |
| In-game terrain obstruction on an occupied yardmap cell | `test_world_obstruction_behavior.lua`: raises one occupied solar cell by 200 elmos and sends a real build command. | Rejected | Rejected |
| In-game terrain obstruction on an open yardmap cell | The same test raises one open corner yardmap cell by 200 elmos. This explicitly tests terrain versus yardmap openness. | Rejected | Rejected |
| Completed building, with yardmap overlap | Creates a completed solar, then sends a conflicting real solar command. | Rejected | Rejected |
| Completed building, without yardmap overlap | Creates a completed solar, then sends a diagonally interlocking real solar command. | Accepted | Accepted; placed-unit yardmaps predate this change |
| Slight queued overlap, with yardmap overlap | Real constructor queue contains one command after the conflicting second command. | Rejected | Rejected |
| Slight queued overlap, without yardmap overlap | Real constructor queue length is checked after the interlocking second command. | Two commands | One command |
| Cancel-region queued overlap | Real constructor queue becomes empty after the second command. | Earlier command removed | Earlier command removed |
| Active construction, with yardmap overlap | A constructor starts a real nanoframe; after it appears with build progress below one, a conflicting second command is sent. The active command remains and the second is rejected. | One command | One command |
| Active construction, without yardmap overlap | Same active-nanoframe fixture with the diagonal interlock. | Two commands | One command |
| Mobile unit inside the proposed footprint | Creates a mobile `armck` on the solar site and sends a real build command from another constructor. | Command accepted so the unit can move away | Same |

The behavioral assertions above do not compare rendered pixels. Cell colors are determined from the engine
`DrawBuildSquare(..., statuses)` values and the Lua status-to-color mapping, while queued-outline red/green selection is
native. Those two data boundaries need focused status/color tests before the preview columns can be considered fully
automated. Until then, the preview wording in the manual table remains the visual oracle; the click-result columns are
programmatically checked as described above.

## Reproducing both runs

Run the normal headless integration suite for the yardmap-aware result. For the compatibility result, add
`useYardmapsForQueuedBuildOverlap = false` under `construction` in `gamedata/modrules.lua` and rerun the identical suite.
Do not change the expected outcomes: the tests read `Game.useYardmapsForQueuedBuildOverlap` and assert the appropriate
column above.

The matrix was run successfully in all three configurations on 2026-08-12:

- Local PR engine `2026.07.01-16-g9925d0a`, yardmap-aware mode: 10 passed, 8 skipped, 0 failed.
- The identical local PR engine with rectangle compatibility enabled: 9 passed, 9 skipped, 0 failed. The faction
  substitution test is intentionally skipped because it requires yardmap-aware classification.
- Installed stock engine `2026.07.04`, which has no `Spring.TestBuildOrderOverlap` API: 9 passed, 9 skipped, 0 failed.

The stock-engine and compatibility-mode behavioral results matched. The yardmap-aware run differed only in the intended
cases: a queued compatible solar and a compatible solar after an active nanoframe were accepted instead of rejected.
