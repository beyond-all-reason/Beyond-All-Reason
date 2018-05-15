-- @TODO: Move top level logic out of ai.lua into here, and then make it load environment specific boot.lua files

if not ShardSpringLua then
	-- globals
	require("preload/globals")
end

require( "ai.lua" )

-- create and use an AI
if ShardSpringLua then
	return AI()
else
	ai = AI()
end
