local function GetUnitSpawnHeight(unit)
    if unit.y then
      return unit.y
    end
  
    return Spring.GetGroundHeight(unit.x, unit.y)
  end -- defining height with unit.y Variable 
--ships have y=0
    if is.ship or is.aircraft then
    return unit.y
     else
        return GetGroundHeight(unit.x, unit.z)
    end
-- to use declareted unit.y for ships and aircrafts only that need it to be on land/water or in air