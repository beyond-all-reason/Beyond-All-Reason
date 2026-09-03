# Mission API: Objectives — what is expected, and the cheapest way to deliver it

Rewritten 2026-08-27 after ingesting `Mission API Documentation.xlsx`. Supersedes the 2026-08-26
replan. Grounded in `mission-api/dev` @ a67c256717 and the two open PRs (#8913, #8914).

## 0. Sources, ranked

There are now four inputs, and they do not carry equal weight:

| Source | Weight | Why |
|---|---|---|
| The five tickets | **Contract.** Must ship. | This is what we were asked for, in writing. |
| WatchTheFort on #8913 | **Blocking.** | He reviews the PR. |
| `Mission API Documentation.xlsx` | **Design intent.** | The designer's own sheet; names and gaps, not decisions. |
| Our plan docs | Working notes. | Void where any of the above disagrees. |

The workbook's ✓/✕ column is decisions, not an audit — blanks are unreliable (`EnableTrigger` and
`DisableTrigger` are implemented and blank), but ✕ is deliberate and used six times. Both ✕ rows on
the *Engine requests* sheet spell out what it means: "consider this request as done", "should allow
cutscenes already". **✕ = not needed, something else already covers it.**

## 1. What the workbook actually says about objectives

Everything objective-shaped in the sheet, verbatim in the columns that matter:

### Triggers, family `Objective`

| Name | ✓ | Description | Parameters | To action context |
|---|---|---|---|---|
| `ObjectiveCompleted` | | Objective requirements have been fulfilled | `objectiveID` | `objectiveID` |
| `ObjectiveFailed` | | Objective requirements can no longer be fulfilled | `objectiveID` | `objectiveID, canRetry?` |
| `ObjectiveSkipped` | | Objective has become obsolete | `objectiveID` | `objectiveID, canRetry?` |
| `ObjectiveProgress` | | Incremental progress towards objective completion | `objectiveID, progress` | `objectiveID, count` |
| `TeamWon` | | The team satisfies its own win condition | `teamID, difficulty` | `allyTeamID` |
| `TeamLost` | | The team cannot satisfy its own win condition | `teamID, difficulty` | `allyTeamID` |

### Actions, family `Objective`

| Name | ✓ | Description | Parameters | Extra |
|---|---|---|---|---|
| `ShowObjective` | | **"This is how objectives are authored: within actions."** | `objectiveID, objectiveType` | `stageID` |
| `CompleteObjective` | | | | |
| `FailObjective` | | "Try to automate failures for impossible triggers. This is a fallback." | | |
| `CancelObjective` | | "Removal without triggering completion" | `objectiveID, objectiveType, outcome` | |
| `UpdateObjective` | ✓ | "Modify objective progress or statistics" | `objectiveID, objectiveType` | |
| `ResetObjectives` | | "Reinitialize all objectives on a stage as uncompleted" | `stageID` | |
| `AdvanceStage` | **✕** | "Move to the predefined next stage of the mission" | `stageID` | |
| `ChangeStage` | ✓ | "Move to an arbitrary stage of the mission" | `stageID` | |

### Elsewhere

- Guide/Internals: "Stages are bags containing objective IDs." Also, in the same breath,
  "Statistics objectives have a separate managed path from all other objectives" — filed under
  known defects, followed by "we can tolerate defects here. But lol."
- Guide/At home: "Presentation. Some actions have been produced but only for mission events like
  playing sounds… No other presentation exists." And: "There is no `SendToUnsynced` nor
  `RecvFromSynced`. There is no `SetGameRulesParam`. The UI fakes are just `Spring.Echo`."
- Guide/Requirements #5, "Full product", lists `presentation (synced -> unsynced)` as a first-class
  requirement alongside launching, results, progression and persistence.

## 2. Your reading, checked against it

**"Objectives are just logical boxes on triggers with presentation and actions to target them."**
Confirmed, and the sheet is blunter than we were. The authoring verb is `ShowObjective` — an
objective is a thing you *show*. Every objective trigger passes exactly `objectiveID` to the action
context and nothing else; none of them carry progression. Stage actions are filed under family
`Objective`, subject `stage`, which puts stages *inside* the objective concept rather than the
reverse. The designer's own summary is "bags containing objective IDs."

**"Maybe the action surface was the point."** That is the only reading that survives. Six of the
eight objective actions do nothing but move one objective between states; the tickets we were
handed are exactly that set. The feature is a verb surface over a display record.

**"Hidden objectives: seemingly unknown [pathway]."** There is no hidden-only pathway in the sheet
either, and there is a reason: the mechanism is already in the code and it is not a pathway, it is a
side effect. `updateObjectiveProgress` accrues managed counts in every non-terminal state and only
*evaluates* completion when active (objectives.lua:230-241). So an unrevealed objective is a
**counter that is already running**. `ShowObjective` then reveals a box that is already partly
filled, instead of asking the player to redo work they have done. Your guess in the second paragraph
is the whole answer; there is nothing further behind it.

The one thing a hidden objective can do that a plain trigger cannot: complete, fire
`ObjectiveCompleted`, drive logic invisibly, *and still be revealable later*. That is not a distinct
capability, it is a plain trigger that kept the option open. Do not design for it. One boolean in
the publisher and stop.

**"Stages are pure presentation… general mission logic probably has to live outside stages."**
Confirmed, and the escape hatch is already built and is already the default. `settings.stages` on a
trigger gates activation (api_missions_triggers.lua:66); a trigger that omits it is stage-agnostic
and always live. So stages are two things at once — a presentation bag, and an opt-in trigger scope.
Nothing to build. Mission logic lives outside stages by default and the author opts *in* to scoping.

**"Broken logic being technically expressible does not matter."** Then `validateStageExits` was
never going to survive, independent of the reviewer's objection, and neither should the
"objective is not listed in any stage" *error* (validation.lua:822). Ten triggers do not need a
theorem prover.

## 3. Where the workbook contradicts our last plan

One row, and it is the load-bearing one.

**`AdvanceStage` is ✕: "Move to the predefined next stage of the mission."** Given the settled
meaning of ✕, the designer considered predefined-next progression and concluded `ChangeStage`
already covers it. That is the same conclusion the reviewer's silence on the subject implies, and
the same one you reached on 2026-08-25 ("There is no `nextStage`. Stages are graphs. There is no
next"), before the ticket text pulled us back.

The ticket text is still real: `optional` is defined there as "does not need to be completed to
advance to the next stage."

**Where it lives, for the record:** on dev, `nextStage` is **per-objective** — it is in the objective
schema (`objectives_schema.lua`), and in `stages_and_objectives_test.lua` it sits inside the
`wait3secs` objective. Stages on dev are `{ objectives = {...} }` and nothing else.

**Verified fact, not a decision:** branching is available under every placement considered, because
an `ObjectiveCompleted` trigger can run a `ChangeStage` action. A stage is left by its gate, by an
explicit `ChangeStage`, by `Victory`, or by `Defeat`. Multi-exit is therefore *not* a
differentiator between placements, and any comparison claiming otherwise is wrong — I made that
mistake once already.

Dev's version additionally groups objectives implicitly by shared `nextStage` value and advances
when every member of that group completes. Given the line above, that grouping is a second way to
express something the trigger already expresses.

**efrec's direction, 2026-08-27 (stated as likely, not final):** move `nextStage` to the stage.
Branching paths use explicit `ChangeStage`. `optional` is the gate exemption and has exactly one
job in that context.

**Requirement, stated flat: all-of reduce is needed.** The gate is what provides it — every
non-optional objective in the stage must complete before `nextStage` fires. `settings.prerequisites`
cannot substitute (checked at dispatch, never revisited, so it deadlocks on unlucky completion
order), and `ObjectiveCompleted -> ChangeStage` is single-objective by construction.

The two compose, and the mechanism already exists on the recut. `objectives_loader.lua` derives
each objective's stage list from stage membership and applies it as `settings.stages` on synthesized
triggers and `stages` on managed metadata, so an objective stops evaluating once the mission leaves
the stages that list it. Canonical branching pattern:

```lua
Stages = { S1 = { objectives = { 'a', 'b', 'c' }, nextStage = 'S2' } }
-- 'c' is declared optional, and carries its own ObjectiveCompleted -> ChangeStage('S3')
```

- `c` completes first -> jump to `S3`; `a` and `b` stop evaluating, so the `S1` gate cannot fire
  later and drag the player back out of `S3`;
- `a` and `b` complete -> gate fires, `c` exempt as optional -> `S2`.

`optional` is load-bearing here: it is what lets the alternate exit exist without blocking the main
one.

**Fallback if the reviewer wants per-objective placement (efrec's design):** collapse `nextStage`
and `optional` into a single `progression` field whose *value* is the answer — a stage ID means
required-and-gates-there, absent means optional. Contradiction becomes structurally impossible
rather than something validation has to catch, which is strictly better than the two-field form I
had proposed for that branch.

`optional` stays a declared flag either way, because it cannot be derived from `nextStage == nil`:
in a terminal stage, or any stage exited by an explicit trigger, no objective carries a `nextStage`
and every one of them would render as a bonus. Under dev's placement it is display-only, and wants
one validation rule — an objective marked `optional` must not carry a `nextStage`.

The ✕ killed an *action* — a second verb duplicating `ChangeStage`. It did not kill the declaration
field, and it did not kill automatic advancement. Under either placement:

- The gate is evaluated **only when an objective completes**, never on stage entry. An
  objective-less stage never auto-advances, re-entering a finished stage does not bounce straight
  out, and an objective already satisfied when its stage opens still completes at that moment and
  advances as expected.
- No `AdvanceStage` action. Ever. `ChangeStage` is the only stage verb.

`settings.prerequisites` is not a substitute for the gate: it is checked at dispatch and never
revisited, so an all-of built from prerequisites deadlocks when the player finishes objectives in
an unlucky order. Re-evaluating on every completion is the gate's whole purpose.

## 4. What the workbook adds that we did not have

Four items, none ticketed. Listed so they are decisions rather than oversights.

| Item | Verdict |
|---|---|
| `ObjectiveSkipped` trigger — "objective has become obsolete" | **Take it, in the lifecycle PR.** It is the trigger half of `SetObjectiveCanceled` and is fifteen lines in the shape of `objective_failed.lua`; without it, cancel is a state nothing can observe. It ships beside its producer — nothing in the completed-and-failed PR can cancel an objective, so landing it there would be a trigger with no way to fire. |
| `ResetObjectives(stageID)` — "reinitialize all objectives on a stage as uncompleted" | **Defer, but it settles the open question.** Repeating objectives are an explicit author action, not an implicit consequence of stage re-entry. Re-entering a stage leaves completed objectives completed. That is now answered; the action itself can wait. |
| `ObjectiveProgress` trigger, "notify every N progress" | **Defer.** Free once the progress consolidation lands, but nobody asked and it wants a repeat policy. |
| `objectiveType` (the sheet's name for primary/optional/bonus) | **Keep our boolean.** The ticket says `optional` and splits it across two tickets; a boolean closes both. If it ever needs a third kind, the boolean widens without breaking the schema. |

`TeamWon` / `TeamLost` are worth one line: the sheet puts win conditions on *teams*, in a different
subject column, hooked to `GameOver`. It agrees with the reviewer that victory and defeat are not
downstream of objectives, and it says where they will eventually live instead.

## 5. The contract

What must ship, no matter what:

1. Add New Primary Objective
2. Add New Optional Objective
3. Mark Objective Hidden / Canceled / Active / Failed / Completed
4. Trigger — Objective Completed
5. Trigger — Objective Failed

Plus two constraints from review that are not negotiable:

- Stage entry enables and disables things "so the author doesn't have to worry about enabling and
  disabling everything themselves."
- "A successful and a failed objective both count as completed, otherwise failed objectives will
  softlock a mission. The only difference needs to come from which triggers get invoked."

Plus the thing that started this and is still unbuilt: objectives are invisible. `Spring.Echo` is
the entire presentation layer today.

## 6. The shallow implementation

### Data

```lua
Objectives = {
	objectiveID = {
		textKey   = 'build_3_bots',
		completes = { 'triggerA', 'triggerB' },  -- all-of; the box is done when every one has fired
		fails     = { 'triggerC' },              -- any-of; the box fails when any one has fired
		hidden    = false,                       -- authored state; revealed by an action
		-- optional: still open, see §10 -- inferable from the stage's box
		-- amount:   gone; the count lives on the trigger
		-- trigger:  gone; objectives reference triggers, they do not author them
	},
}

Stages = {
	stageID = {
		objectives = { 'objectiveID', ... },
		nextStage  = 'otherStageID',   -- MOVED from the objective; optional
	},
}
```

Runtime, per objective:

```
state    : 'dormant' | 'active' | 'canceled' | 'completed'
failed   : boolean   -- meaningful only when completed
hidden   : boolean
progress : number
```

`failed` is orthogonal to `completed`, which is the ticket's anti-softlock requirement stated as a
data shape. This reverses the exclusive `completed | failed` enum currently sitting in #8914.

### `objectives.lua`

- `changeStage(stageID)` — activate every objective the entered stage lists; return every other
  `active` objective to `dormant`. Progress is kept in both directions; a stage re-entered is a
  stage resumed. Terminal and canceled objectives are untouched. **Not** the universal
  auto-cancellation currently in `13c7123e22`.
- `completeObjective` / `failObjective` — both set `state = completed`; only `failed` differs; each
  notifies its own trigger type.
- `cancelObjective` — sets `canceled`, notifies `ObjectiveSkipped`.
- The gate — `tryAdvanceStage`, reworked from dev's per-objective form to the stage: on completion
  only, walk the current stage's objectives and advance to `stage.nextStage` once every
  non-`optional` one is complete. This is the all-of reduce. Re-evaluating on every completion is
  the whole point; it is what makes completion order irrelevant, and it is the one thing
  `settings.prerequisites` cannot do (checked at dispatch, never revisited, so an all-of built from
  prerequisites deadlocks on unlucky ordering).
- `addObjective` is deleted along with its action.
- Everything else (the setters, `incrementObjective`, `updateObjectiveProgress`,
  `isCompleteAtAmount`) survives from #8914 as written.

### Actions

**`AddObjective` is cut.** It had two jobs and has lost both: bringing an objective into play, which
stage entry now does, and setting `optional`, which is now declared. Nothing is left for it to do.
That also closes the `AddObjective` vs `SetObjectiveActive` overlap the ticket left open.

Mapped against the workbook's own action surface:

| Ours | Workbook | Note |
|---|---|---|
| `SetObjectiveActive` | `ShowObjective` | reveals a `hidden` objective, or returns a `canceled` one to play |
| `SetObjectiveHidden` | — | inverse of the above; not in the workbook |
| `SetObjectiveCanceled` | `CancelObjective` | "removal without triggering completion" |
| `SetObjectiveCompleted` | `CompleteObjective` | |
| `SetObjectiveFailed` | `FailObjective` | the workbook calls this "a fallback" for automatic failure detection |
| `UpdateObjective` | `UpdateObjective` ✓ | already shipped |
| `ChangeStage` | `ChangeStage` ✓ | already shipped |
| — | `ResetObjectives(stageID)` | deferred (§4) |

One naming collision worth a decision: the workbook calls the reveal `ShowObjective`, which is a
better name for what it does now that activation is automatic — "show" is exactly the remaining job.
Against that, `Set*` is the convention efrec set for the five state verbs, and this one does set
state (`hidden → visible`, `canceled → active`). Keeping `SetObjectiveActive` for consistency;
flagging it because the workbook's name is the designer's.

`optional` lives on the **declaration** only. With automatic activation there is no action to pass
it to, and the ticket put it on the action because the action was the only way in — which is no
longer true.

### Triggers

`ObjectiveCompleted`, `ObjectiveFailed`, `ObjectiveSkipped`, each taking a **singular
`objectiveID`**. The `objectiveIDs` all-of / any-of lists in #8913 existed only to substitute for
stage advancement; they are cut, and `Types.ObjectiveIDs` with them.

### Validation

| Keep | Drop |
|---|---|
| stage → objective references exist | `validateStageExits` — reviewer rejected its premise outright |
| `amount = 0` only on statistics trigger types | "objective not listed in any stage" as an **error** → warning: with `AddObjective` gone, an unlisted objective is reachable only via `SetObjectiveActive`, which is unusual but legal |
| `ObjectiveID` parameter type | `ObjectiveIDs` parameter type |
| stage reachability, extended to count `nextStage` targets | |

Add: `nextStage` names a real stage.

### Presentation

`SetGameRulesParam('missionObjectives', Json.encode(rows))` plus a numeric
`missionObjectivesVersion` to poll — the same shape as `pveBossInfo` in the raptor and scav
spawners. Rules params rather than `SendToUnsynced` so late joiners, `/luaui reload`, replays and
spectators need no resync protocol.

Row: `{ id, state, failed, optional, progress, amount, textKey }`.

**Hidden filtering is publisher-side**: publish a row iff `state ~= 'dormant'` and (`not hidden` or
`state == 'completed'`). Widgets are user-replaceable by design, so unsynced must never hold what
the player should not see.

Widget stub `gui_mission_objectives.lua` renders the list: progress over amount, optional tagged,
completed marked with success or failure, canceled greyed out. It replaces the `Spring.Echo` calls,
which stay as a debug fallback.

Rule for anything added later: state a late-arriving consumer must still render → rules param; a
moment that changes nothing after it passes → `SendToUnsynced` message.

## 7. What not to build

Named so they stay dead: automatic failure detection for unsatisfiable triggers (the sheet itself
calls the action "a fallback" for it, and the analysis is not worth it at ten triggers); victory or
defeat inferred from objectives; `AdvanceStage`; softlock proofs of any kind; a hidden-objective
pathway; repeating objectives; `objectiveType` as an enum; per-objective `nextStage`.

## 8. PR split

### #8913 — recut

**All four commits stay.** An earlier draft of this section said to drop `bb919f3747`; that was
written before reading it. What it removes is not the design being restored:

- **its `nextStage` / `tryAdvanceStage` removal may need splitting out and dropping** *(pending
  §3)* — that is the half whose premise the reviewer rejected. Requires rewriting history below the
  merge, so it does not happen without an explicit go-ahead;
- it also removes the old scattered counters (`managedObjMetadata._count`, `.amount`, `.stages`,
  `maxRepeats = amount - 1`), which `0977aebb9c` replaces two commits later. Restoring them undoes
  the consolidation.

The gate cannot live here in any case: it needs `optional` to know what blocks, and `optional` is
tickets 1–2. Stage-level `nextStage` is new code in the lifecycle PR, not a revert here.
`bb919f3747` keeps its purely-subtractive framing, which is what makes `0977aebb9c` readable.

Two changes on top, then:

1. **Singular `objectiveID`.** `objectiveIDs` never shipped, so this folds into `0977aebb9c` by
   fixup rather than landing as an add-then-change pair. Touches both trigger files,
   `notifyObjectiveCompleted` / `notifyObjectiveFailed` in `objectives.lua`, `Types.ObjectiveIDs`
   and its validator, `stages_and_objectives_test.lua`, and three specs. Note `winOnObjectives` in
   the test mission is an all-of that existed only to fake advancement; it needs rewriting, not
   translating.
2. **Retitle** off "nonlinear stages" — nothing left in it concerns stage topology.

Tickets 4 and 5.

### Syncing to current `mission-api/dev`

The larger job. Both PRs are based on `a67c256717`; dev is at `caaa9280b7` — 30+ commits including
a merge of master, `Stylua pass on mission api + specs (#8908)`, and a `validation.lua` refactor.

Classified by normalising whitespace and quote style:

| File | Dev's change | Resolution |
|---|---|---|
| `objectives.lua` | formatting only | take ours, run stylua |
| `objectives_loader.lua` | formatting only | take ours, run stylua |
| `objectives_schema.lua` | formatting only | take ours, run stylua |
| `triggers_loader.lua` | formatting only | take ours, run stylua |
| `parameter_types.lua` | added `Command`, expanded `Facing` | our diff becomes empty once `ObjectiveIDs` goes |
| `api_missions_triggers.lua` | added `gadget:UnitCommand` + dispatch | different region, should auto-merge |
| `validation.lua` | real refactor: `requiresOneOf`, `validateNumberArrayCurried` nameKeys, the unit/feature-name recording rewrite | the only file needing judgment |

**Merge dev in; do not rebase.** Four commits replayed against a whole-file reformat means resolving
the same formatting conflict four times. `mission-api/dev` already absorbs master by merge.

**The format constraint has inverted.** #8908 landed, so dev is formatted and these branches are
not. Dev's `.styluaignore` exempts `luarules/mission_api/triggers/`, `luarules/mission_api/actions/`
and `singleplayer/mission-api-tests/` — exactly the hand-styled files, which keep the house style.
Everything else touched, **specs included**, must be stylua-formatted.

Incidentally: dev's `construction_progress_spec.lua` now reads `callins.UnitBuildStepPost`, so the
16 pre-existing spec errors clear with the sync.

### #8914 — rebuild

`failed` as an orthogonal flag; `optional` and `hidden` on the declaration; the five setters, with
`AddObjective` deleted; `ObjectiveSkipped` beside `SetObjectiveCanceled`; stage entry activates and
deactivates; the validation trim. Gate work: `nextStage` moves from the objective to the stage and
`tryAdvanceStage` reduces over the stage's non-`optional` objectives. Rebases onto the recut
afterward, which it needs regardless. Tickets 1, 2 and 3.

One thing in here departs from dev and must be called out in the PR body rather than left for the
reviewer to find: `AddObjective` is deleted outright (§6).

### #8915 — new

Rules-param publisher and the widget stub. The only part the workbook records as having no coverage
whatsoever, and a listed product requirement rather than a ticket, so it lands on its own schedule.


## 9. Decisions log

Only efrec decides. Entries here are stated calls, dated. Analysis lives elsewhere in this
document and is not a decision until it appears in this list.

**2026-08-27**

- **Counts reconsolidate on triggers.** `statistics.lua` already implements the whole counter
  trigger-side — milestone repeats via `(repeatCount + 1) * quantity`, and the `quantity == 0`
  reduce-to-zero case. `objective.amount` / `objective.progress` are a parallel reimplementation of
  it, which is the workbook's own "separate managed path" defect. The count belongs on the trigger
  for every trigger type; an objective reads its trigger's count for display.
  **This reverses the direction of the consolidation already committed in #8913**, which moved
  counts onto `objective.progress`.
- **Stages list their bare triggers.** Stages already scope triggers, but by the trigger declaring
  `settings.stages` rather than the stage naming it. Stages gain a trigger list so membership is
  declared from one end for both kinds.
- **Objectives are player-facing only.** Everything that is not something a player would call an
  objective is a bare trigger. Music cues, ambient events and other script logic lose nothing:
  counting is trigger-side, scoping is trigger-side, observation is `settings.prerequisites`. The
  only genuinely objective-shaped capability they give up is failure-as-a-state, which is
  meaningless for a thing the player never sees.

- **Objectives take `completes` and `fails`.** An objective is a box on triggers: an **all-of
  reduce over `completes`** and an **any-of reduce over `fails`**, both over an unsorted collection.
  Unsorted is load-bearing — all-of and any-of are order-independent by construction, which is
  precisely why `settings.prerequisites` cannot stand in for either (dispatch-time, never
  revisited).

  The reduce is over trigger **firings**, not trigger conditions. Firings are monotonic, so the box
  latches; conditions are not (`statistics.lua` re-fires `quantity == 0` every time a count returns
  to zero). The code already latches — `incrementObjective` and `updateObjectiveProgress` both bail
  on `if objective.completed`. Saying "firings" is what makes model and implementation agree.

  Progress is distance-to-satisfying the reduce: the trigger's own count for a singleton with
  `quantity`, n-of-m fired for a set. One quantity at two arities.

  What this displaces:
  - the inline `objective.trigger` field — objectives now *reference* named triggers;
  - the `__objective_<id>` / `__updateObjective_<id>` synthesis in `objectives_loader.lua`;
  - the managed-vs-synthesized split, and with it the `Quantity`-parameter inference that selects
    between them (§10) — both paths collapse to "the trigger fired";
  - `SetObjectiveFailed` as the load-bearing failure route; it demotes to the workbook's stated
    "fallback", since failure is normally a trigger listed in `fails`.

  **First to latch wins.** If `fails` fires after `completes` has latched, the box is already
  completed and stays completed, and the reverse likewise. This is not a separate rule — it is what
  latching means, and the reduce is over firings precisely so that it holds.

  **Re-arming is `ResetObjectives(stageID)`.** Repeating is an explicit author action, never an
  implicit consequence of stage re-entry or of a trigger re-firing. Settled at the workbook ingest
  (§1) and not open.

**Undecided, open**

Before adding anything to this list, read §9 above and §1. Items have been added here that were
already answered — "first to latch" and re-arming both got reopened after being settled. An item
belongs here only if efrec has not ruled on it and it is not entailed by something already decided.

- **Authoring ergonomics of the reference form.** Today an author writes the trigger inline inside
  the objective, which is short for the common one-trigger case. Referencing a named trigger is more
  verbose. Keeping the inline form as sugar that synthesises a trigger and puts its ID in
  `completes` would preserve brevity but retains the synthesis machinery this decision removes.

- `maxRepeats` semantics: `maxRepeats = N` currently fires **N+1** times, because
  `isTriggerValid` tests `repeatCount > maxRepeats` before `activateTrigger` increments it. Every
  test mission that writes `maxRepeats = 5` gets six firings. Whether to patch N-1 to N, or rename
  the setting so the name matches the behaviour, is open.
- Where `progression` lives — see §10.

## 10. Inferred properties

A bin, kept deliberately. Computing a property is fine; the test is whether the **authored** set
stays consistent, small, and made of things a mission author wants to see, rather than bookkeeping.
Anything in this list must stay computed and must not migrate into the authoring surface.

| Inferred property | Computed from | Where |
|---|---|---|
| an objective's stage scope | stage membership, mapped to `settings.stages` / managed `stages` | `objectives_loader.lua` |
| managed vs synthesized path | whether the trigger type declares a `Quantity` parameter | `objectives_loader.lua` |
| "never shown" | declared `hidden` and no action in the mission reveals it | validation, same whole-mission action scan as reachability |
| stage reachability | no `ChangeStage` action targets it and it is not the initial stage | `validateStageReachability` |
| an objective's progress and completion | its trigger's count, once counts are trigger-side | runtime |
| `trigger.triggered`, `trigger.repeatCount` | runtime bookkeeping | runtime |
| an objective's requiredness | its trigger carries `progression` to the stage's target, **or** an `ObjectiveFailed` trigger naming it runs `Defeat` (one hop only) | load time |
| an objective being an alternative route | its trigger's `progression` target differs from the stage's other gating triggers | load time |
| an objective being bonus | neither of the above | load time |

### `progression`, re-evaluated

The fold was proposed to stop `nextStage` and `optional` contradicting each other on the same
object. The decisions above dissolve that motivation rather than satisfying it: `optional` is a
display badge on a player-facing record, and gate membership is control flow. They are now on
different objects and cannot contradict by construction, so there is nothing left to fold.

What survives is the placement question, and the decisions push it off the objective entirely. If
objectives are purely player-facing, putting `progression` on one repeats the exact error that
`optional`-drives-the-gate made — control flow read off a display record. The trigger is now
unambiguously the logic layer: it holds the condition, the count, the actions and the stage scope.
A trigger carrying `progression = 'stage2'` participates in the all-of reduce for that transition,
and triggers sharing a target form the group.

That is dev's grouping mechanism, on the object it should have been on. Multi-target falls out for
free, and `stage.nextStage` may not be needed at all.

Open, not decided: `progression` on the trigger, versus the stage naming its gating members
directly out of the trigger list it now carries.


### `optional`, tweezed

Analysis, not decided.

`optional` as an authored field is a **mechanical claim the author should not be making** — it
asserts something about the gate that the gate does not read. Both senses of it derive from the
same structure. Partition a stage's gating triggers by `progression` target:

- one partition -> linear; every objective in it is required;
- several partitions -> branching; each partition is a route;
- triggers with no `progression` -> their objectives are bonus.

**The derivation yields three renderings, not two, and `optional` was flattening one of them.** A
branch is not optionality, it is a **choice**. "Destroy the bridge or escort the convoy" shown as
two optional objectives is a lie — the player must do one. Shown as a choice group it is the truth.
A boolean cannot express that.

Requiredness therefore has two structural sources, not one: the objective gates advancement, or its
failure ends the mission. The second is what saves "survive the assault", which gates nothing and
would otherwise infer as bonus. One hop is enough — an `ObjectiveFailed` trigger naming it with a
`Defeat` action — reusing the actions scan `validateStageReachability` already performs. Transitive
reachability would catch more and is the softlock-proof territory already ruled out (§7).

**Residue that is genuinely the author's:** emphasis. "This is the one that matters," told to the
player, with no mechanical claim behind it. Real, worth keeping, and honest only if it is named as
presentation rather than dressed as structure.


## 11. Presentation

Planned 2026-08-28. FlowUI only, no RmlUI. Stubs wherever a stub will do, which is nearly
everywhere: the point of this slice is that every channel exists and is exercised end to end, not
that any of it is finished.

### Channels, verified

| Direction | Mechanism | Precedent |
|---|---|---|
| synced -> unsynced, **state** | game rules params carrying JSON | `pveBossInfo` in the raptor/scav spawners |
| synced -> unsynced, **per-audience state** | `Spring.SetPlayerRulesParam(playerID, ...)` / `SetTeamRulesParam`, with `losAccess` | engine: `LuaSyncedCtrl.cpp:1654` |
| synced -> unsynced, **moments** | `SendToUnsynced` + `gadgetHandler:AddSyncAction(name, fn)` | `api_music.lua`, `cmd_alliance_break.lua` |
| unsynced -> synced | `Spring.SendLuaRulesMsg(msg)` -> `gadget:RecvLuaMsg(msg, playerID)` | `cmd_clone_tool.lua`, `cmd_feature_placer.lua` |

Routing rule, unchanged: state a late-arriving consumer must still render -> rules param; a moment
that changes nothing after it passes -> `SendToUnsynced`.

### Audience filter (stub)

`SendToUnsynced` broadcasts to every client, so audience cannot be enforced on that path — a
replaced widget sees everything. Rules params can be enforced: the engine has
`RULESPARAMLOS_PRIVATE` through `RULESPARAMLOS_PUBLIC` (`LuaRulesParams.h:14`), so
`SetPlayerRulesParam(playerID, name, value, { private = true })` is readable by that player only.
That is the same publisher-side principle already settled for `hidden`.

The stub is one function and one field:

```lua
-- audience = nil | 'all' | { playerIDs = { ... } } | { teamIDs = { ... } }
local function resolveAudience(audience)   -- returns a list of playerIDs, or nil for everyone
	return nil                             -- STUB: everyone, always
end
```

Every presentation action takes an optional `audience` parameter, every publish goes through one
`publish(name, value, audience)` that branches to `SetGameRulesParam` when the audience is everyone
and `SetPlayerRulesParam` per player otherwise. Coop fills in `resolveAudience` and nothing else
moves.

### Resolver and i18n (central)

`textKey` has **no resolver today** — it is declared, validated non-empty, stored, and printed raw
by `Spring.Echo`. Nothing calls `BAR.I18N` on it anywhere.

Two namespaces, kept apart:

- **`ui.mission.*`** — the widgets' own chrome ("Objectives", "Completed", "Failed"). Ships with the
  game, lives in `language/en/interface.json`, syncs to Transifex (`language/transifex.yml`) and
  comes back in the nine other locales.
- **Mission-authored text** — an objective's `textKey`. Per-mission content that travels with the
  mission, and must NOT land in the game's interface file.

One resolver, unsynced-side, used by every mission widget:

```lua
local function resolveText(textKey, params)
	return BAR.I18N(textKey, params) or textKey   -- STUB: falls back to the raw key
end
```

Falling back to the key means everything renders on day one and the mission-i18n question does not
block the slice. **Open: where mission-authored text lives.** Not answered here.

### Widgets

`gui_mission_info.lua` is already FlowUI (`WG.FlowUI.Draw.Element` / `.Scroller` / `RectRound`,
`elementCorner`, `clampedOpacity`) and already renders the shape needed — headers, lines, scroller,
top-bar registration, pause handling. Its only scenario-specific part is the data source: base64
modoption -> `scenarioid` -> scan `singleplayer/scenarios/*.lua`. Reuse the renderer rather than
writing a second panel that looks the same.

Rename `ui.missioninfo.*` -> `ui.briefings.*` **in this slice**. 13 references in
`gui_mission_info.lua`, 3 in `gui_top_bar.lua`, one block in `language/en/interface.json`. No other
locale has translated the key yet, so the rename is free right now and stops being free once
Transifex takes it as source.

### Ending an interaction (unsynced -> synced)

Needed for dismissing a briefing, answering a prompt, choosing a branch. Synced holds the pending
interaction; unsynced answers it; synced closes it.

```lua
-- unsynced
Spring.SendLuaRulesMsg("mission:ack:" .. interactionID)

-- synced, in api_missions.lua
function gadget:RecvLuaMsg(msg, playerID)
	-- STUB: parse, check playerID is in the interaction's audience, resolve, clear
end
```

`RecvLuaMsg` is unauthenticated — any client can send any string — so synced must check that
`playerID` is actually in that interaction's audience before acting. That check is the one part of
this that should not be stubbed.

### What ships real vs stubbed

| Real | Stubbed |
|---|---|
| the rules-param publisher and its version counter | `resolveAudience` returns everyone |
| `AddSyncAction` registration and one message type | audience parameter accepted, not enforced |
| `RecvLuaMsg` parsing **and the playerID/audience check** | one interaction type (`ack`), no prompts or choices |
| the objectives panel rendering live state | no badging (needs `optional`, still open in §10) |
| `resolveText` called everywhere text is drawn | it falls back to the raw key |
| the `ui.briefings.*` rename | mission-authored i18n location unresolved |

`SendMessage` is the honest measure of the slice. It is currently
`actionFunction = Spring.Echo` — no unsynced path, no audience, no resolver. When it goes through
the publisher, the audience stub and the resolver, all three channels are exercised by one shipped
action.


### The message inventory

Four channels, not three. `sounds.lua` already uses the fourth: the synced LuaRules state is given
`LuaUnsyncedCtrl` as well as the synced tables (`LuaHandleSynced.cpp:507`), so synced code can call
`Spring.PlaySoundFile` and `Spring.SendLuaUIMsg` directly. Because synced runs on every client,
those are **inherently broadcast and cannot be audience-filtered**. That is the constraint which
decides what goes where.

**A. Game/player rules params — state a late consumer must re-render**

| Param | Payload | Driven by |
|---|---|---|
| `missionObjectives` + `missionObjectivesVersion` | JSON rows `{ id, textKey, completed, failed, progress, amount }`, `hidden` filtered out publisher-side | every objective state change |
| `missionStage` | current stage ID | `ChangeStage` |
| `missionInteraction` | the open interaction, if any: `{ id, kind, textKey, options }` | a prompt being raised |

An open prompt is **state**, not a moment: reload the UI mid-prompt and it has to come back. Only
its dismissal is a moment. All three go through `publish(name, value, audience)`, which is
`SetGameRulesParam` for everyone and `SetPlayerRulesParam(playerID, ..., { private = true })`
otherwise — the only audience-enforceable path there is.

**B. `SendToUnsynced` + `AddSyncAction` — moments**

| Action name | Payload | Driven by |
|---|---|---|
| `MissionMessage` | text key, params | `SendMessage` |
| `MissionEffect` | effect id, position | flashes, camera nudges, pings |

Music is **not** here: `PlayMusic` already delegates to `GG["music"].GadgetPlayMusicTrack`, and
`api_music.lua` runs its own `AddSyncAction("GadgetPlayMusicTrack", ...)`. Do not duplicate it.

This channel broadcasts, so audience carried in the payload could only be checked client-side and a
replaced widget would ignore it. **Anything audience-sensitive must not use this channel** — it
goes in A instead.

**C. Unsynced callouts from synced — broadcast, already in use**

`Spring.PlaySoundFile` and `Spring.SendLuaUIMsg("suspendNotifications " .. length)` in `sounds.lua`.
Correct for genuinely global effects, unusable for anything with an audience. Audience-filtered
sound would have to move to A and be played by the widget.

**D. `SendLuaRulesMsg` -> `RecvLuaMsg` — ending an interaction**

| Message | Meaning |
|---|---|
| `mission:ack:<interactionID>` | dismissed or acknowledged |
| `mission:choose:<interactionID>:<optionIndex>` | a choice answered |

Both arrive with `playerID`. Synced clears the corresponding `missionInteraction` param and runs
whatever the interaction was waiting on. The playerID-is-in-the-audience check happens here and is
the one thing in the slice that is not stubbed.
