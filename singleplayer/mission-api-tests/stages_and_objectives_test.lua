---
--- Stages and objectives test mission.
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

	-- Stage gate: quick and slow share a nextStage
	quick = {
		textKey = 'gate_quick',
		trigger = { type = triggerTypes.TimeElapsed, parameters = { seconds = 2 } },
		nextStage = 'observer',
		onActivated = 'quickActivated',
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

	-- Stage observer: route's nextStage is the decoy, but its onCompleted trigger
	-- changes to failure first, so the gate stands down.
	route = {
		textKey = 'observer_route',
		trigger = { type = triggerTypes.TimeElapsed, parameters = { seconds = 7 } },
		nextStage = 'decoy',
		onCompleted = 'routeCompleted',
	},

	-- Stage failure: failed by action, and the failure counts for the gate.
	doomed = {
		textKey = 'failure_doomed',
		nextStage = 'cancel',
		onFailed = 'doomedFailed',
	},

	-- Stage cancel: partner completes on its own; flaky is canceled, which holds
	-- the gate, then completed by action, which clears the cancel and advances.
	flaky = {
		textKey = 'cancel_flaky',
		nextStage = 'activation',
		onCanceled = 'flakyCanceled',
	},
	partner = {
		textKey = 'cancel_partner',
		trigger = { type = triggerTypes.TimeElapsed, parameters = { seconds = 12 } },
		nextStage = 'activation',
	},

	-- Stage activation: listed here, so entry activates it and exit cancels it.
	lingering = {
		textKey = 'activation_lingering',
		onCanceled = 'lingeringCanceled',
	},

	-- Listed in no stage and hidden: it counts spawned probes while inactive and
	-- evaluates only once activated. Its onCompleted trigger moves on.
	count = {
		textKey = 'activation_count',
		amount = 3,
		hidden = true,
		trigger = { type = triggerTypes.UnitsOwned, parameters = { unitName = 'probe', teamID = 0 } },
		onActivated = 'countActivated',
		onProgress = 'countProgressed',
		onCompleted = 'countCompleted',
	},

	-- Listed only in the final stage: activating it from another stage is denied.
	future = {
		textKey = 'final_future',
		onCompleted = 'futureCompleted',
	},
}

local triggers = {

	-- Stage gate.
	quickActivated = {
		type = triggerTypes.Event,
		actions = { 'reportQuickActivated' },
	},

	-- Stage observer: route completes at 7 s.
	routeCompleted = {
		type = triggerTypes.Event,
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
		type = triggerTypes.Event,
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
		type = triggerTypes.Event,
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
	spawnFirstProbe = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'activation' } },
		parameters = { seconds = 16 },
		actions = { 'spawnOneProbe' },
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
	countActivated = {
		type = triggerTypes.Event,
		actions = { 'reportCountActivated' },
	},
	spawnSecondProbe = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'activation' } },
		parameters = { seconds = 19 },
		actions = { 'spawnOneProbe' },
	},
	countProgressed = {
		type = triggerTypes.Event,
		actions = { 'reportCountProgressed' },
	},
	spawnThirdProbe = {
		type = triggerTypes.TimeElapsed,
		settings = { stages = { 'activation' } },
		parameters = { seconds = 20 },
		actions = { 'spawnOneProbe' },
	},
	countCompleted = {
		type = triggerTypes.Event,
		actions = { 'changeToFinal' },
	},
	lingeringCanceled = {
		type = triggerTypes.Event,
		actions = { 'reportLingeringCanceled' },
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
		type = triggerTypes.Event,
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

	spawnOneProbe = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', x = 1800, z = 1800, team = 0, unitName = 'probe', quantity = 1 },
			},
		},
	},

	reportQuickActivated = {
		type = actionTypes.SendMessage,
		parameters = { message = 'MissionTest: quick activated' },
	},
	reportDoomedFailed = {
		type = actionTypes.SendMessage,
		parameters = { message = 'MissionTest: doomed failed' },
	},
	reportFlakyCanceled = {
		type = actionTypes.SendMessage,
		parameters = { message = 'MissionTest: flaky canceled' },
	},
	reportLingeringCanceled = {
		type = actionTypes.SendMessage,
		parameters = { message = 'MissionTest: lingering canceled on exit' },
	},
	reportCountActivated = {
		type = actionTypes.SendMessage,
		parameters = { message = 'MissionTest: count activated' },
	},
	reportCountProgressed = {
		type = actionTypes.SendMessage,
		parameters = { message = 'MissionTest: count progressed' },
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
