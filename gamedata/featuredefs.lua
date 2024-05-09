--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    featuredefs.lua
--  brief:   featuredef parser
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local featureDefs = {}
local shared = {} -- shared amongst the lua featuredef enviroments

local preProcFile  = 'gamedata/featuredefs_pre.lua'
local postProcFile = 'gamedata/featuredefs_post.lua'

local system = VFS.Include('gamedata/system.lua')
local section='featuredefs.lua'

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Run a pre-processing script if one exists
--

if (VFS.FileExists(preProcFile)) then
	Shared = shared  -- make it global
	FeatureDefs = featureDefs  -- make it global
	VFS.Include(preProcFile)
	FeatureDefs = nil
	Shared = nil
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Load the raw LUA format featuredef files
--

local luaFiles = VFS.DirList('features/', '*.lua', nil, true)

for _, filename in ipairs(luaFiles) do
	local fdEnv = {}
	fdEnv._G = fdEnv
	fdEnv.Shared = shared
	fdEnv.GetFilename = function() return filename end
	setmetatable(fdEnv, { __index = system })
	local success, fds = pcall(VFS.Include, filename, fdEnv, vfs_modes)

	if (not success) then
		Spring.Log(section, LOG.ERROR, 'Error parsing ' .. filename .. ': ' .. tostring(fds))
	elseif (fds == nil) then
		Spring.Log(section, LOG.ERROR, 'Missing return table from: ' .. filename)
	else
		for fdName, fd in pairs(fds) do
			if ((type(fdName) == 'string') and (type(fd) == 'table')) then
				featureDefs[fdName] = fd
			end
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Run a post-processing script if one exists
--

if (VFS.FileExists(postProcFile)) then
	Shared = shared  -- make it global
	FeatureDefs = featureDefs  -- make it global
	VFS.Include(postProcFile)
	FeatureDefs = nil
	Shared = nil
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

return featureDefs
