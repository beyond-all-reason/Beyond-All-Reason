-- initial setup of things

--- Generates a per AI shard_include function
--
-- Returns a function that can be used for shard_include
-- that is specific for a particular AI
-- e.g.
--
-- ```
-- local load = shard_generate_include_func( 'luarules/gadgets/shard_runtime', 'luarules/gadgets/myai' )
-- local config = load( "config" )
-- ```
--
-- The returned function will also check for a folder with that file name
--
-- @param runtime_path the location of the Shard runtime
-- @param ai_path the location of the AI itself
--
-- @return function a shard_include function
function shard_generate_include_func( runtime_path, ai_path )
	return function( file )
		if type(file) ~= 'string' then
			return nil
		end
		local candidates = {
			ai_path .. "/" .. file .. ".lua",
			ai_path .. "/" .. file .. "/main.lua",
			runtime_path .. "/" .. file .. ".lua",
			runtime_path .. "/" .. file .. "/main.lua"
		}
		for index, file in ipairs( candidates ) do
			if VFS.FileExists(file) then
				return VFS.Include(file)
			end
		end
		Spring.Echo( "Failed to load " .. file .. " we attempted to load the first of the following:" )
		for index, file in ipairs( candidates ) do
			Spring.Echo( index .. ": " .. file )
		end
		return nil
	end
end

--- the default shard include function, only deals with the runtime files for boot up
function shard_include(file)
	if type(file) ~= 'string' then
		return nil
	end
	local runtime_file = "luarules/gadgets/ai/shard_runtime/" .. file .. ".lua"
	if VFS.FileExists(runtime_file) then
		return VFS.Include(runtime_file)
	end
	Spring.Echo( "Failed to load "..runtime_file )
	return
end

os = shard_include( "spring_lua/fakeos" )
api = shard_include( "spring_lua/fakeapi" )

local runtime_includes = {
	"spring_lua/shard",
	"hooks",
	"class",
	"aibase",
	"module",
	"shardai",
	"spring_lua/unit",
	"spring_lua/unittype",
	"spring_lua/damage",
	"spring_lua/feature",
}


for key,include in ipairs(runtime_includes) do
	local result = shard_include( include )
end
