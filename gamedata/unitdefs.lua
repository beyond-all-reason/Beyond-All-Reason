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

local DownloadBuilds = VFS.Include('gamedata/download_builds.lua')

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
local scavengersEnabled = true
local raptorsEnabled = true
if Spring.GetTeamList then
	scavengersEnabled = false
	raptorsEnabled = false
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		local luaAI = Spring.GetTeamLuaAI(teamID)
		if luaAI then
			if luaAI:find("Raptors") then
				raptorsEnabled = true
			elseif luaAI:find("Scavengers") then
				scavengersEnabled = true
			end
		end
	end

	-- Load all unitdefs when Singleplayer and in DevMode
	--local playerCount = 0
	--for _, team in ipairs(teamList) do
	--	if not select (4, Spring.GetTeamInfo(team, false)) then
	--		local teamPlayers = Spring.GetPlayerList(team)
	--		for _, playerID in ipairs(teamPlayers) do
	--			playerCount = playerCount + 1
	--		end
	--	end
	--end
	--if playerCount <= 1 and Spring.GetConfigInt("DevMode", 0) == 1 then		-- ERRORS: Spring.GetConfigInt is not available here
	--	scavengersEnabled = true
	--	raptorsEnabled = true
	--	legionEnabled = true
	--end
end
if Spring.GetModOptions().ruins == "enabled" then
	legionEnabled = true
	scavengersEnabled = true
elseif scavengersEnabled then
	legionEnabled = true
end

if Spring.GetModOptions().experimentalextraunits == true then
	scavengersEnabled = true
end

if Spring.GetModOptions().forceallunits == true then
	raptorsEnabled = true
	scavengersEnabled = true
	legionEnabled = true
end

for _, filename in ipairs(luaFiles) do
	if legionEnabled or not filename:find('legion') then
		if scavengersEnabled or not filename:find('scavengers') then
			if raptorsEnabled or not filename:find('raptors') then
				local udEnv = {}
				udEnv._G = udEnv
				udEnv.Shared = shared
				udEnv.GetFilename = function() return filename end
				setmetatable(udEnv, { __index = system })
				local success, uds = pcall(VFS.Include, filename, udEnv, vfs_modes)
				if not success then
					Spring.Log(section, LOG.ERROR, 'Error parsing ' .. filename .. ': ' .. tostring(uds))
				elseif type(uds) ~= 'table' then
					Spring.Log(section, LOG.ERROR, 'Bad return table from: ' .. filename)
				else
					for udName, ud in pairs(uds) do
						if ((type(udName) == 'string') and (type(ud) == 'table')) then
							unitDefs[udName] = ud
						else
							Spring.Log(section, LOG.ERROR, 'Bad return table entry from: ' .. filename)
						end
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Insert the download build entries
--

DownloadBuilds.Execute(unitDefs)

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
	local cob = 'scripts/'   .. name .. '.cob'
	local obj = def.objectName or def.objectname
	if obj == nil then
		unitDefs[name] = nil
		Spring.Log(section, LOG.ERROR, 'removed ' .. name .. ' unitDef, missing objectname param')
		for k,v in pairs(def) do print('',k,v) end
	else
		local objfile = 'objects3d/' .. obj
		if not VFS.FileExists(objfile) and not VFS.FileExists(objfile .. '.s3o') then
			unitDefs[name] = nil
			Spring.Log(section, LOG.ERROR, 'removed ' .. name .. ' unitDef, missing model file  (' .. obj .. ')')
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
				--Spring.Log(section, LOG.ERROR, 'removed the "' .. option ..'" entry' .. ' from the "' .. name .. '" build menu')
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
