-- thrusters should be done by lups, maybe we'll apply smoke via this ceg

local definitions = {

  ["thruster-medium"] = {
    --smoke = {
    --  air                = true,
    --  class              = [[CSimpleParticleSystem]],
    --  count              = 1,
    --  ground             = true,
    --  water              = true,
    --  properties = {
    --    airdrag            = 0.84,
    --    colormap           = [[0.06 0.053 0.053 0.18   0.085 0.078 0.078 0.2   0.034 0.03 0.03 0.1  0 0 0 0]],
    --    directional        = false,
    --    emitrot            = 0,
    --    emitrotspread      = 10,
    --    emitvector         = [[dir]],
    --    gravity            = [[0, 0, 0]],
    --    numparticles       = 10,
    --    particlelife       = 55,
    --    particlelifespread = 15,
    --    particlesize       = 2,
    --    particlesizespread = 2,
    --    particlespeed      = 0,
    --    particlespeedspread = 2.5,
    --    pos                = [[0, 1, 3]],
    --    sizegrowth         = 0.03,
    --    sizemod            = 1.0,
    --    texture            = [[smoke]],
    --  },
    --},
  },
}


function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--local size = 0.4
--definitions["barrelshot-tiny"] = deepcopy(definitions["barrelshot-medium"])
--definitions["barrelshot-tiny"].fire.properties.length									= definitions["barrelshot-tiny"].fire.properties.length * size
--definitions["barrelshot-tiny"].fire.properties.size										= definitions["barrelshot-tiny"].fire.properties.size * size
--definitions["barrelshot-tiny"].fire.properties.ttl										= 3
--definitions["barrelshot-tiny"].fire2.properties.length								= definitions["barrelshot-tiny"].fire2.properties.length * size
--definitions["barrelshot-tiny"].fire2.properties.size									= definitions["barrelshot-tiny"].fire2.properties.size * size
--definitions["barrelshot-tiny"].fire2.properties.ttl										= 3
--definitions["barrelshot-tiny"].fireglow.properties.particlesize				= definitions["barrelshot-tiny"].fireglow.properties.particlesize * size
--definitions["barrelshot-tiny"].fireglow.properties.particlelife				= 2.5 + definitions["barrelshot-tiny"].fireglow.properties.particlelife * size
--definitions["barrelshot-tiny"].fireglow.properties.colormap       		= [[0.122 0.066 0.013 0.05   0 0 0 0.01]]
--definitions["barrelshot-tiny"].smoke																	= nil
--definitions["barrelshot-tiny"].smoke2																	= nil


return definitions