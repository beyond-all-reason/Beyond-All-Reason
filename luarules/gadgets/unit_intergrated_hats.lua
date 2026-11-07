local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Integrated Hats",
		desc = "Hides hats used for april and alike events, hats get baked into models swapped in in alldefs post",
		author = "",
		date = "1st Of April",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end
--	Authors:
--		robert the pie; scripts, hats:
--			baseball cap, football helmet, mini rocket pod, shoulder spikes, mahwak, pool floaty,
--			mini pawn head, chess pawn, party hat, fedora, tophat, weird arms, UNICORN CATHAT
--		the silver hornet; hats:
--			hard hat, construction cone, jester, proppeler hat, sunhat(unused),

-- synced space only, the hats aren't part of the modified models, hiding them is a synced animation action
if not gadgetHandler:IsSyncedCode() then
	return false
end

-- are any hats enabled
local hatCounts = {}
local unitCount = 0
do
	-- customparams.holidayhatcount is stamped in alldefs_post next to the holiday model swap
	-- (unitbasedefs/holiday_models.lua), so it only exists while the matching holiday is active
	local anyHats = false
	for unitDefID, unitDef in pairs(UnitDefs) do
		local numberOfHats = tonumber(unitDef.customParams.holidayhatcount)
		if numberOfHats and numberOfHats > 0 then
			hatCounts[unitDefID] = numberOfHats
			anyHats = true
		end
	end

	if not anyHats then
		return false
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	-- we increment every time a unit is made, makes for a good rng in our case
	unitCount = unitCount + 1

	-- hide all but the chosen hat
	local numberOfHats = hatCounts[unitDefID]
	if numberOfHats then
		local unitPieceList = Spring.GetUnitPieceMap(unitID)
		-- @NOTE: current formula means all units will have a hat
		local hatRoll = unitCount % numberOfHats + 1
		for i = 1, numberOfHats do
			if i ~= hatRoll then
				Spring.SetUnitPieceVisible(unitID, unitPieceList["h" .. i], false)
			else
				-- hats should be zeroed so that when on 0,0,0 they are where they should be, otherwise buried in the ground
				-- (the 16 numbers is a matrix that positions them at 0,0,0, of scale 1,1,1, unrotated (rotation gets baked in, in upspring))
				Spring.SetUnitPieceMatrix(
					unitID,
					unitPieceList["h" .. i],
					{ 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 }
				)
			end
		end
	end
end
