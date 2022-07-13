
function gadget:GetInfo()
	return {
		name		= "Xmas effects",
		desc		= "Adds unit explosion xmas-balls and places candycanes randomly on the map",
		author		= "Floris",
		date		= "October 2017",
		license		= "",
		layer		= 0,
		enabled		= true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local decorationUdefIDs = {}
local decorationUdefIDlist = {}
for udefID,def in ipairs(UnitDefs) do
	if def.name == 'xmasball' or def.name == 'xmasball2' then
		decorationUdefIDlist[#decorationUdefIDlist+1] = udefID
		decorationUdefIDs[udefID] = true
	end
end


local maxDecorations = 200
local candycaneAmount = math.ceil((Game.mapSizeX*Game.mapSizeZ)/2000000)
local candycaneSnowMapMult = 2.5
local addGaiaBalls = false	-- if false, only own team colored balls are added

local enableUnitDecorations = true		-- burst out xmas ball after unit death
for _,teamID in ipairs(Spring.GetTeamList()) do
	if select(4,Spring.GetTeamInfo(teamID,false)) then	-- is AI?
		enableUnitDecorations = false
	end
end

local isComWreck = {}
local xmasComwreckDefID
for fdefID,def in ipairs(FeatureDefs) do
	if def.name == "armcom_dead" or def.name == "corcom_dead" then
		isComWreck[fdefID] = true
	end
	if def.name == "xmascomwreck" then
		xmasComwreckDefID = fdefID
	end
end

local costSettings = {
	{0, 0, 0},
	{40, 1, 0.7},
	{100, 1, 0.8},
	{200, 1, 0.9},
	{350, 2, 0.9},
	{600, 2, 1},
	{900, 3, 1.05},
	{1200, 3, 1.15},
	{1500, 4, 1.15},
	{2000, 4, 1.25},
	{2500, 5, 1.25},
	{4000, 6, 1.35},
	{7000, 7, 1.45},
	{12000, 8, 1.55},
	{20000, 9, 1.7},
}
local isBuilder = {}
local unitSize = {}
local unitRadius = {}
local hasDecoration = {}
for udefID,def in ipairs(UnitDefs) do
	if def.isBuilder then
		isBuilder[udefID] = true
	end
	unitSize[udefID] = { ((def.xsize*8)+8)/2, ((def.zsize*8)+8)/2 }
	unitRadius[udefID] = def.radius
	if not def.isAirUnit and not def.modCategories["ship"] and not def.modCategories["hover"] and not def.modCategories["underwater"] and not def.modCategories["object"] then
		if def.mass >= 35 then
			local balls = math.floor(((def.radius-13) / 7.5))
			local cost = def.metalCost + (def.energyCost/100)
			local impulse = 0.37
			local radius = 0.8
			for _,v in ipairs(costSettings) do
				if cost > v[1] then
					balls = v[2]
					radius = v[3] --+ impulse
					impulse = impulse + (radius/1.7)
				else
					break
				end
			end
			if balls > 0 then
				hasDecoration[udefID] = {balls, impulse, 30*14, radius}
			end
		end
	end
	if def.customParams.iscommander ~= nil then
		hasDecoration[udefID] = {28, 9, 30*22, 1, true} -- always shows decorations for commander even if maxDecorations is reached
	end
end

_G.itsXmas = false

local decorationCount = 0
local decorations = {}
local decorationsTerminal = {}
local createDecorations = {}
local createdDecorations = {}
local candycanes = {}
local gaiaTeamID = Spring.GetGaiaTeamID()
local random = math.random
local GetGroundHeight = Spring.GetGroundHeight
local receivedPlayerXmas = {}
local receivedPlayerCount = 0
local initiated

VFS.Include("luarules/configs/map_biomes.lua")

function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,4)=="xmas" then
		if receivedPlayerXmas[playerID] == nil then
			receivedPlayerCount = receivedPlayerCount + 1
			receivedPlayerXmas[playerID] = (msg:sub(5,6) == '1' and true or false)
		end
	end
end

function initiateXmas()
	if not initiated then
		initiated = true

		if snowKeywords then
			local currentMapname = Game.mapName:lower()
			for _,keyword in pairs(snowKeywords) do
				if string.find(currentMapname, keyword, nil, true) then
					candycaneAmount = math.floor(candycaneAmount * candycaneSnowMapMult)
					break
				end
			end
		end

		-- spawn candy canes
		for i=1, candycaneAmount do
			local x = random(0, Game.mapSizeX)
			local z = random(0, Game.mapSizeZ)
			local groundType, groundType2 = Spring.GetGroundInfo(x,z)
			if (type(groundType) == 'string' and groundType ~= "void" or groundType2 ~= "void") then	-- 105 compatibility
				local y = GetGroundHeight(x, z)
				local caneType = math.ceil(random(1,7))
				local featureID = Spring.CreateFeature('candycane'..caneType,x,y,z,random(0,360))
				Spring.SetFeatureRotation(featureID, random(-12,12), random(-12,12), random(-180,180))
				candycanes[featureID] = caneType
			end
		end
	end
end

_G.xmasDecorations = {}

local function setGaiaUnitSpecifics(unitID)
	Spring.SetUnitNeutral(unitID, true)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitStealth(unitID, true)
	Spring.SetUnitNoMinimap(unitID, true)
	--Spring.SetUnitMaxHealth(unitID, 2)
	Spring.SetUnitBlocking(unitID, true, true, false, false, true, false, false)
	Spring.SetUnitSensorRadius(unitID, 'los', 0)
	Spring.SetUnitSensorRadius(unitID, 'airLos', 0)
	Spring.SetUnitSensorRadius(unitID, 'radar', 0)
	Spring.SetUnitSensorRadius(unitID, 'sonar', 0)
	for weaponID, _ in pairs(UnitDefs[Spring.GetUnitDefID(unitID)].weapons) do
		Spring.UnitWeaponHoldFire(unitID, weaponID)
	end
end

function gadget:GameFrame(n)

	if n % 30 == 1 then
		for unitID, frame in pairs(decorations) do
			if frame < n then
				decorations[unitID] = nil
				local x,y,z = Spring.GetUnitPosition(unitID)
				local gy = Spring.GetGroundHeight(x,z)

				decorationsTerminal[unitID] = n+random(0,50)+225+((y - gy) * 33)		-- allows if in sea to take longer to go under seafloor
				if decorationsTerminal[unitID] > n+1500 then	-- limit time
					decorationsTerminal[unitID] = n+1500
				end
				local env = Spring.UnitScript.GetScriptEnv(unitID)
				Spring.UnitScript.CallAsUnit(unitID,env.Sink)
			end
		end
	end
	if n % 90 == 1 then

		for unitID, frame in pairs(decorationsTerminal) do

			if frame < n then
				decorationsTerminal[unitID] = nil
				if Spring.GetUnitIsDead(unitID) == false then
					Spring.DestroyUnit(unitID, false, false)
				end
			end
		end
	end

	-- add destroyed unit decorations
	if enableUnitDecorations then
		for _, data in ipairs(createDecorations) do
			local i = 0
			local uID
			local amount = hasDecoration[data[5]][1]
			while i < amount do
				local teamID = data[4]
				if addGaiaBalls and random() > 0.5 then
					teamID = gaiaTeamID
				end
				local decorationDefID = decorationUdefIDlist[math.floor(1 + (math.random() * (#decorationUdefIDlist-0.001)))]
				uID = Spring.CreateUnit(decorationDefID, data[1],data[2],data[3], 0, teamID)
				if uID ~= nil then
					decorationCount = decorationCount + 1
					decorations[uID] = Spring.GetGameFrame() + hasDecoration[data[5]][3] + (random()*(hasDecoration[data[5]][3]*0.33))
					Spring.SetUnitRotation(uID,random()*360,random()*360,random()*360)
					local impulseMult = hasDecoration[data[5]][2]
					Spring.AddUnitImpulse(uID, (random()-0.5)*(impulseMult/2), 1+(random()*impulseMult), (random()-0.5)*(impulseMult/2))
				end
				i = i + 1
			end
		end
		createDecorations = {}
	end

	-- add gifted unit decorations
	for _, unitID in ipairs(createdDecorations) do
		if decorations[unitID] == nil then
			decorationCount = decorationCount + 1
			decorations[unitID] = Spring.GetGameFrame() + 600 + (random()*300)
			setGaiaUnitSpecifics(unitID)
			Spring.SetUnitRotation(unitID,random()*360,random()*360,random()*360)
			Spring.AddUnitImpulse(unitID, (random()-0.5)*2, 3.8+(random()*1), (random()-0.5)*2)
		end
	end
	createdDecorations = {}
end

function gadget:FeatureCreated(featureID, allyTeam)
	if _G.itsXmas then
		-- replace comwreck with xmas comwreck
		if isComWreck[Spring.GetFeatureDefID(featureID)] then
			local px,py,pz = Spring.GetFeaturePosition(featureID)
			local rx,ry,rz = Spring.GetFeatureRotation(featureID)
			local dx,dy,dz = Spring.GetFeatureDirection(featureID)
			Spring.DestroyFeature(featureID)
			local xmasFeatureID = Spring.CreateFeature(xmasComwreckDefID, px,py,pz)
			if xmasFeatureID then
				Spring.SetFeatureRotation(xmasFeatureID, rx,ry,rz)
				Spring.SetFeatureDirection(xmasFeatureID, dx,dy,dz)
				local comtype = 'armcom'
				if string.find(FeatureDefs[Spring.GetFeatureDefID(featureID)].modelname:lower(), 'corcom', nil, true) then
					comtype = 'corcom'
				end
				Spring.SetFeatureResurrect(xmasFeatureID, comtype, "s", 0)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if not _G.itsXmas then
		return
	end
	if decorationUdefIDs[unitDefID] then
		if decorations[unitID] ~= nil then
			decorations[unitID] = nil
		elseif decorationsTerminal[unitID] ~= nil then
			decorationsTerminal[unitID] = nil
		end
		decorationCount = decorationCount - 1
	elseif attackerID ~= nil then --and (not _G.destroyingTeam or not _G.destroyingTeam[select(6,Spring.GetTeamInfo(teamID,false))]) then	-- is not reclaimed and not lastcom death chain ripple explosion
		if enableUnitDecorations and hasDecoration[unitDefID] ~= nil and (decorationCount < maxDecorations or hasDecoration[unitDefID][5]) then

			local _,_,_,_,buildProgress=Spring.GetUnitHealth(unitID)
			if buildProgress and buildProgress == 1 then	-- exclude incompleted nanoframes
				local x,y,z = Spring.GetUnitPosition(unitID)
				createDecorations[#createDecorations+1] = {x,y,z, teamID, unitDefID }
				--Spring.Echo(hasDecoration[unitDefID][1])
			end
		end
	end
end


function gadget:UnitGiven(unitID, unitDefID, unitTeam)
	if decorationUdefIDs[unitDefID] then
		setGaiaUnitSpecifics(unitID)
	end
end

-- prevents area targetting xmasballs
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if decorationUdefIDs[unitDefID] then
		setGaiaUnitSpecifics(unitID)
	end
	if cmdID and cmdID == CMD.ATTACK then
		if cmdParams and #cmdParams == 1 then
			if decorationUdefIDs[Spring.GetUnitDefID(cmdParams[1])] then
				return false
			end
		end
	end
	-- remove any xmasball that is blocking queued build order
	if cmdID < 0 and cmdParams[3] and isBuilder[Spring.GetUnitDefID(unitID)] then
		local udefid = math.abs(cmdID)
		local units = Spring.GetUnitsInBox(cmdParams[1]-unitSize[udefid][1],cmdParams[2]-200,cmdParams[3]-unitSize[udefid][2],cmdParams[1]+unitSize[udefid][1],cmdParams[2]+50,cmdParams[3]+unitSize[udefid][2])
		for i=1, #units do
			if decorationUdefIDs[Spring.GetUnitDefID(units[i])] then
				if Spring.GetUnitIsDead(units[i]) == false then
					Spring.DestroyUnit(units[i], false, false)
					decorations[units[i]] = nil
					decorationsTerminal[units[i]] = nil
					createdDecorations[units[i]] = nil
				end
			end
		end
	end
	return true
end

function gadget:GameStart()
	if not _G.itsXmas then
		local xmasRatio = 0
		for playerID, xmas in pairs(receivedPlayerXmas) do
			if xmas then
				xmasRatio = xmasRatio + (1/receivedPlayerCount)
			end
		end
		if xmasRatio > 0.75 then
			_G.itsXmas = true
			initiateXmas()
		else
			return
		end
	end
end
