-- initial setup of things

function shard_include( file , subf)
	if type(file) ~= 'string' then
		return nil
	end
	subdir = Game.gameShortName	
	local curEnv = nil
	if subf then
		subdir = subdir.."/"..subf -- "BYAR/low/behaviourfactory.lua"
		curEnv = getfenv()
		curEnv.subf = subf
	end
	local gameFile = "luarules/gadgets/ai/" ..  subdir .. "/" .. file .. ".lua"
	local baseFile = "luarules/gadgets/ai/" .. file .. ".lua"
	local preloadFile = "luarules/gadgets/ai/shard_runtime/" .. file .. ".lua"
	if VFS.FileExists(gameFile) then
		return VFS.Include(gameFile, curEnv)
	elseif VFS.FileExists(baseFile) then
		return VFS.Include(baseFile)
	elseif VFS.FileExists(preloadFile) then
		return VFS.Include(preloadFile)
	end
end

shard_include "shard_runtime/spring_lua/shard"
os = shard_include "shard_runtime/spring_lua/fakeos"
api = shard_include "shard_runtime/spring_lua/fakeapi"
shard_include "shard_runtime/hooks"
shard_include "shard_runtime/class"
shard_include "shard_runtime/aibase"
shard_include "shard_runtime/module"
shard_include "shard_runtime/spring_lua/unit"
shard_include "shard_runtime/spring_lua/unittype"
shard_include "shard_runtime/spring_lua/damage"
shard_include "shard_runtime/spring_lua/feature"
shard_include "shard_runtime/spring_lua/controlpoint"
