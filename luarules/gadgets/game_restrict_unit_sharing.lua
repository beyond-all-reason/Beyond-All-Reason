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

local DEBUFF_FRAMES = Game.gameSpeed * 30
local debuffedUnits = {} -- unitID -> { expireFrame, buildSpeed }

local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt

-- gather all economy/builder units
local ecoUnits = {}
local builderUnits = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local group = unitDef.customParams.unitgroup
	if group then
		if group == "builder" or group == "buildert2" or group == "buildert3" then
			if not unitDef.isImmobile then -- not factory or conturret
				builderUnits[unitDefID] = true
			else
				ecoUnits[unitDefID] = true
			end
		elseif group == "energy" or group == "metal" then
			ecoUnits[unitDefID] = true
		end
	end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if (capture) and (not Spring.AreTeamsAllied(fromTeamID, toTeamID)) or fromTeamID == Spring.GetGaiaTeamID() or toTeamID == Spring.GetGaiaTeamID() then
		return true
	end
	beingBuilt, buildProgress = spGetUnitIsBeingBuilt(unitID)
	if beingBuilt and buildProgress > 0 and next(Spring.GetPlayerList(fromTeamID, true)) ~= nil then
		return false -- Sharing partly built nanoframes is not allowed because letting it decay bypasses taxation and letting it build runs out the debuff early. Also if you can't assist ally build the unit could get stuck in factory.
	end
	if builderUnits[unitDefID] then
		local unitDef = UnitDefs[unitDefID]
		local startFrame = Spring.GetGameFrame()
		local expireFrame = startFrame + DEBUFF_FRAMES
		debuffedUnits[unitID] = {
			expireFrame  = expireFrame,
		}
		SendToUnsynced("unitBuildspeedDebuff", unitID, startFrame, expireFrame)
	elseif ecoUnits[unitDefID] then
		local _, maxHealth = Spring.GetUnitHealth(unitID)
		Spring.AddUnitDamage(unitID, maxHealth * 5, 30) -- Stun for 30 seconds.
	end
	return true
end

function gadget:AllowFeatureBuildStep(builderID, builderTeam, featureID, featureDefID, part)
	if debuffedUnits[builderID] then
		return false
	end
	return true
end

function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, part)
	if debuffedUnits[builderID] and spGetUnitIsBeingBuilt(unitID) then
		return false
	end
	return true
end

local expiredUnits = {}

function gadget:GameFrame(n)
	local expiredCount = 0
	for unitID, data in pairs(debuffedUnits) do
		if n >= data.expireFrame then
			expiredCount = expiredCount + 1
			expiredUnits[expiredCount] = unitID
		end
	end
	for i = 1, expiredCount do
		local unitID = expiredUnits[i]
		expiredUnits[i] = nil
		debuffedUnits[unitID] = nil
		SendToUnsynced("unitBuildspeedDebuffEnd", unitID)
	end
end

function gadget:UnitDestroyed(unitID)
	if debuffedUnits[unitID] then
		debuffedUnits[unitID] = nil
		SendToUnsynced("unitBuildspeedDebuffEnd", unitID)
	end
end