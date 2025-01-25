function gadget:GetInfo()
	return {
		name      = "PopUpWaterStructures",
		desc      = "",
		author    = "TheFatController",
		date      = "26 May 2013",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (gadgetHandler:IsSyncedCode()) then


local POP_UP_UNITDEFS = {
	armptl = { unit = "armtl", waterLine = -10 },
	corptl = { unit = "cortl", waterLine = -10 },
	armptl_scav = { unit = "armtl_scav", waterLine = -10 },
	corptl_scav = { unit = "cortl_scav", waterLine = -10 },
}

local POP_UP_UNIT = {}
for unitDefName, popupunit in pairs(POP_UP_UNITDEFS) do 
	if UnitDefNames[unitDefName] and UnitDefNames[popupunit.unit] then 
		popupunit.unit = UnitDefNames[popupunit.unit].id
		POP_UP_UNIT[UnitDefNames[unitDefName].id] = popupunit
	end
end
POP_UP_UNITDEFS = nil

local PTL_COLLISION = WeaponDefNames.ptl_collision.id;

local popUps = {}

local math_max = math.max
local math_random = math.random

local function HeadingToFacing(heading)
	return ((heading + 8192) / 16384) % 4
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam)
  if (POP_UP_UNIT[unitDefID]) then
    popUps[unitID] = { velocity = 0.05, waterLine = POP_UP_UNIT[unitDefID].waterLine , process = false}
  end
end


function gadget:UnitFinished(unitID, unitDefID, unitTeam)
  if (POP_UP_UNIT[unitDefID]) and unitID and Spring.ValidUnitID(unitID) then
    Spring.MoveCtrl.Enable(unitID)
    popUps[unitID].process = true
  end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
    if (POP_UP_UNIT[unitDefID]) and unitID then
		popUps[unitID].process = false
	end
end

function gadget:GameFrame(n)
  for unitID, defs in pairs(popUps) do
	if defs.process == true then
		local x,y,z = Spring.GetUnitPosition(unitID)
		if (y > defs.waterLine) then
			local h = HeadingToFacing(Spring.GetUnitHeading(unitID))
			Spring.MoveCtrl.Disable(unitID)
			local newUnitID = Spring.CreateUnit(POP_UP_UNIT[Spring.GetUnitDefID(unitID)].unit,x,0,z,h,Spring.GetUnitTeam(unitID))
			if newUnitID then
				local cmds = Spring.GetCommandQueue(unitID,20)
				for i=1,#cmds do
					local cmd = cmds[i]
					Spring.GiveOrderToUnit(newUnitID, cmd.id, cmd.params, cmd.options.coded)
				end
				Spring.SetUnitHealth(newUnitID, select(1,Spring.GetUnitHealth(unitID)))
				Spring.DestroyUnit(unitID, false, true)

				Spring.SpawnCEG("splash-tiny",x,-5,z,0,0,0)
				SendToUnsynced("splashsound", x,y,z)
				popUps[unitID].process = false
				local collisions = Spring.GetUnitsInSphere(x,0,z,35)
				for i=1,#collisions do
					local colUnitID    = collisions[i]
					if (colUnitID ~= newUnitID) and (colUnitID ~= unitID) then
						Spring.SpawnProjectile(PTL_COLLISION, { ["pos"] = {x,0,z}, ["end"] = {x,0,z} })
					end
				end
				collisions = Spring.GetFeaturesInSphere(x,0,z,35)
				for i=1,#collisions do
					local colFeatureID    = collisions[i]
					Spring.SpawnProjectile(PTL_COLLISION, { ["pos"] = {x,0,z}, ["end"] = {x,0,z} })
					if Spring.ValidFeatureID(colFeatureID) then
						Spring.DestroyFeature(colFeatureID)
					end
				end
		  end
		else
			Spring.MoveCtrl.SetRelativeVelocity(unitID,0,defs.velocity,0)
			popUps[unitID].velocity = math_max(defs.velocity * 1.05, 1.75)
			if math_random() > 0.8 then
				Spring.SpawnCEG("small_water_bubbles",x,y,z,0,1,0)
			end
		end
	end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
else -- UNSYNCED ---------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:Initialize()
  gadgetHandler:AddSyncAction("splashsound", SplashSound)
end

function SplashSound(_,x,y,z)
  if (Spring.IsPosInLos(x,y,z)) then
    Spring.PlaySoundFile("splslrg", ((Spring.GetConfigInt("snd_volmaster") or 100) / 100), x,y,z, 'ui')
  end
end

end
