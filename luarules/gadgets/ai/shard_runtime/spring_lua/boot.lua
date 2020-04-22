-- initial setup of things

function shard_include(file)
	if type(file) ~= 'string' then
		return nil
	end
	local preloadFile = "luarules/gadgets/ai/shard_runtime/" .. file .. ".lua"
	if VFS.FileExists(preloadFile) then
		return VFS.Include(preloadFile)
	end
	Spring.Echo( "Failed to load "..preloadFile )
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
