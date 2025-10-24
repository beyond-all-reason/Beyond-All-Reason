local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name		= "Intergrated Hats",
		desc		= "Hides hats used for april and alike events, hats get baked into models swapped in in alldefs post",
		author		= "",
		date		= "1st Of April",
		license		= "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= true
	}
end
--	Authors:
--		robert the pie; scripts, hats:
--			baseball cap, football helmet, mini rocket pod, shoulder spikes, mahwak, pool floaty, 
--			mini pawn head, chess pawn, party hat, fedora, tophat, weird arms, UNICORN CATHAT
--		the silver hornet; hats:
--			hard hat, construction cone, jester, proppeler hat, sunhat(unused), 

-- synced space only, the hats arent part of the modified models, hiding them is a synced animation action
if not gadgetHandler:IsSyncedCode() then
	return false
end

-- are any hats enabled
local hatCounts = {}
local unitCount = 0
do
	local hats

	if Spring.Utilities.Gametype.GetCurrentHolidays()["aprilfools"] then
		hats = "april"
	end

	if hats then

		-- count of how many hats a unit has for the hat mode
		-- unit models should be swapped out to the appropate models via all defs post
		local hatCountsTemp = {}
		local hatTable = {
			april = { -- objects3d/units/events/aprilfools, AprilFools hats
				corak=7,
				corstorm=7,
				corck=6,
				corack=6,
				correap=6,
				corllt=8,
				corhllt=8,
				cordemon=4,
				armpw=7,
				armcv=5,
				armrock=6,
				armbull=6,
				armllt=6,
				corwin=7,
				armwin=6,
				armham=5,
				corthud=6,
			},
		}

		hatCountsTemp = hatTable[hats]
		-- if we failed to find hats
		if not hatCountsTemp then
			return false
		end

		-- make sure we didn't blunder unit names, or the unit in question is loaded
		for unitName, hatsNo in pairs(hatCountsTemp) do
			local tmp = UnitDefNames[unitName]
			if tmp and tmp.id then
				hatCounts[tmp.id] = hatsNo
			end
		end
	else
		return false
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)

	-- we increment every time a unit is made, makes for a good rng in our case
	unitCount = unitCount + 1

	-- hide all but the choosen hat
	local numberOfHats = hatCounts[unitDefID]
	if numberOfHats then
		local unitPieceList = Spring.GetUnitPieceMap(unitID)
		-- @NOTE: current formula means all units will have a hat
		local hatRoll = unitCount % numberOfHats + 1
		for i = 1, numberOfHats do
			if i ~= hatRoll then
				Spring.SetUnitPieceVisible(unitID, unitPieceList["h"..i], false)
			else
				-- hats should be zeroed so that when on 0,0,0 they are where they should be, otherwise buried in the ground
				-- (the 16 numbers is a matrix that positions them at 0,0,0, of scale 1,1,1, unrotated (rotation gets baked in, in upspring))
				Spring.SetUnitPieceMatrix(unitID, unitPieceList["h"..i], { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1})
			end
		end
	end
end
