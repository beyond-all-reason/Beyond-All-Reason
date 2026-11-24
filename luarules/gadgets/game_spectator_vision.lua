function gadget:GetInfo()
	return {
		name = "Spectator Vision",
		desc = "Applies the lobby and personal spectator settings when the local player is eliminated",
		layer = -1000000,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() or not Spring.SetSpectatorFullCommunications then
	return false
end

local vision = VFS.Include("common/spectatorVision.lua")
local lobbyMode = vision.lobbyMode(Spring.GetModOptions().restrictedspectators)
local myPlayer = Spring.GetMyPlayerID()
local wasSpectating = Spring.GetSpectatingState()
local awaitingOptIn = false

local function grantFullAccess()
	awaitingOptIn = false
	Spring.SetSpectatorFullCommunications(true)
	Spring.SetSpectatorFullView(true)
	Spring.SetSpectatorFullSelect(true)
end

function gadget:PlayerChanged(playerID)
	if playerID ~= myPlayer then
		return
	end
	local spectating = Spring.GetSpectatingState()
	if spectating == wasSpectating then
		return
	end
	wasSpectating = spectating
	awaitingOptIn = false
	if spectating then
		local personalMode = Spring.GetConfigInt("EliminatedSpectatorVision", vision.full)
		local mode = math.min(lobbyMode, personalMode)
		if mode == vision.full or Spring.IsGameOver() then
			grantFullAccess()
		else
			awaitingOptIn = mode == vision.optIn
		end
	end
end

function gadget:Update()
	-- Poll only while the button is available. LuaUI may reload or the simulation may be paused.
	if awaitingOptIn and Script.LuaUI("BARSpectatorFullViewButton") and Script.LuaUI.BARSpectatorFullViewButton() then
		grantFullAccess()
	end
end

function gadget:GameOver()
	if Spring.GetSpectatingState() and not Spring.GetSpectatorFullCommunications() then
		grantFullAccess()
	end
end
