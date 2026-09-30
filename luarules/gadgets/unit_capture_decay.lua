local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Capture Decay",
		desc = "Decays capture progress if there was none done over the past 10 seconds",
		author = "Damgam",
		date = "2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local GAME_SPEED_FPS = Game.gameSpeed
local SLOWUPDATE_RATE = GAME_SPEED_FPS / 2
local CAPTURE_DECAY_DELAY_SECONDS = 10
local CAPTURE_DECAY_ACCEL = 0.001

---@type table<UnitID, { lastCaptureFrame: number, previousCaptureProgress: number }>
local unitsWithCaptureProgress = {}

local function ensureTracked(unitID, frame)
	local data = unitsWithCaptureProgress[unitID]
	if data then
		return data
	end
	data = {
		lastCaptureFrame = frame,
		previousCaptureProgress = select(4, Spring.GetUnitHealth(unitID)) or 0,
	}
	unitsWithCaptureProgress[unitID] = data
	return data
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	unitsWithCaptureProgress[unitID] = nil
end

function gadget:GameFrame(frame)
	for unitID, data in pairs(unitsWithCaptureProgress) do
		if unitID % SLOWUPDATE_RATE == frame % SLOWUPDATE_RATE then
			local captureLevel = select(4, Spring.GetUnitHealth(unitID))
			if not captureLevel or captureLevel <= 0 then
				unitsWithCaptureProgress[unitID] = nil
			else
				-- Some PvE capture sources set capture directly so we need to update the last capture frame manually.
				if captureLevel > data.previousCaptureProgress then
					data.lastCaptureFrame = frame
					SendToUnsynced("unitCaptureFrame", unitID, captureLevel)
				end
				data.previousCaptureProgress = captureLevel

				local secondsPastGrace = (frame - data.lastCaptureFrame) / GAME_SPEED_FPS - CAPTURE_DECAY_DELAY_SECONDS
				if secondsPastGrace >= 0 then
					local dtSeconds = SLOWUPDATE_RATE / GAME_SPEED_FPS
					local decayAtSlowUpdate = secondsPastGrace * CAPTURE_DECAY_ACCEL * dtSeconds
					captureLevel = math.max(captureLevel - decayAtSlowUpdate, 0)
					Spring.SetUnitHealth(unitID, { capture = captureLevel })
					data.previousCaptureProgress = captureLevel
					if captureLevel <= 0 then
						unitsWithCaptureProgress[unitID] = nil
					end
				end
			end
		end
	end
end

function gadget:AllowUnitCaptureStep(builderID, builderTeam, unitID, unitDefID, part)
	if builderID then
		local frame = Spring.GetGameFrame()
		ensureTracked(unitID, frame).lastCaptureFrame = frame
	end
	return true
end

---Starts tracking a unit so its partial capture progress decays over time.
---Does nothing if the unit is already tracked.
---@param unitID UnitID
function addUnitToCaptureDecay(unitID)
	ensureTracked(unitID, Spring.GetGameFrame())
end

GG.addUnitToCaptureDecay = addUnitToCaptureDecay
