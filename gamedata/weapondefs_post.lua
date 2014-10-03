--------------------------------------------------------------------------------
-- Default Engine Weapon Definitions Post-processing
--------------------------------------------------------------------------------

local function isbool(x)   return (type(x) == 'boolean') end
local function istable(x)  return (type(x) == 'table')   end
local function isnumber(x) return (type(x) == 'number')  end
local function isstring(x) return (type(x) == 'string')  end

local function tobool(val)
  local t = type(val)
  if (t == 'nil') then
    return false
  elseif (t == 'boolean') then
    return val
  elseif (t == 'number') then
    return (val ~= 0)
  elseif (t == 'string') then
    return ((val ~= '0') and (val ~= 'false'))
  end
  return false
end


--------------------------------------------------------------------------------

local function ProcessUnitDef(udName, ud)

  local wds = ud.weapondefs
  if (not istable(wds)) then
    return
  end

  -- add this unitDef's weaponDefs
  for wdName, wd in pairs(wds) do
    if (isstring(wdName) and istable(wd)) then
      local fullName = udName .. '_' .. wdName
      WeaponDefs[fullName] = wd
    end
  end

  -- convert the weapon names
  local weapons = ud.weapons
  if (istable(weapons)) then
    for i = 1, 32 do
      local w = weapons[i]
      if (istable(w)) then
        if (isstring(w.def)) then
          local ldef = string.lower(w.def)
          local fullName = udName .. '_' .. ldef
          local wd = WeaponDefs[fullName]
          if (istable(wd)) then
            w.name = fullName
          end
        end
        w.def = nil
      end
    end
  end

  -- convert the death explosions
  if (isstring(ud.explodeas)) then
    local fullName = udName .. '_' .. ud.explodeas
    if (WeaponDefs[fullName]) then
      ud.explodeas = fullName
    end
  end
  if (isstring(ud.selfdestructas)) then
    local fullName = udName .. '_' .. ud.selfdestructas
    if (WeaponDefs[fullName]) then
      ud.selfdestructas = fullName
    end
  end
end

--------------------------------------------------------------------------------

-- Process the unitDefs
local UnitDefs = DEFS.unitDefs

for udName, ud in pairs(UnitDefs) do
  if (isstring(udName) and istable(ud)) then
    ProcessUnitDef(udName, ud)
  end
end



--------------------------------------------------------------------------------
-- BA Weapon Definitions Post-processing
--------------------------------------------------------------------------------
local explosiveWeapons = {
	MissileLauncher = true,
	StarburstLauncher = true,
	TorpedoLauncher = true,
	Cannon = true,
	AircraftBomb = true,
}
local inertialessWeapons = {
	LaserCannon = true,
	BeamLaser = true,
	EmgCannon = true,
	Flame = true,
	LightningCannon = true,
}

-- local modOptions = Spring.GetModOptions() -- this crashes the mission editor and is not actually used here.

for id in pairs(WeaponDefs) do
	-- Adjustment of terrain damage, kinetic force of weapons, and add water hit sounds
	WeaponDefs[id].soundhitwet = ""
	if explosiveWeapons[WeaponDefs[id].weapontype] then
		if WeaponDefs[id].weapontype == "TorpedoLauncher" then
			WeaponDefs[id].soundhitwet = WeaponDefs[id].soundhitdry
		else
			local AoE = tonumber(WeaponDefs[id].areaofeffect) or 0
			if AoE<50 then
				WeaponDefs[id].soundhitwet = "splshbig"
				WeaponDefs[id].soundhitwetvolume = 0.5
			elseif AoE<88 then
				WeaponDefs[id].soundhitwet = "splssml"
				WeaponDefs[id].soundhitwetvolume = 0.5
			elseif AoE<145 then
				WeaponDefs[id].soundhitwet = "splsmed"
				WeaponDefs[id].soundhitwetvolume = 0.5
			elseif AoE>450 then
				WeaponDefs[id].soundhitwet = WeaponDefs[id].soundhitdry
			else
				WeaponDefs[id].soundhitwet = "splslrg"
				WeaponDefs[id].soundhitwetvolume = 0.5
			end
		end
	else
		WeaponDefs[id].soundhitwet = "sizzle"
		WeaponDefs[id].soundhitwetvolume = 0.5
	end
	if inertialessWeapons[WeaponDefs[id].weapontype] then
		WeaponDefs[id].impulseboost = 0
		WeaponDefs[id].impulsefactor = 0
	end

	if WeaponDefs[id].cratermult then 
		WeaponDefs[id].cratermult = WeaponDefs[id].cratermult * 0.4
	else
		WeaponDefs[id].cratermult = 0.4
	end
	if WeaponDefs[id].craterboost then
		WeaponDefs[id].craterboost = WeaponDefs[id].craterboost * 0.4
	else
		WeaponDefs[id].craterboost = 0
	end
    if not WeaponDefs[id].craterareaofeffect then
        WeaponDefs[id].craterareaofeffect = (tonumber(WeaponDefs[id].areaofeffect) or 0)
    end
    
    -- don't affect ground for tiny explosions (-> don't cause PFS updates pointlessly)
    if WeaponDefs[id].craterareaofeffect <= 64 then
        WeaponDefs[id].craterareaofeffect = 0
		WeaponDefs[id].cratermult = 0
		WeaponDefs[id].craterboost = 0
    end
    
	if WeaponDefs[id].weapontype == "BeamLaser" then
		WeaponDefs[id].soundhitdry = ""
		WeaponDefs[id].soundtrigger = 1
	end
	
	-- don't let features get in the way of firing, except commandos minelayer weapon
	if WeaponDefs[id].name ~= "commando_minelayer" then 
		WeaponDefs[id].avoidfeature = false
	end
end