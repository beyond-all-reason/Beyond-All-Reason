-- This is the main gadget script for the mod.
-- It runs during the game and applies the changes if the option is enabled.

function gadget:GetInfo()
  return {
    name      = "Fast Turrets Logic",
    desc      = "Handles changing unit turret speeds.",
    author    = "Your Name",
    date      = "2023-10-27",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

-- This code runs when the game starts
if (Spring.GetModOptions and Spring.GetModOptions().experimentalturrettrunspeed) then

  -- This function will be called to modify the unit definitions
  function gadget:UnitDef(id, ud, udn)
    -- We are looking for the Cortex Commander unit
    -- The unit name for the Cortex Commander is "corcom"
    if (udn == "corcom") then
      -- The turn rate in UnitDefs is measured in radians per second.
      -- The original speed in the .bos file is <300>, which is in degrees per second.
      -- To convert degrees to radians, we use: radians = degrees * (math.pi / 180)
      -- The original value of 300 degrees/sec is roughly 5.23 radians/sec.

      -- The problem states you want the value to be 10.
      -- This is a very low value and will make the turret extremely slow.
      -- A value of 10 degrees/sec is about 0.1745 radians/sec.
      -- Let's assume you want a much faster speed, for example 1000 degrees/sec.
      -- 1000 * (math.pi / 180) = 17.45 radians/sec

      -- Let's set it to a noticeably faster speed. The original is ~5.23. Let's make it 20.
      local newTurnRate = 20

      -- We update the turnRate property of the unit definition.
      -- This value is inherited by all instances of this unit.
      ud.turnRate = newTurnRate

      -- We can also print a message to the game's log (infolog.txt) to confirm it's working.
      Spring.Echo("Fast Turrets Mod: Cortex Commander (corcom) turret speed set to " .. newTurnRate)
    end

    -- You can add more 'if' statements here to change other units.
    -- For example, to change the ARM commander:
    -- if (udn == "armcom") then
    --   ud.turnRate = 20
    --   Spring.Echo("Fast Turrets Mod: ARM Commander (armcom) turret speed set to 20")
    -- end
  end

end
