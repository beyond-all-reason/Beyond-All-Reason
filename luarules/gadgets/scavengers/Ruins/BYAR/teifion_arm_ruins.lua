local function teifion_arm_aa_ruin1(posx, posy, posz, GaiaTeamID, radiusCheck)
  local posradius = 124
  if radiusCheck then
    return posradius
  else
SpawnRuin("armpb", posx+(88), posy, posz+(88), 1)
SpawnRuin("armpb", posx+(88), posy, posz+(-88), 1)
SpawnRuin("armmercury", posx+(0), posy, posz+(-96), 1)
SpawnRuin("armmercury", posx+(0), posy, posz+(96), 1)
SpawnRuin("armmercury", posx+(96), posy, posz+(0), 1)
SpawnRuin("armgate", posx+(0), posy, posz+(0), 1)
SpawnRuin("armpb", posx+(-88), posy, posz+(88), 1)
SpawnRuin("armmercury", posx+(-96), posy, posz+(0), 1)
SpawnRuin("armpb", posx+(-88), posy, posz+(-88), 1)
  end
end
table.insert(RuinsList,teifion_arm_aa_ruin1)

local function teifion_arm_bunker_ruin1(posx, posy, posz, GaiaTeamID, radiusCheck)
  local posradius = 68
  if radiusCheck then
    return posradius
  else
SpawnRuin("armhlt", posx+(0), posy, posz+(52), 1)
SpawnRuin("armflak", posx+(48), posy, posz+(4), 1)
SpawnRuin("armflak", posx+(-48), posy, posz+(4), 1)
SpawnRuin("armjuno", posx+(0), posy, posz+(-60), 1)
SpawnRuin("armsd", posx+(0), posy, posz+(4), 1)
  end
end
table.insert(RuinsList,teifion_arm_bunker_ruin1)

local function teifion_arm_watchpost_ruin1(posx, posy, posz, GaiaTeamID, radiusCheck)
  local posradius = 90
  if radiusCheck then
    return posradius
  else
SpawnRuin("armarad", posx+(-14), posy, posz+(28), 1)
SpawnRuin("armtarg", posx+(-6), posy, posz+(-12), 1)
SpawnRuin("armuwadvms", posx+(-78), posy, posz+(-20), 1)
SpawnRuin("armuwadves", posx+(82), posy, posz+(-20), 1)
SpawnRuin("armveil", posx+(18), posy, posz+(28), 1)
  end
end
table.insert(RuinsList,teifion_arm_watchpost_ruin1)

local function teifion_arm_metal_maker_ruin1(posx, posy, posz, GaiaTeamID, radiusCheck)
  local posradius = 88
  if radiusCheck then
    return posradius
  else
SpawnRuin("armmmkr", posx+(-66), posy, posz+(0), 3)
SpawnRuin("armmmkr", posx+(-2), posy, posz+(0), 1)
SpawnRuin("armckfus", posx+(70), posy, posz+(0), 2)
  end
end
table.insert(RuinsList,teifion_arm_metal_maker_ruin1)

local function teifion_arm_silo_ruin1(posx, posy, posz, GaiaTeamID, radiusCheck)
  local posradius = 160
  if radiusCheck then
    return posradius
  else
SpawnRuin("armllt", posx+(-99), posy, posz+(-147), 1)
SpawnRuin("armllt", posx+(-67), posy, posz+(157), 1)
SpawnRuin("armllt", posx+(109), posy, posz+(157), 1)
SpawnRuin("armsilo", posx+(-27), posy, posz+(5), 3)
SpawnRuin("armllt", posx+(109), posy, posz+(-163), 1)
SpawnRuin("armbrtha", posx+(189), posy, posz+(-3), 1)
SpawnRuin("armllt", posx+(-211), posy, posz+(-3), 1)
  end
end
table.insert(RuinsList,teifion_arm_silo_ruin1)

local function teifion_arm_afus_ruin1(posx, posy, posz, GaiaTeamID, radiusCheck)
  local posradius = 124
  if radiusCheck then
    return posradius
  else
SpawnRuin("armgate", posx+(-132), posy, posz+(5), 1)
SpawnRuin("armamb", posx+(84), posy, posz+(-131), 1)
SpawnRuin("armanni", posx+(140), posy, posz+(5), 1)
SpawnRuin("armamb", posx+(-92), posy, posz+(125), 1)
SpawnRuin("armamb", posx+(84), posy, posz+(125), 1)
SpawnRuin("armamb", posx+(-92), posy, posz+(-131), 1)
SpawnRuin("armafus", posx+(12), posy, posz+(5), 1)
  end
end
table.insert(RuinsList,teifion_arm_afus_ruin1)
