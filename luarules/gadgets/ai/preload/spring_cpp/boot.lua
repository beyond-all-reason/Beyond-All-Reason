-- initial setup of things

function shard_include( file )
	if type(file) ~= 'string' then
		return nil
	end
	local gameName = game_engine:GameName()
	local ok1
	local mod1
	if gameName == 'BAR' then
		ok1, mod1 = pcall( require, "BA/"..file )
	else
		ok1, mod1 = pcall( require, gameName.."/"..file )
	end
	if ok1 then
		return mod1
	else
		local ok2, mod2 = pcall( require, file )
		if ok2 then
			return mod2
		else
			game_engine:SendToConsole("require can't load " .. game_engine:GameName().."/"..file .. " error: " .. mod1)
			game_engine:SendToConsole("require can't load " .. file .. " error: " .. mod2)
		end
	end
end

shard_include "hooks"
shard_include "class"
shard_include "aibase"
shard_include "module"

shard_include "preload/spring_cpp/unit"
shard_include "preload/spring_cpp/unittype"