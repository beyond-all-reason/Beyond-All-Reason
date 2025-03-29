local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Explosion Deformation Fix",
		desc = "123",
		author = "Damgam, GoogleFrog",
		date = "2022",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
    return
end

function gadget:UnitCreated(unitID, unitDefID)
	-- Terraform gadget already deals with structures restoring themselves to their original heights after
	-- explosions. Unlike engine restoration it does this with an infrequent poll, so hitting bewteen nuke
	-- crater and nuke damage is unlikely.
	if Spring.ValidUnitID(unitID) then
		local b1, b2, b3, b4, b5, b6, b7 = Spring.GetUnitBlocking(unitID)
		Spring.SetUnitBlocking(unitID, b1, b2, b3, b4, b5, b6, false)
	end
end

-- local deformationDisableList = {}
-- function gadget:UnitCreated(unitID, unitDefID)
--     table.insert(deformationDisableList, unitID)
-- end

-- function gadget:GameFrame(n)
--     if #deformationDisableList > 0 then
--         for i = 1,#deformationDisableList do
--             local unitID = deformationDisableList[i]
--             local _,_,_,_,buildProgress = Spring.GetUnitHealth(unitID)
--             if buildProgress > 0.01 then
--                 local b1, b2, b3, b4, b5, b6, b7 = Spring.GetUnitBlocking(unitID)
--                 Spring.SetUnitBlocking(unitID, b1, b2, b3, b4, b5, b6, false)
--                 table.remove(deformationDisableList, i)
--                 break
--             end
--         end
--     end
-- end

-- function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
--     if #deformationDisableList > 0 then
--         for i = 1,#deformationDisableList do
--             if deformationDisableList[i] == unitID then
--                 table.remove(deformationDisableList, i)
--                 break
--             end
--         end
--     end
-- end
