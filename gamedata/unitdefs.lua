--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unitdefs.lua
--  brief:   unitdef parser
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local unitDefs = {}
local shared = {} -- shared amongst the lua unitdef enviroments

local preProcFile  = 'gamedata/unitdefs_pre.lua'
local postProcFile = 'gamedata/unitdefs_post.lua'

local system = VFS.Include('gamedata/system.lua')

local section = 'unitdefs.lua'

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Run a pre-processing script if one exists
--

if VFS.FileExists(preProcFile) then
	Shared   = shared    -- make it global
	UnitDefs = unitDefs  -- make it global
	VFS.Include(preProcFile)
	UnitDefs = nil
	Shared   = nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Load the raw LUA format unitdef files
--  (these will override the SWU versions)
--

local luaFiles = VFS.DirList('units/', '*.lua', nil, true)

local legionEnabled = Spring.GetModOptions().experimentallegionfaction
local scavengersEnabled = Spring.Utilities.Gametype.IsScavengers()
local raptorsEnabled = Spring.Utilities.Gametype.IsRaptors()

if Spring.GetModOptions().ruins == "enabled" then
	legionEnabled = true
	scavengersEnabled = true
elseif scavengersEnabled then
	legionEnabled = true
end

if Spring.GetModOptions().experimentalextraunits or Spring.GetModOptions().scavunitsforplayers then
	scavengersEnabled = true
end

if Spring.GetModOptions().forceallunits then
	raptorsEnabled = true
	scavengersEnabled = true
	legionEnabled = true
end

for _, filename in ipairs(luaFiles) do
	local loadFile = (legionEnabled or not filename:find('legion'))
					and (scavengersEnabled or not filename:find('scavengers'))
					and (raptorsEnabled or not filename:find('raptors'))

	if loadFile then
		local unitDefsEnv = {}
		unitDefsEnv._G = unitDefsEnv
		unitDefsEnv.Shared = shared
		unitDefsEnv.GetFilename = function() return filename end
		setmetatable(unitDefsEnv, { __index = system })
		local success, defs = pcall(VFS.Include, filename, unitDefsEnv, VFS_MODES)
		if not success then
			Spring.Log(section, LOG.ERROR, 'Error parsing ' .. filename .. ': ' .. tostring(defs))
		elseif type(defs) ~= 'table' then
			Spring.Log(section, LOG.ERROR, 'Bad return table from: ' .. filename)
		else
			for unitDefName, unitDef in pairs(defs) do
				if ((type(unitDefName) == 'string') and (type(unitDef) == 'table')) then
					unitDefs[unitDefName] = unitDef
				else
					Spring.Log(section, LOG.ERROR, 'Bad return table entry from: ' .. filename)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Run a post-processing script if one exists
--

if VFS.FileExists(postProcFile) then
	Shared   = shared    -- make it global
	UnitDefs = unitDefs  -- make it global
	VFS.Include(postProcFile)
	UnitDefs = nil
	Shared   = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Basic checks to kill unitDefs that will crash ".give all"
--

for name, def in pairs(unitDefs) do
	local model = def.objectName or def.objectname
	if model == nil then
		unitDefs[name] = nil
		Spring.Log(section, LOG.ERROR, 'removed ' .. name .. ' unitDef, missing objectname param')
	else
		local objfile = 'objects3d/' .. model
		if not VFS.FileExists(objfile) then
			unitDefs[name] = nil
			Spring.Log(section, LOG.ERROR, 'removed ' .. name .. ' unitDef, missing model file  (' .. model .. ')')
		end
	end
end

for name, def in pairs(unitDefs) do
	local badOptions = {}
	local buildOptions = def.buildOptions or def.buildoptions
	if buildOptions then
		for i, option in ipairs(buildOptions) do
			if unitDefs[option] == nil then
				table.insert(badOptions, i)
			end
		end
		if #badOptions > 0 then
			local removed = 0
			for _, badIndex in ipairs(badOptions) do
				table.remove(buildOptions, badIndex - removed)
				removed = removed + 1
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return unitDefs
