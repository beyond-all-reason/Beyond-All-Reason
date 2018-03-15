
function gadget:GetInfo()
	return {
		name	= "Activity Broadcast",
		desc	= "Checks if there is keyboard/mouse activity or camera changes",
		author	= "Floris",
		date	= "July,2016",
		layer	= 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- config
--------------------------------------------------------------------------------

local sendPacketEvery	= 2

--------------------------------------------------------------------------------
-- synced
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then
	local charset = {}  do -- [0-9a-zA-Z]
		for c = 48, 57  do table.insert(charset, string.char(c)) end
		for c = 65, 90  do table.insert(charset, string.char(c)) end
		for c = 97, 122 do table.insert(charset, string.char(c)) end
	end
	local function randomString(length)
		if not length or length <= 0 then return '' end
		--math.randomseed(os.clock()^5)
		return randomString(length - 1) .. charset[math.random(1, #charset)]
	end

	local validation = randomString(2)
	_G.validationActivity = validation

	function gadget:RecvLuaMsg(msg, playerID)
		if msg:sub(1,1)=="^" and msg:sub(2,3)==validation then
			SendToUnsynced("activityBroadcast",playerID)
			return true
		end
	end
	
else
	--------------------------------------------------------------------------------
	-- unsynced
	--------------------------------------------------------------------------------

	local GetMouseState					= Spring.GetMouseState
	local GetLastUpdateSeconds	= Spring.GetLastUpdateSeconds
	local SendLuaRulesMsg				= Spring.SendLuaRulesMsg
	local GetCameraState				= Spring.GetCameraState
	
	local activity							= false
	local old_mx,old_my					= 0,0
	local updateTimer						= 0
	local prevCameraState				= GetCameraState()
	local validation = SYNCED.validationActivity
	
	function gadget:Initialize()
		gadgetHandler:AddSyncAction("activityBroadcast", handleActivityEvent)
	end
	
	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("activityBroadcast")
	end
	
	function handleActivityEvent(_,playerID)
		if Script.LuaUI("ActivityEvent") then
			Script.LuaUI.ActivityEvent(playerID)
		end
	end
	
	function gadget:Update()
		updateTimer = updateTimer + GetLastUpdateSeconds()
		if updateTimer > sendPacketEvery then
			-- mouse
			local mx,my = GetMouseState()
			if mx ~= old_mx or my ~= old_my then
				old_mx,old_my = mx,my
				activity = true
			end
			-- camera
			local cameraState = GetCameraState()
			if not activity then 
					for i,stateindex in pairs(cameraState) do
					if stateindex ~= prevCameraState[i] then
						activity = true
						break
					end
				end
			end
			prevCameraState = cameraState
			
			if activity then
				SendLuaRulesMsg("^"..validation)
			end
			activity = false
			updateTimer = 0
		end
	end
	
	function gadget:KeyPress(key, mods, isRepeat)
		activity = true
	end

end

