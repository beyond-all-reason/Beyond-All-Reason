-- Parses actions separated by | and attempts each one in succession
--
-- The action is specified as so `chain <force> <action1> <action1args> | <action2> <action2args> <...>`
--
-- If force is passed, then all actions in the chain will be performed
--
-- Otherwise the actions after the first will only be performed if the first
-- responds.
--
-- Keep in mind engine actions without text command support won't work.
--
-- For the ones with text support (work with Spring.SendCommands) it's advised
-- to use the force parameter since they can't be known to respond.
--
-- Example:
--
-- Selects one unit from current selection and unsets control group:
--
--   bind u chain force select PrevSelection++_ClearSelection_SelectOne+ | group unset
--
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Chain Actions",
		desc = "Allows lua actions to be chained together",
		author = "badosu",
		date = "April 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

local function tryRawCmd(rawCmd, isRepeat, isRelease)
	rawCmd = string.trim(rawCmd)

	local cmd, extra = string.match(rawCmd, "^(%w+)[%s]*(.*)$")
	local bAction = {
		command = cmd,
		extra = extra,
	}

	if widgetHandler.actionHandler:KeyAction(not isRelease, nil, nil, isRepeat, _, { bAction }) then
		return true
	end

	-- Attempt text command (for engine cmds)
	Spring.SendCommands(rawCmd)

	return false
end

local function chainHandler(_, extra, bOpts, _, isRepeat, isRelease)
	-- Whether to keep sending actions even if first does not respond
	--
	local force = false

	if bOpts[1] == "force" then
		force = true
		extra = string.match(extra, "^force[%s]+(.*)$")
	end

	local rawCmds = string.split(extra, "|")

	if #rawCmds == 0 then
		return false
	end

	if not force then
		local firstRawCmd = table.remove(rawCmds, 1)

		-- if the first command does not respond we return early
		if not tryRawCmd(string.trim(firstRawCmd), isRepeat, isRelease) then
			return false
		end
	end

	for _, rawCmd in pairs(rawCmds) do
		tryRawCmd(string.trim(rawCmd))
	end

	return true
end

function widget:Initialize()
	widgetHandler.actionHandler:AddAction(self, "chain", chainHandler, nil, "p")
end
