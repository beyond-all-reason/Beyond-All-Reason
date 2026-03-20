local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Tax Resource Sharing',
		desc    = 'Tax Resource Sharing when modoption enabled. Modified from "Prevent Excessive Share" by Niobium',
		author  = 'Rimilel, RebelNode',
		date    = 'April 2024, January 2026',
		license = 'GNU GPL, v2 or later',
		layer   = 1, -- Needs to occur before "Prevent Excessive Share" since their restriction on AllowResourceTransfer is not compatible
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end
if Spring.GetModOptions().tax_resource_sharing_amount == 0 and (not Spring.GetModOptions().easytax) then
	return false
end

local spIsCheatingEnabled = Spring.IsCheatingEnabled
local spGetTeamUnitCount = Spring.GetTeamUnitCount
local spGetTeamList = Spring.GetTeamList
local spGetTeamResources = Spring.GetTeamResources
local spGetTeamInfo = Spring.GetTeamInfo
local spAreTeamsAllied = Spring.AreTeamsAllied
local spUseTeamResource = Spring.UseTeamResource
local spShareTeamResource = Spring.ShareTeamResource
local spAddTeamResource = Spring.AddTeamResource
local spSetTeamResource = Spring.SetTeamResource
local math_max = math.max
local math_min = math.min

local gameMaxUnits = math.min(Spring.GetModOptions().maxunits, math.floor(32000 / #Spring.GetTeamList()))

local sharingTax = Spring.GetModOptions().tax_resource_sharing_amount
if Spring.GetModOptions().easytax then
	sharingTax = 0.3 -- 30% tax for easytax modoption
end

local function isAlliedUnit(teamID, unitID)
	local unitTeam = Spring.GetUnitTeam(unitID)
	return teamID and unitTeam and teamID ~= unitTeam and Spring.AreTeamsAllied(teamID, unitTeam)
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function gadget:AllowResourceTransfer(senderTeamId, receiverTeamId, resourceType, amount)

	-- Spring uses 'm' and 'e' instead of the full names that we need, so we need to convert the resourceType
	-- We also check for 'metal' or 'energy' incase Spring decides to use those in a later version
	local resourceName
	if (resourceType == 'm') or (resourceType == 'metal') then
		resourceName = 'metal'
	elseif (resourceType == 'e') or (resourceType == 'energy') then
		resourceName = 'energy'
	else
		-- We don't handle whatever this resource is, allow it
		return true
	end

	-- Calculate the maximum amount the receiver can receive
	--Current, Storage, Pull, Income, Expense
	local rCur, rStor, rPull, rInc, rExp, rShare = spGetTeamResources(receiverTeamId, resourceName)

	-- rShare is the share slider setting, don't exceed their share slider max when sharing
	local maxShare = rStor * rShare - rCur

	local taxedAmount = math_min((1-sharingTax)*amount, maxShare)
	local totalAmount = taxedAmount / (1-sharingTax)
	local transferTax = totalAmount * sharingTax

	spSetTeamResource(receiverTeamId, resourceName, rCur+taxedAmount)
	local sCur, _, _, _, _, _ = spGetTeamResources(senderTeamId, resourceName)
	spSetTeamResource(senderTeamId, resourceName, sCur-totalAmount)

	-- Block the original transfer
	return false
end

function gadget:AllowUnitTransfer(unitID, unitDefID, oldTeam, newTeam, capture)
	local unitCount = spGetTeamUnitCount(newTeam)
	if capture or spIsCheatingEnabled() or unitCount < gameMaxUnits then
		return true
	end
	return false
end

-- Below is implementation of the overflow mechanic in lua with taxing added.
-- Using this requires disabling engine overflow mechanic completely via modrule "system.nativeExcessSharing = false".
-- See https://github.com/beyond-all-reason/RecoilEngine/blob/master/rts/Sim/Misc/Team.cpp#L330 for engine overflow logic.
-- team is the player who is overflowing, otherTeam are the allied players who receive resources
UPDATE_PERIOD = 30 -- probably don't try to change this, apparently it's 30 in engine Team.cpp
function gadget:GameFrame(f)
	if (f-1) % UPDATE_PERIOD == 0 then
		local teamList = spGetTeamList()
		for j, teamID in ipairs(teamList) do
			local teamEnergyCurrentLevel, teamEnergyStorage, teamEnergyPull, teamEnergyIncome, teamEnergyExpense, teamEnergyShare, teamEnergySent, teamEnergyReceived, teamEnergyExcess = spGetTeamResources(teamID, "energy")
			local teamMetalCurrentLevel, teamMetalStorage, teamMetalPull, teamMetalIncome, teamMetalExpense, teamMetalShare, teamMetalSent, teamMetalReceived, teamMetalExcess = spGetTeamResources(teamID, "metal")

			local eShare = 0.0
			local mShare = 0.0

			-- calculate the total amount of resources that all
			-- allied teams can collectively receive through sharing
			for i, otherTeamID in ipairs(teamList) do
				local _,_,isDead = spGetTeamInfo(otherTeamID,false)
				if otherTeamID ~= teamID and spAreTeamsAllied(teamID, otherTeamID) and (not isDead) then
					local otherTeamMetalCurrentLevel, otherTeamMetalStorage,_,_,_, otherTeamMetalShare = spGetTeamResources(otherTeamID, "metal")
					local otherTeamEnergyCurrentLevel, otherTeamEnergyStorage,_,_,_, otherTeamEnergyShare = spGetTeamResources(otherTeamID, "energy")
					eShare = eShare + math_max(0.0, (otherTeamEnergyStorage * math_min(0.99, otherTeamEnergyShare)) - otherTeamEnergyCurrentLevel)
					mShare = mShare + math_max(0.0,(otherTeamMetalStorage * math_min(0.99, otherTeamMetalShare)) - otherTeamMetalCurrentLevel)
				end
			end

			-- calculate how much we can share in total (resources above the red share slider)
			local eExcess = math_max(0.0, teamEnergyCurrentLevel - (teamEnergyStorage * teamEnergyShare))
			local mExcess = math_max(0.0, teamMetalCurrentLevel  - (teamMetalStorage  * teamMetalShare))

			local de = 0.0
			local dm = 0.0
			if eShare > 0.0 then
				de = math_min(1.0, eExcess / eShare)
			end
			if mShare > 0.0 then
				dm = math_min(1.0, mExcess / mShare)
			end

			-- now evenly distribute our excess resources among allied teams
			for i, otherTeamID in ipairs(teamList) do
				local _,_,isDead = spGetTeamInfo(otherTeamID,false)
				if otherTeamID ~= teamID and spAreTeamsAllied(teamID, otherTeamID) and (not isDead) then
					local otherTeamMetalCurrentLevel, otherTeamMetalStorage,_,_,_, otherTeamMetalShare = spGetTeamResources(otherTeamID, "metal")
					local otherTeamEnergyCurrentLevel, otherTeamEnergyStorage,_,_,_, otherTeamEnergyShare = spGetTeamResources(otherTeamID, "energy")
					local edif = math_max(0.0, math_min(((otherTeamEnergyStorage * math_min(0.99, otherTeamEnergyShare)) - otherTeamEnergyCurrentLevel) * de, teamEnergyCurrentLevel))
					local mdif = math_max(0.0, math_min(((otherTeamMetalStorage * math_min(0.99, otherTeamMetalShare)) - otherTeamMetalCurrentLevel) * dm, teamMetalCurrentLevel))
					
					-- Tax the resources here. These count as used resources for in statistics, not sure what they should count as.
					spUseTeamResource(teamID, "energy", edif * sharingTax)
					spUseTeamResource(teamID, "metal", mdif * sharingTax)

					spShareTeamResource(teamID, otherTeamID, "energy", edif * (1-sharingTax))
					spShareTeamResource(teamID, otherTeamID, "metal", mdif * (1-sharingTax))
				end
			end

			----------------------------------------------------------------
			-- The resources that we technically already wasted are added to allies if possible. This tries to do the same as resDelayedShare in engine. This lets players overflow reclaimed buildings etc. that go over their storage capacity.
			----------------------------------------------------------------
			-- Allies have already received some resources above, reduce the amount they can still receive accordingly.
			eShare = eShare - eExcess
			mShare = mShare - mExcess

			eExcess = math_max(0.0, teamEnergyExcess)
			mExcess = math_max(0.0, teamMetalExcess)

			--- Tax the extra overflow, these resources are not shared and were already wasted to full storage
			eExcess = math_max(0.0, eExcess * (1-sharingTax))
			mExcess = math_max(0.0, mExcess * (1-sharingTax))

			de = 0.0
			dm = 0.0
			if eShare > 0.0 then
				de = math_min(1.0, eExcess / eShare)
			end
			if mShare > 0.0 then
				dm = math_min(1.0, mExcess / mShare)
			end

			-- now evenly distribute our extra excess resources among allied teams
			for i, otherTeamID in ipairs(teamList) do
				local _,_,isDead = spGetTeamInfo(otherTeamID,false)
				if otherTeamID ~= teamID and spAreTeamsAllied(teamID, otherTeamID) and (not isDead) then
					local otherTeamMetalCurrentLevel, otherTeamMetalStorage,_,_,_, otherTeamMetalShare = spGetTeamResources(otherTeamID, "metal")
					local otherTeamEnergyCurrentLevel, otherTeamEnergyStorage,_,_,_, otherTeamEnergyShare = spGetTeamResources(otherTeamID, "energy")
					local edif = math_max(0.0, math_min(((otherTeamEnergyStorage * math_min(0.99, otherTeamEnergyShare)) - otherTeamEnergyCurrentLevel) * de, teamEnergyCurrentLevel))
					local mdif = math_max(0.0, math_min(((otherTeamMetalStorage * math_min(0.99, otherTeamMetalShare)) - otherTeamMetalCurrentLevel) * dm, teamMetalCurrentLevel))
					
					-- These erroneously count as produced resources for allies in statistics. Not yet sure how to do this better, but this should be fine for modoption/testing at least.
					spAddTeamResource(otherTeamID, "energy", edif)
					spAddTeamResource(otherTeamID, "metal", mdif)
				end
			end
		end
	end
end
