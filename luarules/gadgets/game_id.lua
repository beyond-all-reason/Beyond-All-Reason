if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "GameID GameRulesParam",
		desc = "Exposes GameID as a rules param for luaui reload",
		author = "Sprung",
		date = "2022-12-21",
		license = "Public Domain",
		layer = 0,
		enabled = true,
	}
end

function gadget:GameID(msg)
	Spring.SetGameRulesParam("GameID", msg)
	gadgetHandler:RemoveGadget()
end
