function gadget:GetInfo()
  return {
    name      = "Hacky 87.0 submerged nanoframe workaround",
    desc      = "Uses fake units to allow torpedoes to target nanoframes", -- http://springrts.com/mantis/view.php?id=3017
    author    = "Google Frog",
    date      = "14 March 2012",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
    return
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local fakeUnitDefID = UnitDefNames["fakeunit"].id

local inBuildLinks = {}

local units = {count = 0, unitID = {}}
local thereIsStuffToDo = false

function gadget:UnitCreated(unitID, unitDefID, teamID)
	
	local x,y,z = Spring.GetUnitPosition(unitID)
	local height = Spring.GetGroundHeight(x,z)
	
	if height < 0 then
		thereIsStuffToDo = true
		units.count = units.count + 1
		units.unitID[units.count] = unitID
	end
end

function gadget:GameFrame(f)
	if thereIsStuffToDo then
		for i = 1, units.count do
			local unitID = units.unitID[i]
			if Spring.ValidUnitID(unitID) then
				local build = select(5, Spring.GetUnitHealth(unitID))
				if build ~= 1 then
					local x,y,z = Spring.GetUnitPosition(unitID)
					local teamID = Spring.GetUnitTeam(unitID)
					local height = math.min( math.max(Spring.GetGroundHeight(x,z)+2, y), -2)
					local fakeID = Spring.CreateUnit(fakeUnitDefID, x, height, z, 1, teamID)
					
					Spring.MoveCtrl.Enable(fakeID)
					Spring.MoveCtrl.SetPosition(fakeID, x, height, z)
					Spring.SetUnitNoMinimap(fakeID,true)
					Spring.SetUnitNoSelect(fakeID,true)
					Spring.SetUnitNoDraw(fakeID,true)
					--Spring.SetUnitSonarStealth(fakeID,true)
					Spring.SetUnitStealth(fakeID,true)
					
					inBuildLinks[unitID] = fakeID
				end
			end
		end
		thereIsStuffToDo = false
		units = {count = 0, unitID = {}}
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage)
	return unitDefID ~= fakeUnitDefID and damage or 0
end

function gadget:UnitFinished(unitID, unitDefID, teamID)
	if inBuildLinks[unitID] then
		Spring.DestroyUnit(inBuildLinks[unitID], true, true)
		inBuildLinks[unitID] = nil
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	if inBuildLinks[unitID] then
		Spring.DestroyUnit(inBuildLinks[unitID], true, true)
		inBuildLinks[unitID] = nil
	end
end