local game = {}
--game_engine

-- prints 'message' to ingame chat console
function game:SendToConsole(...)
	print( ... )
	return true
end

function game:Frame() -- returns int/game frame number
	return 0
end

function game:Test() -- debug
	print( "Testing API" )
	return true
end

function game:IsPaused() -- if the game is paused, returns true
	return true
end

function game:GetTypeByName(typename) -- returns unittype
	return nil
end

function game:ConfigFolderPath() -- returns string with path to the folder
	return "luarules/gadgets/ai/" .. self:GameName() .. "/"
	-- return game_engine:ConfigFolderPath()
end

function game:ReadFile(filename) -- returns string with file contents
	return '' -- @TODO: Implement core lua IO
end

function game:FileExists(filename) -- returns boolean
	return false -- @TODO: Implement core lua IO
end

function game:GetTeamID()
	return 0
end

function game:GetEnemies()
	return {}
end

function game:GetUnits()
	return {}
end

function game:GetFriendlies()
	return {}
end

function game:GameName() -- returns the shortname of this game
	return "nullgame"
end

function game:AddMarker(position,label) -- adds a marker
	return false
end

function game:SendToContent(stringvar) -- returns a string passed from any lua gadgets
	return false
end

function game:GetResource(idx) --  returns a Resource object
	return Shard:shardify_resource({currentLevel=0, storage=0, pull=0, income=0, expense=0, share=0, sent=0, received=0})
end

function game:GetResourceCount() -- return the number of resources
	return 0
end

function game:GetResourceByName(name) -- returns a Resource object, takes the name of the resource
	return Shard:shardify_resource({currentLevel=0, storage=0, pull=0, income=0, expense=0, share=0, sent=0, received=0})
end

function game:GetUnitByID( unit_id ) -- returns a Shard unit when given an engine unit ID number
	return
end

function game:GetResources() -- returns a table of Resource objects, takes the name of the resource
	return {}
end

function game:UsesControlPoints()
	return false
end

function game:ControlPointCaptureRadius()
	return 0
end

function game:ControlPointNonCapturingUnits()
	return {}
end

return game
