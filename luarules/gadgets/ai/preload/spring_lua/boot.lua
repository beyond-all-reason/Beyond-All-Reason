-- initial setup of things

function shard_generate_include_func( preloadPath, path1, path2, path3 )
    return function( file)
        if type(file) ~= 'string' then
            return nil
        end
        local file1 = path1 .. "/" .. file .. ".lua"
        local file2 = path2 .. "/" .. file .. ".lua"
        local file3 = path3 .. "/" .. file .. ".lua"
        local preloadFile = preloadPath .. "/" .. file .. ".lua"
        if VFS.FileExists(file1) then
            return VFS.Include(file1, curEnv)
        elseif VFS.FileExists(file2) then
            return VFS.Include(file2)
        elseif VFS.FileExists(file3) then
            return VFS.Include(file3)
        elseif VFS.FileExists(preloadFile) then
            return VFS.Include(preloadFile)
        end
    end
end

function byar_hacky_include_shim( path )
	return function(file, subf)
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
		local gameFile = path .. "/" ..  subdir .. "/" .. file .. ".lua"
		local baseFile = path .. "/" .. file .. ".lua"
		local preloadFile = path .. "/preload/" .. file .. ".lua"
		if VFS.FileExists(gameFile) then
			return VFS.Include(gameFile, curEnv)
		elseif VFS.FileExists(baseFile) then
			return VFS.Include(baseFile)
		elseif VFS.FileExists(preloadFile) then
			return VFS.Include(preloadFile)
		end
	end
end
--shard_include = shard_generate_include_func( "luarules/gadgets/ai/preload", subdir, "luarules/gadgets/ai" )
shard_include = byar_hacky_include_shim("luarules/gadgets/ai/preload")

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
