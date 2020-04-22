-- initial setup of things

-- Generates a per AI shard_include function
function shard_generate_include_func( runtime_path, ai_path )
	return function( file )
		if type(file) ~= 'string' then
			return nil
		end
		local ai_file = ai_path .. "/" .. file .. ".lua"
		local runtime_file = runtime_path .. "/" .. file .. ".lua"
		if VFS.FileExists(ai_file) then
			return VFS.Include(ai_file)
		elseif VFS.FileExists(runtime_file) then
			return VFS.Include(runtime_file)
		end
		Spring.Echo( "Failed to load "..ai_file.." or "..runtime_file )
		return nil
	end
end

-- the default shard include function, only deals with the runtime files for boot up
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
	"spring_lua/unit",
	"spring_lua/unittype",
	"spring_lua/damage",
	"spring_lua/feature",
	"spring_lua/controlpoint"
}


for key,include in ipairs(runtime_includes) 
do
	local result = shard_include( include )
end
