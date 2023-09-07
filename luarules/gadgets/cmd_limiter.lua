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

local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()

local historyFrames = 180
local maxCommands = 450

local history = {}
local totalCmdCount = 0
local totalOffence = 0
local offenceFrames = {}
function gadget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if cmdID < 0 then	-- is build order
		if cmdOpts.shift then
			local gf = Spring.GetGameFrame()
			if offenceFrames[gf] then
				return true
			end
			history[gf] = (history[gf] or 0) + 1
			totalCmdCount = totalCmdCount + 1
			if totalCmdCount > maxCommands then
				if not isSinglePlayer then
					offenceFrames[gf] = true
					totalOffence = totalOffence + 1
					if totalOffence >= 5 then
						--Spring.I18N('ui.cmdlimiter.forceresign')
						Spring.Echo("You queued too much buildings too many times, you have been force resigned!")
						Spring.SendCommands("spectator")
					elseif totalOffence >= 3 then
						--Spring.I18N('ui.cmdlimiter.forceresignwarning')
						Spring.Echo("You queued too much buildings a few time, continue this and you will get forcefully resigned.")
					end
					totalCmdCount = totalCmdCount - 100	-- remove some so user can instantly queue somehting next without instantly being warned again
				end
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
