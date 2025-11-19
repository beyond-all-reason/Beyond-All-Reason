local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "UnitCallinsWidget",
		desc = "Draws and echos each widget callin for debugging",
		author = "Beherith",
		date = "2022.02.14",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false,
	}
end



-- Localized functions for performance
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spEcho = Spring.Echo

-- UNIT CALLINS:
local showcallins = true
local printcallins = true
local enabledcallins = {
	UnitCreated = true,
	UnitFinished = true,
	UnitFromFactory = true,
	UnitDestroyed = true,
	UnitDestroyedByTeam = true,
	UnitTaken = true,
	UnitExperience = true,
	UnitCommand = true,
	UnitCmdDone = true,
	UnitDamaged = true,
	UnitGiven = true,
	UnitIdle = true,
	UnitEnteredRadar = true,
	UnitEnteredLos = true,
	UnitLeftRadar = true,
	UnitLeftLos = true,
	UnitEnteredWater = true,
	UnitEnteredAir = true,
	UnitLeftWater = true,
	UnitLeftAir = true,
	UnitSeismicPing = true,
	UnitLoaded = true,
	UnitUnloaded = true,
	UnitCloaked = true, 
	UnitDecloaked = true,
	UnitMoveFailed = true,
	StockpileChanged  = true,
	RenderUnitDestroyed  = true,
	FeatureCreated = true,
	FeatureDestroyed = true,
	MetaUnitAdded = true,
	MetaUnitRemoved = true,
	}
local taglife = 5 * 30
local tagrise = 2
local eventlist = {}
local numevents = 0
local startheight = 64
	-- is a dict of
	-- life = gameframe to die on
	-- 

local function addEvent(unitID,callin, param1, param2, param3, param4)
	if unitID == nil then return end
	local px, py, pz 
	if type(unitID) == 'table' then 
		px = unitID[1]
		py = unitID[2]
		pz = unitID[3]
	elseif Spring.ValidUnitID(unitID) then 
		px, py, pz = Spring.GetUnitPosition(unitID)
	end
	if px == nil then return end 
	local caption = 'w:'..callin
	if param1 ~= nil then caption = caption .. " " .. tostring(param1) end 
	if param2 ~= nil then caption = caption .. " " .. tostring(param2) end 
	if param3 ~= nil then caption = caption .. " " .. tostring(param3) end 
	if param4 ~= nil then caption = caption .. " " .. tostring(param4) end 
	local newevent = {
		life = spGetGameFrame() + taglife,
		caption = caption,
		x = px ,
		y = py + startheight,
		z = pz + (math.random()-0.5) * 32,
	}
	tableInsert(eventlist, newevent)
	numevents = numevents + 1
end

function widget:GameFrame()
	local gf = spGetGameFrame()
	local removelist = {}
	for k, v in pairs(eventlist) do 
		if v.life < gf then 
			tableInsert(removelist, k) 
		else
			v.y = v.y + tagrise
		end
	end
	for k,v in pairs(removelist) do 
		eventlist[v] = nil
		numevents = numevents - 1
	end
end

function widget:DrawWorld()
	--spEcho("w:drawing:", numevents)
	if numevents > 0 then 
		gl.Color(1,1,1,1)
		for key, event in pairs(eventlist) do 
			if Spring.IsSphereInView(event.x, event.y, event.z, 128) then 
				gl.PushMatrix()
				gl.Translate(event.x, event.y, event.z)
				gl.Text( event.caption,0,0,16,'n')
				gl.PopMatrix()
			end
			
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if printcallins then spEcho("w:UnitCreated",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, builderID) end 
	if enabledcallins.UnitCreated == nil then return end
	if showcallins then addEvent(unitID, "UnitCreated")	end
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitFinished == nil then return end
	if printcallins then spEcho("w:UnitFinished",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitFinished") end
end

function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	if enabledcallins.UnitFromFactory == nil then return end
	if printcallins then spEcho("w:UnitFromFactory",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, factID, factDefID, userOrders) end 
	if showcallins then addEvent(unitID, "UnitFromFactory") end

end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if enabledcallins.UnitDestroyed == nil then return end
	if printcallins then spEcho("w:UnitDestroyed",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitDestroyed") end 
end

function widget:UnitDestroyedByTeam(unitID, unitDefID, unitTeam, attackerTeamID)
	if enabledcallins.UnitDestroyedByTeam == nil then return end
	if printcallins then spEcho("w:UnitDestroyedByTeam",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, attackerTeamID) end
	if showcallins then addEvent(unitID, "UnitDestroyedByTeam") end 
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if enabledcallins.UnitTaken == nil then return end
	if printcallins then spEcho("w:UnitTaken",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, newTeam) end
	if showcallins then addEvent(unitID, "UnitTaken") end 
end
function widget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	if enabledcallins.UnitExperience == nil then return end
	if printcallins then spEcho("w:UnitExperience",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, experience, oldExperience) end
	if showcallins then addEvent(unitID, "UnitExperience") end 
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if enabledcallins.UnitCommand == nil then return end
	if printcallins then spEcho("w:UnitCommand",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua) end
	if showcallins then addEvent(unitID, "UnitCommand") end 
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if enabledcallins.UnitCmdDone == nil then return end
	if printcallins then spEcho("w:UnitCmdDone",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag) end
	if showcallins then addEvent(unitID, "UnitCmdDone") end 
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if enabledcallins.UnitDamaged == nil then return end
	if printcallins then spEcho("w:UnitDamaged",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, damage, paralyzer) end
	if showcallins then addEvent(unitID, "UnitDamaged") end 
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	if enabledcallins.UnitGiven == nil then return end
	if printcallins then spEcho("w:UnitGiven",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, oldTeam) end
	if showcallins then addEvent(unitID, "UnitGiven") end 
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitIdle == nil then return end
	if printcallins then spEcho("w:UnitIdle",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitIdle") end 
end

function widget:UnitEnteredRadar(unitID, unitTeam)
	if enabledcallins.UnitEnteredRadar == nil then return end
	if printcallins then spEcho("w:UnitEnteredRadar",unitID, unitTeam) end
	if showcallins then addEvent(unitID, "UnitEnteredRadar") end 
end

function widget:UnitEnteredLos(unitID, unitTeam)
	if enabledcallins.UnitEnteredLos == nil then return end
	if printcallins then spEcho("w:UnitEnteredLos",unitID, unitTeam) end
	if showcallins then addEvent(unitID, "UnitEnteredLos") end 
end

function widget:UnitLeftRadar(unitID, unitTeam)
	if enabledcallins.UnitLeftRadar == nil then return end
	if printcallins then spEcho("w:UnitLeftRadar",unitID, unitTeam) end
	if showcallins then addEvent(unitID, "UnitLeftRadar") end 
end

function widget:UnitLeftLos(unitID, unitTeam)
	if enabledcallins.UnitLeftLos == nil then return end
	if printcallins then spEcho("w:UnitLeftLos",unitID, unitTeam) end
	if showcallins then addEvent(unitID, "UnitLeftLos") end 
end

function widget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitEnteredWater == nil then return end
	if printcallins then spEcho("w:UnitEnteredWater",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitEnteredWater") end 
end

function widget:UnitEnteredAir(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitEnteredAir == nil then return end
	if printcallins then spEcho("w:UnitEnteredAir",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitEnteredAir") end 
end

function widget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitLeftWater == nil then return end
	if printcallins then spEcho("w:UnitLeftWater",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitLeftWater") end 
end

function widget:UnitLeftAir(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitLeftAir == nil then return end
	if printcallins then spEcho("w:UnitLeftAir",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitLeftAir") end 
end

function widget:UnitSeismicPing(x, y, z, strength)
	if enabledcallins.UnitSeismicPing == nil then return end
	if printcallins then spEcho("w:UnitSeismicPing",x, y, z, strength) end
	--if showcallins then addEvent(unitID, "UnitGiven") end 
end

function widget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if enabledcallins.UnitLoaded == nil then return end
	if printcallins then spEcho("w:UnitLoaded",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, transportID, transportTeam) end
	if showcallins then addEvent(unitID, "UnitLoaded") end 
end

function widget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if enabledcallins.UnitUnloaded == nil then return end
	if printcallins then spEcho("w:UnitUnloaded",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, transportID, transportTeam) end
	if showcallins then addEvent(unitID, "UnitUnloaded") end 
end

function widget:UnitCloaked(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitCloaked == nil then return end
	if printcallins then spEcho("w:UnitCloaked",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitCloaked") end 
end

function widget:UnitDecloaked(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitDecloaked == nil then return end
	if printcallins then spEcho("w:UnitDecloaked",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitDecloaked") end 
end

function widget:UnitMoveFailed(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitMoveFailed == nil then return end
	if printcallins then spEcho("w:UnitMoveFailed",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitMoveFailed") end 
end

function widget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	if enabledcallins.StockpileChanged == nil then return end
	if printcallins then spEcho("w:StockpileChanged",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, weaponNum, oldCount, newCount) end
	if showcallins then addEvent(unitID, "StockpileChanged") end 
end


function widget:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	if enabledcallins.RenderUnitDestroyed == nil then return end
	if printcallins then spEcho("w:RenderUnitDestroyed",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "RenderUnitDestroyed") end 
end

function widget:FeatureCreated(featureID)
	if enabledcallins.FeatureCreated == nil then return end
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if printcallins then spEcho("w:FeatureCreated",featureID, FeatureDefs[featureDefID].name) end
	if showcallins then 	
		local fx, fy, fz = Spring.GetFeaturePosition(featureID)
		local pos = {fx,fy,fz}
		addEvent(pos, "FeatureCreated") 
	end 
end

function widget:FeatureDestroyed(featureID)
	if enabledcallins.FeatureDestroyed == nil then return end
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if printcallins then spEcho("w:FeatureDestroyed",featureID, FeatureDefs[featureDefID].name) end
	if showcallins then 	
		local fx, fy, fz = Spring.GetFeaturePosition(featureID)
		local pos = {fx,fy,fz}
		addEvent(pos, "FeatureDestroyed") 
	end 
end

function widget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if enabledcallins.MetaUnitAdded == nil then return end
	if printcallins then spEcho("w:MetaUnitAdded",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "MetaUnitAdded") end
end

function widget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	if enabledcallins.MetaUnitRemoved == nil then return end
	if printcallins then spEcho("w:MetaUnitRemoved",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "MetaUnitRemoved") end
end

local function init()
end

function widget:PlayerChanged(playerID)
end

function widget:Initialize()
	init()
end

function widget:Shutdown()
end

function widget:GetConfigData(data)
	return {}
end

function widget:SetConfigData(data)
end
