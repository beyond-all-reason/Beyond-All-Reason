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

local historyFrames = 180
local maxCommands = 600
local startWarningOffences = 3
local maxOffences = 6
local isSingleplayer = Spring.Utilities.Gametype.IsSinglePlayer()

local history = {}
local totalCmdCount = 0
local totalOffence = 0
local offenceFrames = {}

local spec = Spring.GetSpectatingState()
function gadget:PlayerChanged(playerID)
	spec = Spring.GetSpectatingState()
end

function gadget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if cmdID < 0 and not spec then	-- is build order
		if cmdOpts.shift then
			local gf = Spring.GetGameFrame()
			if offenceFrames[gf] then
				return true
			end
			history[gf] = (history[gf] or 0) + 1
			totalCmdCount = totalCmdCount + 1
			if totalCmdCount > maxCommands then
				offenceFrames[gf] = true
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
				totalCmdCount = totalCmdCount - math.floor(maxCommands/2)	-- remove some so user can instantly queue something next without instantly being warned again
				return true
			end
		end
	end
	return false
end


function gadget:GameFrame(gf)
	if history[gf - historyFrames] then
		totalCmdCount = math.max(0, totalCmdCount - history[gf - historyFrames])
		history[gf - historyFrames] = nil
	end
end
