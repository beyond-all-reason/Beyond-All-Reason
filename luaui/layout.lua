--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	file:	 layout.lua
--	brief:	 dummy and default LayoutButtons() routines
--	author:	 Dave Rodgers
--
--	Copyright (C) 2007.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	ConfigLayoutHandler(data) is defined at the end of this file.
--
--	  data ==  true:  use DummyLayoutHandler
--	  data ==  func:  use the provided function
--	  data ==	nil:  use Spring's default control panel
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CopyTable(outtable,intable)
	for i,v in pairs(intable) do
		if (type(v)=='table') then
			if (type(outtable[i])~='table') then
				outtable[i] = {}
			end
			CopyTable(outtable[i],v)
		else
			outtable[i] = v
		end
	end
end

--------------------------------------------------------------------------------

-- No longer used for UI, but necessary for custom commands to function properly
local function DummyLayoutHandler(xIcons, yIcons, cmdCount, commands)
	widgetHandler.commands	 = commands
	widgetHandler.commands.n = cmdCount
	widgetHandler:CommandsChanged()
	local reParamsCmds = {}
	local customCmds = {}
	
	local cnt = 0
	
	local AddCommand = function(command)
		local cc = {}
		CopyTable(cc,command )
		cnt = cnt + 1
		cc.cmdDescID = cmdCount+cnt
		if (cc.params) then
			if (not cc.actions) then --// workaround for params
				local params = cc.params
				for i=1,#params+1 do
					params[i-1] = params[i]
				end
				cc.actions = params
			end
			reParamsCmds[cc.cmdDescID] = cc.params
		end
		--// remove api keys (custom keys are prohibited in the engine handler)
		cc.pos		 = nil
		cc.cmdDescID = nil
		cc.params	 = nil
		
		customCmds[#customCmds+1] = cc
	end
	
	--// preprocess the Custom Commands
	for i=1,#widgetHandler.customCommands do
		AddCommand(widgetHandler.customCommands[i])
	end

	if (cmdCount <= 0) then
		return "", xIcons, yIcons, {}, customCmds, {}, {}, {}, {}, reParamsCmds, {} --prevent CommandChanged() from being called twice when deselecting all units  (copied from ca_layout.lua)
	end
	
	return "", xIcons, yIcons, {}, customCmds, {}, {}, {}, {}, reParamsCmds, {[1337]=9001}
end

--------------------------------------------------------------------------------

function ConfigLayoutHandler(data)
	if (type(data) == 'function') then
		LayoutButtons = data
	elseif (data == nil) then
		LayoutButtons = nil
	else
		LayoutButtons = DummyLayoutHandler
	end
end
LayoutButtons = DummyLayoutHandler

--------------------------------------------------------------------------------
