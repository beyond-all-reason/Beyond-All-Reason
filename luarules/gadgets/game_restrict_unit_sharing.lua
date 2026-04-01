local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Restrict Unit Sharing',
		desc    = 'Stun/debuff economy and builder units when transferred to ally when modoption enabled.',
		author  = 'RebelNode',
		date    = 'January 2026',
		license = 'GNU GPL, v2 or later',
		layer   = -2, -- before unit_healthbars_widget_forwarding so that AllowFeatureBuildStep will prevent reclaim bar from showing
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if not Spring.GetModOptions().easytax then
	return false
end

local DEBUFF_FRAMES = 30 * 30 -- 30 seconds at 30 game frames per second
local debuffedUnits = {} -- unitID -> { expireFrame, buildSpeed }

-- gather all economy/builder units
local ecoUnits = {}
local builderUnits = {}
-- local commanders = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local group = unitDef.customParams.unitgroup
	if group then
		if group == "builder" or group == "buildert2" or group == "buildert3" then
			if unitDef.speed > 0 then -- not factory or conturret
				builderUnits[unitDefID] = true
			end
			ecoUnits[unitDefID] = true
		elseif group == "energy" or group == "metal" then
			ecoUnits[unitDefID] = true
		end
	end
	-- if unitDef.customParams.iscommander then
	-- 	commanders[unitDefID] = true
	-- end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if (capture) and (not Spring.AreTeamsAllied(fromTeamID, toTeamID)) then
		return true
	end
	beingBuilt, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
	if beingBuilt and buildProgress > 0 and next(Spring.GetPlayerList(fromTeamID)) ~= nil then
		return false -- Sharing partly built nanoframes is not allowed because letting it decay bypasses taxation and letting it build runs out the debuff early. Also if you can't assist ally build the unit could get stuck in factory.
	end
	-- if commanders[unitDefID] then
	-- 	if next(Spring.GetPlayerList(fromTeamID)) == nil then -- There are no players in the fromTeam, therefore this is /take.
	-- 		return true
	-- 	end
	-- 	return false
	-- end
	if builderUnits[unitDefID] then
		local unitDef = UnitDefs[unitDefID]
		local startFrame = Spring.GetGameFrame()
		local expireFrame = startFrame + DEBUFF_FRAMES
		Spring.SetUnitBuildSpeed(unitID, 0.01, nil, 0.01)
		debuffedUnits[unitID] = {
			expireFrame  = expireFrame,
			buildSpeed   = unitDef.buildSpeed or 0,
			reclaimSpeed = unitDef.reclaimSpeed or unitDef.buildSpeed or 0,
		}
		SendToUnsynced("unitBuildspeedDebuff", unitID, startFrame, expireFrame)
	elseif ecoUnits[unitDefID] then
		local _, maxHealth = Spring.GetUnitHealth(unitID)
		Spring.AddUnitDamage(unitID, maxHealth * 5, 30) -- Stun for 30 seconds.
	end
	return true
end

-- Spring.SetUnitBuildSpeed does not affect features so also prevent feature reclaim/resurrect on debuffed builders using AllowFeatureBuildStep.
function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if debuffedUnits[builderID] then
		return false
	end
	return true
end

function gadget:GameFrame(n)
	for unitID, data in pairs(debuffedUnits) do
		if n >= data.expireFrame then
			Spring.SetUnitBuildSpeed(unitID, data.buildSpeed, nil, data.reclaimSpeed)
			debuffedUnits[unitID] = nil
			SendToUnsynced("unitBuildspeedDebuffEnd", unitID)
		end
	end
end

function gadget:UnitDestroyed(unitID)
	if debuffedUnits[unitID] then
		debuffedUnits[unitID] = nil
		SendToUnsynced("unitBuildspeedDebuffEnd", unitID)
	end
end