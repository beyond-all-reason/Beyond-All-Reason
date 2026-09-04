---
--- Stages and objectives test mission.
---

---
--- Expected in the infolog, in this order (grep "Stage set to|Objective updated|MissionTest"):
---   Stage set to: gate
---   quick completed at 2 s and bonus at 3 s, with no stage change
---   Stage set to: observer, then slow completed with active: false (slow at 5 s
---     finished the all-of pair; leaving gate deactivated it)
---   Stage set to: failure, then route completed (route's observer changed stage
---     before the gate could move to decoy; "Stage set to: decoy" never appears)
---   MissionTest: ObjectiveFailed fired for doomed, then Stage set to: cancel, then
---     doomed completed (failed) (observers run first; the failure advanced the gate)
---   MissionTest: ObjectiveCanceled fired for flaky, then flaky (canceled) with active: false
---   partner completed at 12 s with no stage change (flaky holds the gate)
---   Stage set to: activation, then flaky completed without (canceled)
---   lingering with active: true (entry activated it)
---   count with active: false and progress: nil (two probes spawned; counted, not evaluated)
---   future with active: false (activation denied outside its stage)
---   count with active: true (hidden), then count shown
---   Stage set to: final, then count completed with progress: 3 (the third probe)
---   future with active: true, lingering with active: false (entry and exit)
---   MissionTest: complete, then future completed, then the game ends
---

local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local initialStage = 'gate'
local stages = {
	gate       = { objectives = { 'quick', 'slow', 'bonus' } },
	observer   = { objectives = { 'route' } },
	decoy      = { objectives = {} },
	failure    = { objectives = { 'doomed' } },
	cancel     = { objectives = { 'flaky', 'partner' } },
	activation = { objectives = { 'lingering' } },
	final      = { objectives = { 'future' } },
}

local objectives = {

	-- Stage gate: quick and slow share a nextStage, so the stage holds until both
	-- complete; bonus has none and moves nothing.
	quick = {
		textKey = 'gate_quick',
		trigger = { type = triggerTypes.TimeElapsed, parameters = { seconds = 2 } },
		nextStage = 'observer',
	},
	slow = {
		textKey = 'gate_slow',
		trigger = { type = triggerTypes.TimeElapsed, parameters = { seconds = 5 } },
		nextStage = 'observer',
	},
	bonus = {
		textKey = 'gate_bonus',
		trigger = { type = triggerTypes.TimeElapsed, parameters = { seconds = 3 } },
	},

	-- Stage observer: route's nextStage is the decoy, but its ObjectiveCompleted
	-- trigger changes to failure first, and the gate stands down.
	route = {
		textKey = 'observer_route',
		trigger = { type = triggerTypes.TimeElapsed, parameters = { seconds = 7 } },
		nextStage = 'decoy',
	},

	-- Stage failure: failed by action, and the failure counts for the gate.
	doomed = {
		textKey = 'failure_doomed',
		nextStage = 'cancel',
	},

	-- Stage cancel: partner completes on its own; flaky is canceled, which holds
	-- the gate, then completed by action, which clears the cancel and advances.
	flaky = {
		textKey = 'cancel_flaky',
		nextStage = 'activation',
	},
	partner = {
		textKey = 'cancel_partner',
		trigger = { type = triggerTypes.TimeElapsed, parameters = { seconds = 12 } },
		nextStage = 'activation',
	},

	-- Stage activation: listed here, so entry activates it and exit deactivates it.
	lingering = {
		textKey = 'activation_lingering',
	},

	-- Listed in no stage and hidden: it counts spawned probes while inactive and
	-- completes only once activated. Its ObjectiveCompleted trigger moves on.
	count = {
		textKey = 'activation_count',
		amount = 2,
		hidden = true,
		trigger = { type = triggerTypes.UnitsOwned, parameters = { unitName = 'probe', teamID = 0 } },
	},

	-- Listed only in the final stage: activating it from another stage is denied.
	future = {
		textKey = 'final_future',
	},
}

local triggers = {

	-- Stage observer: route completes at 7 s.
	routeCompleted = {
		type = triggerTypes.ObjectiveCompleted,
		parameters = { objectiveID = 'route' },
		actions = { 'changeToFailure' },
	},

	-- Stage failure.
	failDoomed = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'failure' } },
		parameters = { seconds = 9 },
		actions = { 'failDoomed' },
	},
	doomedFailed = {
		type = triggerTypes.ObjectiveFailed,
		parameters = { objectiveID = 'doomed' },
		actions = { 'reportDoomedFailed' },
	},

	-- Stage cancel: partner completes at 12 s.
	cancelFlaky = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'cancel' } },
		parameters = { seconds = 11 },
		actions = { 'cancelFlaky' },
	},
	flakyCanceled = {
		type = triggerTypes.ObjectiveCanceled,
		parameters = { objectiveID = 'flaky' },
		actions = { 'reportFlakyCanceled' },
	},
	completeFlaky = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'cancel' } },
		parameters = { seconds = 14 },
		actions = { 'completeFlaky' },
	},

	-- Stage activation.
	probeLingering = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'activation' } },
		parameters = { seconds = 15 },
		actions = { 'probeLingering' },
	},
	spawnTwoProbes = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'activation' } },
		parameters = { seconds = 16 },
		actions = { 'spawnTwoProbes' },
	},
	probeBeforeActivation = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'activation' } },
		parameters = { seconds = 17 },
		actions = { 'probeCount', 'activateFuture' },
	},
	activateCount = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'activation' } },
		parameters = { seconds = 18 },
		actions = { 'activateCount', 'showCount' },
	},
	spawnThirdProbe = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'activation' } },
		parameters = { seconds = 20 },
		actions = { 'spawnOneProbe' },
	},
	countCompleted = {
		type = triggerTypes.ObjectiveCompleted,
		parameters = { objectiveID = 'count' },
		actions = { 'changeToFinal' },
	},

	-- Stage final.
	probeAfterEntry = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'final' } },
		parameters = { seconds = 21 },
		actions = { 'probeFuture', 'probeLingering' },
	},
	completeFuture = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'final' } },
		parameters = { seconds = 22 },
		actions = { 'completeFuture' },
	},
	futureCompleted = {
		type = triggerTypes.ObjectiveCompleted,
		parameters = { objectiveID = 'future' },
		actions = { 'reportComplete', 'victory' },
	},
}

local actions = {

	changeToFailure = {
		type = actionTypes.ChangeStage,
		parameters = { stageID = 'failure' },
	},
	changeToFinal = {
		type = actionTypes.ChangeStage,
		parameters = { stageID = 'final' },
	},

	failDoomed = {
		type = actionTypes.FailObjective,
		parameters = { objectiveID = 'doomed' },
	},
	cancelFlaky = {
		type = actionTypes.CancelObjective,
		parameters = { objectiveID = 'flaky' },
	},
	completeFlaky = {
		type = actionTypes.CompleteObjective,
		parameters = { objectiveID = 'flaky' },
	},
	completeFuture = {
		type = actionTypes.CompleteObjective,
		parameters = { objectiveID = 'future' },
	},
	activateCount = {
		type = actionTypes.ActivateObjective,
		parameters = { objectiveID = 'count' },
	},
	showCount = {
		type = actionTypes.ShowObjective,
		parameters = { objectiveID = 'count' },
	},
	activateFuture = {
		type = actionTypes.ActivateObjective,
		parameters = { objectiveID = 'future' },
	},

	-- Probes: they print the objective and change nothing it does not already have.
	probeLingering = {
		type = actionTypes.ShowObjective,
		parameters = { objectiveID = 'lingering' },
	},
	probeFuture = {
		type = actionTypes.ShowObjective,
		parameters = { objectiveID = 'future' },
	},
	probeCount = {
		type = actionTypes.HideObjective,
		parameters = { objectiveID = 'count' },
	},

	spawnTwoProbes = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', x = 1800, z = 1800, team = 0, unitName = 'probe', quantity = 2 },
			},
		},
	},
	spawnOneProbe = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', x = 1800, z = 1800, team = 0, unitName = 'probe', quantity = 1 },
			},
		},
	},

	reportDoomedFailed = {
		type = actionTypes.SendMessage,
		parameters = { message = 'MissionTest: ObjectiveFailed fired for doomed' },
	},
	reportFlakyCanceled = {
		type = actionTypes.SendMessage,
		parameters = { message = 'MissionTest: ObjectiveCanceled fired for flaky' },
	},
	reportComplete = {
		type = actionTypes.SendMessage,
		parameters = { message = 'MissionTest: complete' },
	},
	victory = {
		type = actionTypes.Victory,
		parameters = { allyTeamIDs = { 0 } },
	},
}

return {
	InitialStage = initialStage,
	Stages = stages,
	Objectives = objectives,
	Triggers = triggers,
	Actions = actions,
}
