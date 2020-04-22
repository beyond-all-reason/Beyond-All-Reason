-- @TODO: Move top level logic out of ai.lua into here, and then make it load environment specific boot.lua files

if ShardSpringLua then
	-- VFS.Include( "luarules/gadgets/ai/shard_runtime/spring_lua/boot.lua" )
elseif game_engine then
	require "spring_cpp/boot"
else
	require "shard_runtime/shard_null/boot"
end

shard_include( "ai" )

-- create and use an AI
if ShardSpringLua then
	return STAI()
elseif game_engine then
	ai = STAI()
else
	ai = STAI()
	ai:Init()
end
