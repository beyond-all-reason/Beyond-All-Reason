local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "CMD limiter",
		desc      = "",
		author    = "Floris",
		version   = "1",
		date      = "September 2023",
		license   = "GNU GPL, v2 or later",
		layer     = -999999,
		enabled   = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return
end

local historySeconds = 6
local maxCommands = 700
local startWarningOffences = 3
local maxOffences = 6
local isSingleplayer = Spring.Utilities.Gametype.IsSinglePlayer()
local mathFloor = math.floor
local mathMax = math.max

local history = {}
local totalCmdCount = 0
local totalOffence = 0
local offenceBuckets = {}
local currentTime = 0   -- accumulated real time in seconds

local spec = Spring.GetSpectatingState()
function gadget:PlayerChanged(playerID)
	spec = Spring.GetSpectatingState()
end

function gadget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if cmdID < 0 and not spec then	-- is build order
		if cmdOpts.shift then
			local bucket = mathFloor(currentTime * 30)	-- ~30fps granularity buckets
			if offenceBuckets[bucket] then
				return true
			end
			history[bucket] = (history[bucket] or 0) + 1
			totalCmdCount = totalCmdCount + 1
			if totalCmdCount > maxCommands then
				offenceBuckets[bucket] = true
				totalOffence = totalOffence + 1
				if not isSingleplayer then
					if totalOffence >= maxOffences then
						--Spring.I18N('ui.cmdlimiter.forceresign')
						Spring.Echo("\255\255\040\040YOU QUEUED TOO MUCH BUILDINGS TOO MANY TIMES, YOU HAVE BEEN FORCE RESIGNED!")
						Spring.SendCommands("spectator")
					elseif totalOffence >= startWarningOffences then
						--Spring.I18N('ui.cmdlimiter.forceresignwarning')
						Spring.Echo("\255\255\085\085YOU HAVE QUEUED TOO MUCH BUILDINGS IN A SHORT PERIOD, KEEP DOING THIS AND YOU WILL GET AUTO RESIGNED!")
					end
				end
				totalCmdCount = totalCmdCount - mathFloor(maxCommands/2)	-- remove some so user can instantly queue something next without instantly being warned again
				return true
			end
		end
	end
	return false
end


function gadget:Update(dt)
	currentTime = currentTime + dt
	local cutoffBucket = mathFloor((currentTime - historySeconds) * 30)
	for bucket, count in pairs(history) do
		if bucket <= cutoffBucket then
			totalCmdCount = mathMax(0, totalCmdCount - count)
			history[bucket] = nil
			offenceBuckets[bucket] = nil
		end
	end
end
