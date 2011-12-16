function gadget:GetInfo()
  return {
    name      = "Air Release",
    desc      = "Adds falling damage = falling height * mass / 50",
    author    = "Pako",
    date      = "21 Feb 2010",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if (not gadgetHandler:IsSyncedCode()) then
  return
end

local COMMANDO = UnitDefNames["commando"].id

local fC = 0
local fallingUnits = {}

function gadget:GameFrame(n)
  if fC > 0 then
    for k,t in ipairs(fallingUnits) do
		local unitAlive = (Spring.ValidUnitID (t[1]) and (not Spring.GetUnitIsDead (t[1]))) --+++
		if (unitAlive) then						--++
			x,y,z = Spring.GetUnitBasePosition(t[1])		--maybe check if units were off map		
			h = Spring.GetGroundHeight(x,z)
		--else
			--Spring.Echo ("unit was not alive anymore. There would have been error spam")
		end
		if (not unitAlive or h > y-10)  then			--+++
		  Spring.AddUnitDamage(t[1], t[2])
		  table.remove(fallingUnits,k)
		  fC = fC - 1
		end
    end
  end
end

function gadget:UnitUnloaded(unitID, unitDefID, _, transID)
	if unitDefID ~= COMMANDO then
		local x,y,z = Spring.GetUnitBasePosition(unitID)
		local h = Spring.GetGroundHeight(x,z)
		local damage = 0
		if (y-h) > 25 then
			local Udef = UnitDefs[unitDefID]
			damage = Udef.mass * (y-h)/50
		elseif (y-h) > 5 then
			damage = ((y-h)*25)
		end
		if damage > 10 then 
			fC = fC + 1
			--Spring.Echo(y-h, damage)
			fallingUnits[fC] = {unitID, damage}
		end
	end	
end
