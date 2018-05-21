local game = {}
	--game_engine

	-- prints 'message' to ingame chat console
	function game:SendToConsole(...)
		local str = ""
		local parts = {...}
		for i = 1, #parts do
			local part = parts[i]
			str = str .. tostring(part)
			if i < #parts then str = str .. ", " end
		end
		return game_engine:SendToConsole(str)
	end

	function game:Frame() -- returns int/game frame number
		return game_engine:Frame() -- Shard AI API
	end

	function game:Test() -- debug
		return game_engine:Test()
	end

	function game:IsPaused() -- if the game is paused, returns true
		--
		return game_engine:IsPaused()
	end

	function game:GetTypeByName(typename) -- returns unittype
		--
		return game_engine:GetTypeByName(typename)
	end


	function game:ConfigFolderPath() -- returns string with path to the folder
		--
		return game_engine:ConfigFolderPath()
	end

	function game:ReadFile(filename) -- returns string with file contents
		--
		return game_engine:ReadFile(filename)
	end

	function game:FileExists(filename) -- returns boolean
		--
		return game_engine:FileExists(filename)
	end

	function game:GetTeamID() -- returns boolean
		--
		return game_engine:GetTeamID()
	end

	function game:GetEnemies()
		local has_enemies = game_engine:HasEnemies()
		if has_enemies ~= true then
			return nil
		else
			local ev = game_engine:GetEnemies()
			local e = {}
			local i = 0
			while i  < ev:size() do
				table.insert(e,ev[i])
				i = i + 1
			end
			ev = nil
			return e
		end
	end

	function game:GetUnits()
		local fv = game_engine:GetUnits()
		local f = {}
		local i = 0
		while i  < fv:size() do
			table.insert(f,fv[i])
			i = i + 1
		end
		fv = nil
		return f
	end

	function game:GetFriendlies()
		local has_friendlies = game_engine:HasFriendlies()
		if has_friendlies ~= true then
			return nil
		else
			local fv = game_engine:GetFriendlies()
			local f = {}
			local i = 0
			while i  < fv:size() do
				table.insert(f,fv[i])
				i = i + 1
			end
			fv = nil
			return f
		end
	end

	function game:GameName() -- returns the shortname of this game
		--
		return game_engine:GameName()
	end

	function game:AddMarker(position,label) -- adds a marker
		--
		return game_engine:AddMarker(position,label)
	end

	function game:SendToContent(stringvar) -- returns a string passed from any lua gadgets
		--
		return game_engine:SendToContent(stringvar)
	end

	function game:GetResource(idx) --  returns a Resource object
		return game_engine:GetResource(idx)
	end

	function game:GetResourceCount() -- return the number of resources
		return game_engine:GetResourceCount()
	end

	function game:GetResourceByName(name) -- returns a Resource object, takes the name of the resource
		return game_engine:GetResourceByName(name)
	end

	function game:GetUnitByID( unit_id ) -- returns a Shard unit when given an engine unit ID number
		return game_engine:getUnitByID( unit_id )
	end

	function game:GetResources() -- returns a table of Resource objects, takes the name of the resource
		local rcount = game_engine:GetResourceCount()
		if(rcount > 0) then

			local resources = {}

			for i = 0,rcount do
				local res = game:GetResource(i)
				if res.name ~= "" then
					resources[res.name] = res
				end
			end
			return resources
		else
			return nil
		end
	end

	function game:UsesControlPoints()
		return map:AreControlPoints()
	end

	function game:ControlPointCaptureRadius()
		return 500
	end

	function game:ControlPointNonCapturingUnits()
		return {}
	end

return game