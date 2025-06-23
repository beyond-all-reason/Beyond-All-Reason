if not Spring.GetModOptions().xmas then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name		= "Xmas effects",
		desc		= "Adds unit explosion xmas-balls and places candycanes randomly on the map",
		author		= "Floris",
		date		= "October 2017",
		license     = "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= true,
	}
end

_G.itsXmas = true

local decorationUdefIDs = {}
local decorationUdefIDlist = {}
local decorationSizes = {}
for udefID,def in ipairs(UnitDefs) do
	if string.sub(def.name, 1, 8) == 'xmasball' then
		decorationUdefIDlist[#decorationUdefIDlist+1] = udefID
		decorationUdefIDs[udefID] = true
		local size = tonumber(string.sub(def.name, 11))
		if size then
			if not decorationSizes[size] then
				decorationSizes[size] = {}
			end
			decorationSizes[size][#decorationSizes[size]+1] = udefID
		end
	end
end

-------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	local uniformcache = {0}
	function gadget:UnitCreated(unitID, unitDefID)
		if decorationUdefIDs[unitDefID] then
			uniformcache[1] = math.random() * 0.6 - 0.25
			gl.SetUnitBufferUniforms(unitID, uniformcache, 9)
		end
	end
	return
end
-------------------------------------------------------------------------------

local maxDecorations = 400
local candycaneAmount = math.ceil((Game.mapSizeX*Game.mapSizeZ)/1800000)
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
	if def.name == "armcom_dead" or def.name == "corcom_dead" or def.name == "legcom_dead" or def.name == "legcomlvl2_dead" or def.name == "legcomlvl3_dead" or def.name == "legcomlvl4_dead" then
		isComWreck[fdefID] = true
	end
	if def.name == "xmascomwreck" then
		xmasComwreckDefID = fdefID
	end
end

local costSettings = {
	{0, 0, 1},
	{40, 1, 1},
	{100, 1, 1},
	{200, 1, 2},
	{350, 2, 2},
	{600, 2, 2},
	{900, 3, 3},
	{1200, 3, 3},
	{1500, 4, 3},
	{2000, 4, 4},
	{2500, 5, 4},
	{4000, 6, 5},
	{7000, 7, 5},
	{12000, 8, 6},
	{20000, 9, 6},
}
local hasDecoration = {}
for udefID,def in ipairs(UnitDefs) do
	if not def.isAirUnit and not def.modCategories["ship"] and not def.modCategories["hover"] and not def.modCategories["underwater"] and not def.modCategories["object"] then
		if def.mass >= 35 then
			local balls = math.floor(((def.radius-13) / 7.5))
			local cost = def.metalCost + (def.energyCost/100)
			local impulse = 0.5
			local radius = 0.8
			for _,v in ipairs(costSettings) do
				if cost > v[1] then
					balls = v[2]
					radius = v[3] --+ impulse
					impulse = impulse + (radius/#decorationSizes)
				else
					break
				end
			end
			if balls > 0 then
				hasDecoration[udefID] = {balls, impulse, 30*20, radius}
			end
		end
	end
	if def.customParams.iscommander ~= nil then
		hasDecoration[udefID] = {28, 9, 30*33, 1, true} -- always shows decorations for commander even if maxDecorations is reached
	end
end

local decorationCount = 0
local decorations = {}
local decorationsTerminal = {}
local createDecorations = {}
local createdDecorations = {}
local gaiaTeamID = Spring.GetGaiaTeamID()
local random = math.random
local GetGroundHeight = Spring.GetGroundHeight
local initiated

VFS.Include("luarules/configs/map_biomes.lua")

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

		-- spawn candy canes (if not already done)
		local detectedCandycane = false
		local allfeatures = Spring.GetAllFeatures()
		for i, featureID in ipairs(allfeatures) do
			local featureDefID = Spring.GetFeatureDefID(featureID)
			if string.find(FeatureDefs[featureDefID].name, 'candycane') then
				detectedCandycane = true
				break
			end
		end
		if not detectedCandycane then
			for i=1, candycaneAmount do
				local x = random(0, Game.mapSizeX)
				local z = random(0, Game.mapSizeZ)
				local y = GetGroundHeight(x, z)
				if y > 5 then
					local groundType, groundType2 = Spring.GetGroundInfo(x,z)
					if (type(groundType) == 'string' and groundType ~= "void" or groundType2 ~= "void") then	-- 105 compatibility
						local caneType = math.ceil(random(1,7))
						local featureID = Spring.CreateFeature('candycane'..caneType,x,y,z,random(0,360))
						Spring.SetFeatureRotation(featureID, random(-12,12), random(-12,12), random(-180,180))
					end
				end
			end
		end
	end
end

function gadget:GameFrame(n)

	if n % 30 == 1 then
		for unitID, frame in pairs(decorations) do
			if frame < n then
				decorations[unitID] = nil
				local x,y,z = Spring.GetUnitPosition(unitID)
				if x then
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
	end
	if n % 90 == 1 then
		for unitID, frame in pairs(decorationsTerminal) do
			if frame < n then
				decorationsTerminal[unitID] = nil
				if Spring.GetUnitIsDead(unitID) == false then
					Spring.DestroyUnit(unitID, false, true)
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
				local size = math.clamp(math.floor((hasDecoration[data[5]][4])), 1, #decorationSizes)	-- retrieve max size
				size = math.min(size, (math.ceil((size*0.35) + (math.random() * (size*0.65)))))	-- pick a size
				local decorationDefID = decorationSizes[size][math.floor(1 + (math.random() * (#decorationSizes[size]-0.001)))]	-- pick one of 2 variants/textured baubles
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
		if not decorations[unitID] then
			decorationCount = decorationCount + 1
			decorations[unitID] = Spring.GetGameFrame() + 2000 + (random()*1000)
			Spring.SetUnitRotation(unitID,random()*360,random()*360,random()*360)
			--Spring.AddUnitImpulse(unitID, (random()-0.5)*2, 3.8+(random()*1), (random()-0.5)*2)
			local impulseMult = 80
			Spring.AddUnitImpulse(unitID, (random()-0.5)*(impulseMult/3), 1+(random()*(impulseMult/1.6)), (random()-0.5)*(impulseMult/3))
		end
	end
	createdDecorations = {}
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if decorationUdefIDs[unitDefID] then
		createdDecorations[#createdDecorations+1] = unitID
	end
end

function gadget:FeatureCreated(featureID, allyTeam)
	-- replace comwreck with xmas comwreck
	if isComWreck[Spring.GetFeatureDefID(featureID)] then
		local px,py,pz = Spring.GetFeaturePosition(featureID)
		local rx,ry,rz = Spring.GetFeatureRotation(featureID)
		local dx,dy,dz = Spring.GetFeatureDirection(featureID)
		local heading = Spring.GetFeatureHeading(featureID)
		local teamID = Spring.GetFeatureTeam(featureID)
		Spring.DestroyFeature(featureID)
		local xmasFeatureID = Spring.CreateFeature(xmasComwreckDefID, px, py, pz, heading, teamID)
		if xmasFeatureID then
			Spring.SetFeatureRotation(xmasFeatureID, rx,ry,rz)
			Spring.SetFeatureDirection(xmasFeatureID, dx,dy,dz)
			local featureResurrect = Spring.GetFeatureResurrect(featureID)
			Spring.SetFeatureResurrect(xmasFeatureID, featureResurrect, "s", 0)
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if decorationUdefIDs[unitDefID] then
		if decorations[unitID] ~= nil then
			decorations[unitID] = nil
		elseif decorationsTerminal[unitID] ~= nil then
			decorationsTerminal[unitID] = nil
		end
		decorationCount = decorationCount - 1
	elseif attackerID ~= nil then --and (not _G.destroyingTeam or not _G.destroyingTeam[select(6,Spring.GetTeamInfo(teamID,false))]) then	-- is not reclaimed and not lastcom death chain ripple explosion
		if enableUnitDecorations and hasDecoration[unitDefID] ~= nil and (decorationCount < maxDecorations or hasDecoration[unitDefID][5]) then

			local inProgress = Spring.GetUnitIsBeingBuilt(unitID)
			if not inProgress then	-- exclude incompleted nanoframes
				local x,y,z = Spring.GetUnitPosition(unitID)
				createDecorations[#createDecorations+1] = {x,y,z, teamID, unitDefID }
				--Spring.Echo(hasDecoration[unitDefID][1])
			end
		end
	end
end

function gadget:GameStart()
	initiateXmas()
end
