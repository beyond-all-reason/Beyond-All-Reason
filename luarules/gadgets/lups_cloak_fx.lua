-- $Id: lups_manager.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	author:	jK
--
--	Copyright (C) 2007,2008.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- UNSYNCED ONLY
if gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------



function gadget:GetInfo()
	return {
		name		= "Lups Cloak FX",
		desc		= "",
		author		= "jK",
		date		= "Apr, 2008",
		license		= "GNU GPL, v2 or later",
		layer		= 10,
		enabled		= true,
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- speed ups + some table functions
--

--local tinsert = table.insert
local tinsert = function(tab, insert)
	tab[#tab+1] = insert
end

local type	= type
local pairs = pairs

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Lups	--// Lua Particle System
local particleIDs = {}
local initialized = false --// if LUPS isn't started yet, we try it once a gameframe later
local tryloading = 1		 --// try to activate lups if it isn't found

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	«« some basic functions »»
--

local supportedFxs = {}
local function fxSupported(fxclass)
	if (supportedFxs[fxclass]~=nil) then
		return supportedFxs[fxclass]
	else
		supportedFxs[fxclass] = Lups.HasParticleClass(fxclass)
		return supportedFxs[fxclass]
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	«« cloaked unit handling »»
--

local CloakedHitEffect = { class='UnitJitter',options={ life=50, pos={0,0,0}, enemyHit=true, repeatEffect=false} }
local CloakEffect = {
	{ class='UnitCloaker',options={ life=50 } },
	{ class='UnitJitter',options={ delay=24, life=math.huge } },
	{ class='Sound',options={ file="cloak",volume=0.9 } },
}
local EnemyCloakEffect = {
	{ class='UnitCloaker',options={ life=20 } },
	{ class='Sound',options={ file="cloak",volume=0.9 } },
}

local DecloakEffect	= {
	{ class='UnitCloaker',options={ inverse=true, life=50 } },
	{ class='UnitJitter',options={ life=24 } },
	{ class='Sound',options={ file="cloak",volume=0.9 } },
}
local EnemyDecloakEffect = {
	{ class='UnitCloaker',options={ inverse=true, life=60 } },
	{ class='Sound',options={ file="cloak",volume=0.9 } },
}

--[[ Units are actually decloaked when damaged so this part is not required
local function UnitDamaged(_,unitID,unitDefID,teamID)
	local allyTeamID = Spring.GetUnitAllyTeam(unitID)

	local LocalAllyTeamID
	local _, specFullView = Spring.GetSpectatingState()
	if (specFullView) then
		LocalAllyTeamID = allyTeamID
	else
		LocalAllyTeamID = Spring.GetLocalAllyTeamID()
	end

	if (Spring.GetUnitIsCloaked(unitID))and(allyTeamID~=LocalAllyTeamID) then

		if (particleIDs[unitID]) then
			for _,fxID in ipairs(particleIDs[unitID]) do
				Lups.RemoveParticles(fxID)
			end
		end

		particleIDs[unitID] = {}
		CloakedHitEffect.options.unit = unitID
		CloakedHitEffect.options.team = teamID
		CloakedHitEffect.options.unitDefID = unitDefID
		tinsert( particleIDs[unitID],Lups.AddParticles(CloakedHitEffect.class,CloakedHitEffect.options) )
	end
end
--]]

function gadget:UnitCloaked(unitID,unitDefID,teamID)
	local allyTeamID = Spring.GetUnitAllyTeam(unitID)

	local LocalAllyTeamID
	local _, specFullView = Spring.GetSpectatingState()
	if (specFullView) then
		LocalAllyTeamID = allyTeamID
	else
		LocalAllyTeamID = Spring.GetLocalAllyTeamID()
	end

	if (particleIDs[unitID]) then
		for i=1,#particleIDs[unitID] do
			Lups.RemoveParticles(particleIDs[unitID][i])
		end
	end
	particleIDs[unitID] = {}
	if (LocalAllyTeamID==allyTeamID) then
		if Lups then
			for i=1,#CloakEffect do
				local fx = CloakEffect[i]
				fx.options.unit			= unitID
				fx.options.unitDefID = unitDefID
				fx.options.team			= teamID
			fx.options.allyTeam	= allyTeamID
			tinsert( particleIDs[unitID],Lups.AddParticles(fx.class,fx.options) )
			end
		end
	else
		if Lups then
			for i=1,#EnemyCloakEffect do
				local fx = EnemyCloakEffect[i]
				fx.options.unit			= unitID
				fx.options.unitDefID = unitDefID
				fx.options.team			= teamID
				fx.options.allyTeam	= allyTeamID
				tinsert( particleIDs[unitID],Lups.AddParticles(fx.class,fx.options) )
			end
		end
	end

end

function gadget:UnitDecloaked(unitID,unitDefID,teamID)
	local allyTeamID = Spring.GetUnitAllyTeam(unitID)

	local LocalAllyTeamID
	local _, specFullView = Spring.GetSpectatingState()
	if (specFullView) then
		LocalAllyTeamID = allyTeamID
	else
		LocalAllyTeamID = Spring.GetLocalAllyTeamID()
	end

	if (particleIDs[unitID]) then
		for i=1,#particleIDs[unitID] do
			Lups.RemoveParticles(particleIDs[unitID][i])
		end
	end
	particleIDs[unitID] = {}
	if (LocalAllyTeamID==allyTeamID) then
		for i=1,#DecloakEffect do
			local fx = DecloakEffect[i]
			fx.options.unit			= unitID
			fx.options.unitDefID = unitDefID
			fx.options.team			= teamID
		fx.options.allyTeam	= allyTeamID
		tinsert( particleIDs[unitID],Lups.AddParticles(fx.class,fx.options) )
		end
	else
		for i=1,#EnemyDecloakEffect do
			local fx = EnemyDecloakEffect[i]
			fx.options.unit			= unitID
			fx.options.unitDefID = unitDefID
			fx.options.team			= teamID
		fx.options.allyTeam	= allyTeamID
		tinsert( particleIDs[unitID],Lups.AddParticles(fx.class,fx.options) )
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, teamID, oldTeamID)
	if (Spring.GetUnitIsCloaked(unitID)) then
		gadget:UnitCloaked(unitID,unitDefID,teamID)
	end
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	«« Unit Destroyed handling »»
--

function gadget:UnitDestroyed(unitID,unitDefID)
	if (particleIDs[unitID]) then
		local effects = particleIDs[unitID]
		for i=1,#effects do
			Lups.RemoveParticles(effects[i])
		end
		particleIDs[unitID] = nil
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:PlayerChanged(playerID)
	if (playerID == Spring.GetMyPlayerID()) then
		--// this should reset the cloak fx when becoming a spec
		--gadget.Update = ReinitializeUnitFX
		gadgetHandler:UpdateCallIn("Update")
	end
end

local function ReinitializeUnitFX()
	--// clear old FXs
	for _,unitFxIDs in pairs(particleIDs) do
		for i=1,#unitFxIDs do
			Lups.RemoveParticles(unitFxIDs[i])
		end		
	end
	particleIDs = {}

	--// initialize effects for existing units
	local allUnits = Spring.GetAllUnits();
	for i=1,#allUnits do
		local unitID		= allUnits[i]
		if (Spring.GetUnitIsCloaked(unitID)) then
			local unitDefID = Spring.GetUnitDefID(unitID)
			local teamID = Spring.GetUnitTeam(unitID)
			gadget:UnitCloaked(unitID,unitDefID,teamID)
		end
	end

	gadgetHandler:RemoveCallIn("Update")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Update()
	if (Spring.GetGameFrame()<1) then 
		return
	end

	Lups = GG['Lups']

	if (Lups) then
		initialized = true
	else
		return
	end

	gadget.Update = ReinitializeUnitFX
	gadgetHandler:UpdateCallIn("Update")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Shutdown()

	if (initialized) then
		for _,unitFxIDs in pairs(particleIDs) do
			for i=1,#unitFxIDs do
		Lups.RemoveParticles(unitFxIDs[i])
			end		
		end
		particleIDs = {}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

