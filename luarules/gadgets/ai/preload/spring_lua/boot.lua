-- initial setup of things

function shard_include( file )
	if type(file) ~= 'string' then
		return nil
	end
	subdir = Game.gameShortName
	if Game.gameShortName == "BAR" then
		-- AI for BA / BAR is (atm) the same
		subdir = "BA"
	end

	local gameFile = "luarules/gadgets/ai/" ..  subdir .. "/" .. file .. ".lua"
	local baseFile = "luarules/gadgets/ai/" .. file .. ".lua"
	local preloadFile = "luarules/gadgets/ai/preload/" .. file .. ".lua"
	if VFS.FileExists(gameFile) then
		-- Spring.Echo("got gameFile", gameFile)
		return VFS.Include(gameFile)
	elseif VFS.FileExists(baseFile) then
		-- Spring.Echo("got baseFile", baseFile)
		return VFS.Include(baseFile)
	elseif VFS.FileExists(preloadFile) then
		-- Spring.Echo("got preloadFile", preloadFile)
		return VFS.Include(preloadFile)
	end
end

shard_include "preload/spring_lua/shard"
os = shard_include "preload/spring_lua/fakeos"
api = shard_include "preload/spring_lua/fakeapi"
shard_include "preload/hooks"
shard_include "preload/class"
shard_include "preload/aibase"
shard_include "preload/module"
shard_include "preload/spring_lua/unit"
shard_include "preload/spring_lua/unittype"
shard_include "preload/spring_lua/damage"
shard_include "preload/spring_lua/feature"
shard_include "preload/spring_lua/controlpoint"
