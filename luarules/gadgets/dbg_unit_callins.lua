local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "UnitCallinsGadget",
		desc = "Draws and echos each gadget callin for debugging, enable with /luarules unitcallinsgadget",
		author = "Beherith",
		date = "2022.02.14",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then return end


-- UNIT CALLINS:
local showcallins = true
local printcallins = true
local enabled = false
local enabledcallins = {}
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
	local caption = 'g:'..callin
	if param1 ~= nil then caption = caption .. " " .. tostring(param1) end
	if param2 ~= nil then caption = caption .. " " .. tostring(param2) end
	if param3 ~= nil then caption = caption .. " " .. tostring(param3) end
	if param4 ~= nil then caption = caption .. " " .. tostring(param4) end
	local newevent = {
		life = Spring.GetGameFrame() + taglife,
		caption = caption,
		x = px ,
		y = py + startheight,
		z = pz + (math.random()-0.5) * 32,
	}
	table.insert(eventlist, newevent)
	numevents = numevents + 1
end

function gadget:GameFrame()
	if numevents > 0 then
		local gf = Spring.GetGameFrame()
		local removelist = {}
		for k, v in pairs(eventlist) do
			if v.life < gf then
				table.insert(removelist, k)
			else
				v.y = v.y + tagrise
			end
		end
		for k,v in pairs(removelist) do
			eventlist[v] = nil
			numevents = numevents - 1
		end
	end
end

function gadget:DrawWorld()
	--Spring.Echo("g:drawing:", numevents)
	if numevents > 0 then
		gl.Color(0.3,1,0.3,1)
		for key, event in pairs(eventlist) do
			if Spring.IsSphereInView(event.x, event.y, event.z, 128) then
				gl.PushMatrix()
				local w = gl.GetTextWidth(event.caption) * 16.0
				gl.Translate(event.x - w, event.y, event.z)
				gl.Text( event.caption,0,0,16,'n')
				gl.PopMatrix()
			end

		end
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if enabledcallins.UnitCreated == nil then return end
	if printcallins then Spring.Echo("g:UnitCreated",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, builderID) end
	if showcallins then addEvent(unitID, "UnitCreated")	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitFinished == nil then return end
	if printcallins then Spring.Echo("g:UnitFinished",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitFinished") end
end

function gadget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	if enabledcallins.UnitFromFactory == nil then return end
	if printcallins then Spring.Echo("g:UnitFromFactory",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, factID, factDefID, userOrders) end
	if showcallins then addEvent(unitID, "UnitFromFactory") end

end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if enabledcallins.UnitDestroyed == nil then return end
	if printcallins then Spring.Echo("g:UnitDestroyed",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitDestroyed") end
end

function gadget:UnitReverseBuilt(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitReverseBuilt == nil then return end
	if printcallins then Spring.Echo("g:UnitReverseBuilt",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitReverseBuilt") end
end

function gadget:UnitDestroyedByTeam(unitID, unitDefID, unitTeam, attackerTeamID)
	if enabledcallins.UnitDestroyedByTeam == nil then return end
	if printcallins then Spring.Echo("g:UnitDestroyedByTeam",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, attackerTeamID) end
	if showcallins then addEvent(unitID, "UnitDestroyedByTeam") end
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
	if enabledcallins.UnitTaken == nil then return end
	if printcallins then Spring.Echo("g:UnitTaken",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, newTeam) end
	if showcallins then addEvent(unitID, "UnitTaken") end
end
function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	if enabledcallins.UnitExperience == nil then return end
	if printcallins then Spring.Echo("g:UnitExperience",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, experience, oldExperience) end
	if showcallins then addEvent(unitID, "UnitExperience") end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if enabledcallins.UnitCommand == nil then return end
	if printcallins then Spring.Echo("g:UnitCommand",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua) end
	if showcallins then addEvent(unitID, "UnitCommand") end
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdTag, cmdParams, cmdOpts)
	if enabledcallins.UnitCmdDone == nil then return end
	if printcallins then Spring.Echo("g:UnitCmdDone",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, cmdID, cmdTag, cmdParams, cmdOpts) end
	if showcallins then addEvent(unitID, "UnitCmdDone") end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if enabledcallins.UnitDamaged == nil then return end
	if printcallins then Spring.Echo("g:UnitDamaged",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, damage, paralyzer) end
	if showcallins then addEvent(unitID, "UnitDamaged") end
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
	if enabledcallins.UnitGiven == nil then return end
	if printcallins then Spring.Echo("g:UnitGiven",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, oldTeam) end
	if showcallins then addEvent(unitID, "UnitGiven") end
end

function gadget:UnitIdle(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitIdle == nil then return end
	if printcallins then Spring.Echo("g:UnitIdle",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitIdle") end
end

function gadget:UnitEnteredRadar(unitID, unitTeam)
	if enabledcallins.UnitEnteredRadar == nil then return end
	if printcallins then Spring.Echo("g:UnitEnteredRadar",unitID, unitTeam) end
	if showcallins then addEvent(unitID, "UnitEnteredRadar") end
end

function gadget:UnitEnteredLos(unitID, unitTeam)
	if enabledcallins.UnitEnteredLos == nil then return end
	if printcallins then Spring.Echo("g:UnitEnteredLos",unitID, unitTeam) end
	if showcallins then addEvent(unitID, "UnitEnteredLos") end
end

function gadget:UnitLeftRadar(unitID, unitTeam)
	if enabledcallins.UnitLeftRadar == nil then return end
	if printcallins then Spring.Echo("g:UnitLeftRadar",unitID, unitTeam) end
	if showcallins then addEvent(unitID, "UnitLeftRadar") end
end

function gadget:UnitLeftLos(unitID, unitTeam)
	if enabledcallins.UnitLeftLos == nil then return end
	if printcallins then Spring.Echo("g:UnitLeftLos",unitID, unitTeam) end
	if showcallins then addEvent(unitID, "UnitLeftLos") end
end

function gadget:UnitEnteredWater(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitEnteredWater == nil then return end
	if printcallins then Spring.Echo("g:UnitEnteredWater",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitEnteredWater") end
end

function gadget:UnitEnteredAir(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitEnteredAir == nil then return end
	if printcallins then Spring.Echo("g:UnitEnteredAir",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitEnteredAir") end
end

function gadget:UnitLeftWater(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitLeftWater == nil then return end
	if printcallins then Spring.Echo("g:UnitLeftWater",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitLeftWater") end
end

function gadget:UnitLeftAir(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitLeftAir == nil then return end
	if printcallins then Spring.Echo("g:UnitLeftAir",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitLeftAir") end
end

function gadget:UnitSeismicPing(x, y, z, strength)
	if enabledcallins.UnitSeismicPing == nil then return end
	if printcallins then Spring.Echo("g:UnitSeismicPing",x, y, z, strength) end
	--if showcallins then addEvent(unitID, "UnitGiven") end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if enabledcallins.UnitLoaded == nil then return end
	if printcallins then Spring.Echo("g:UnitLoaded",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, transportID, transportTeam) end
	if showcallins then addEvent(unitID, "UnitLoaded") end
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
	if enabledcallins.UnitUnloaded == nil then return end
	if printcallins then Spring.Echo("g:UnitUnloaded",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, transportID, transportTeam) end
	if showcallins then addEvent(unitID, "UnitUnloaded") end
end

function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitCloaked == nil then return end
	if printcallins then Spring.Echo("g:UnitCloaked",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitCloaked") end
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	if enabledcallins.UnitDecloaked == nil then return end
	if printcallins then Spring.Echo("g:UnitDecloaked",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "UnitDecloaked") end
end

--function gadget:UnitMoveFailed(unitID, unitDefID, unitTeam)
--	if enabledcallins.UnitMoveFailed == nil then return end
--	if printcallins then Spring.Echo("g:UnitMoveFailed",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
--	if showcallins then addEvent(unitID, "UnitMoveFailed") end
--end

function gadget:StockpileChanged(unitID, unitDefID, unitTeam, weaponNum, oldCount, newCount)
	if enabledcallins.StockpileChanged == nil then return end
	if printcallins then Spring.Echo("g:StockpileChanged",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam, weaponNum, oldCount, newCount) end
	if showcallins then addEvent(unitID, "StockpileChanged") end
end

function gadget:RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	if enabledcallins.RenderUnitDestroyed == nil then return end
	if printcallins then Spring.Echo("g:RenderUnitDestroyed",unitID, unitDefID and UnitDefs[unitDefID].name, unitTeam) end
	if showcallins then addEvent(unitID, "RenderUnitDestroyed") end
end

function gadget:UnitUnitCollision(colliderID, collideeID)
	if enabledcallins.UnitUnitCollision == nil then return end
	if printcallins then Spring.Echo("g:UnitUnitCollision",colliderID, collideeID) end
	if showcallins then addEvent(colliderID, "UnitUnitCollision") end
end

function gadget:UnitFeatureCollision(colliderID, collideeID)
	if enabledcallins.UnitFeatureCollision == nil then return end
	if printcallins then Spring.Echo("g:UnitFeatureCollision",colliderID, collideeID) end
	if showcallins then addEvent(colliderID, "UnitFeatureCollision") end
end

function gadget:UnitFeatureCollision(colliderID, collideeID)
	if enabledcallins.UnitFeatureCollision == nil then return end
	if printcallins then Spring.Echo("g:UnitFeatureCollision",colliderID, collideeID) end
	if showcallins then addEvent(colliderID, "UnitFeatureCollision") end
end

function gadget:FeatureCreated(featureID)
	if enabledcallins.FeatureCreated == nil then return end
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if printcallins then Spring.Echo("g:FeatureCreated",featureID, FeatureDefs[featureDefID].name) end
	if showcallins then
		local fx, fy, fz = Spring.GetFeaturePosition(featureID)
		local pos = {fx,fy,fz}
		addEvent(pos, "FeatureCreated")
	end
end

function gadget:FeatureDestroyed(featureID)
	if enabledcallins.FeatureDestroyed == nil then return end
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if printcallins then Spring.Echo("g:FeatureDestroyed",featureID, FeatureDefs[featureDefID].name) end
	if showcallins then
		local fx, fy, fz = Spring.GetFeaturePosition(featureID)
		local pos = {fx,fy,fz}
		addEvent(pos, "FeatureDestroyed")
	end
end

local function togglegadget()
	enabled = not enabled
	Spring.Echo("UnitCallinsGadget toggled to:", enabled)
	if enabled == false then
		enabledcallins = {}
	else
		enabledcallins = {
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
			UnitReverseBuilt  = true,
			UnitUnitCollision  = true,
			UnitFeatureCollision  = true,
			FeatureCreated = true,
			FeatureDestroyed = true,
		}
	end
end

function gadget:Initialize()
	gadgetHandler:AddChatAction('unitcallinsgadget', togglegadget)
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction('unitcallinsgadget')
end

function gadget:GetConfigData(data)
	return {}
end

function gadget:SetConfigData(data)
end
