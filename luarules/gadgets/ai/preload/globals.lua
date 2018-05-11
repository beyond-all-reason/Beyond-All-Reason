-- Created by Tom J Nowell 2010
-- Shard AI
if ShardSpringLua then
	function shard_include( file )
		if type(file) ~= 'string' then
			return nil
		end
		local gameFile = "luarules/gadgets/ai/" ..  Game.gameShortName .. "/" .. file .. ".lua"
		local baseFile = "luarules/gadgets/ai/" .. file .. ".lua"
		local preloadFile = "luarules/gadgets/ai/preload/" .. file .. ".lua"
		if VFS.FileExists(gameFile) then
			return VFS.Include(gameFile)
		elseif VFS.FileExists(baseFile) then
			return VFS.Include(baseFile)
		elseif VFS.FileExists(preloadFile) then
			return VFS.Include(preloadFile)
		end
	end
else
	function shard_include( file )
		if type(file) ~= 'string' then
			return nil
		end
		local ok1, mod1 = pcall( require, game_engine:GameName().."/"..file )
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
end

shard_include "hooks"
shard_include "class"
shard_include "aibase"

if ShardSpringLua then
	shard_include "spring_lua/unit"
	shard_include "spring_lua/unittype"
	shard_include "spring_lua/damage"
	shard_include "spring_lua/feature"
	shard_include "spring_lua/controlpoint"
else
	shard_include "spring_native/unit"
	shard_include "spring_native/unittype"
end