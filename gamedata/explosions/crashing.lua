local definitions = {
    ["crashing-small"] = {
        smoke = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            properties = {
                airdrag            = 0.91,
                colormap           = [[0.17 0.12 0.1 0.35   0.14 0.12 0.1 0.4   0.125 0.115 0.11 0.3   0.075 0.075 0.075 0.2   0.042 0.042 0.042 0.11    0.02 0.02 0.02 0.05   0 0 0 0.01]],
                directional        = true,
                emitrot            = -180,
                emitrotspread      = 30,
                emitvector         = [[dir]],
                gravity            = [[0.0, -0.03, 0.0]],
                numparticles       = 1,
                particlelife       = 60,
                particlelifespread = 60,
                particlesize       = 3.2,
                particlesizespread = 4.2,
                particlespeed      = 0.4,
                particlespeedspread = 2,
                pos                = [[-5 r10, -5 r10, -5 r10]],
                sizegrowth         = 0.1,
                sizemod            = 1,
                texture            = [[dirt]],
                useairlos          = true,
            },
        },
        dustparticles = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            underwater         = true,
            water              = true,
            properties = {
                airdrag            = 0.8,
                colormap           = [[0.66 0.5 0.4 0.01    1 0.7 0.44 0.02    0.6 0.35 0.25 0.017    0.2 0.14 0.1 0.016    0.06 0.05 0.045 0.015    0 0 0 0.01]],
                directional        = true,
                emitrot            = 80,
                emitrotspread      = 15,
                emitvector         = [[dir]],
                gravity            = [[0, -0.011, 0]],
                numparticles       = [[0.6 r1]],
                particlelife       = 12,
                particlelifespread = 16,
                particlesize       = 3.7,
                particlesizespread = 3.3,
                particlespeed      = 0.05,
                particlespeedspread = 0.6,
                pos                = [[-3 r6, -3 r6, -3 r6]],
                sizegrowth         = 0.035,
                sizemod            = 1.0,
                texture            = [[randomdots]],
            },
        },
        flame = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 2,
            ground             = true,
            properties = {
                airdrag            = 0.93,
                colormap           = [[0.9 0.5 0.5 0.3  0.5 0.5 0.2 0.2   0.7 0.7 0.1 0.11   0 0 0 0.2   0 0 0 0.15   0 0 0 0.09   0 0 0 0.01]],
                directional        = true,
                emitrot            = 70,
                emitrotspread      = 40,
                emitvector         = [[0.3 r0.1, 1, 0.3 r0.1]],
                gravity            = [[0 r0.1, 0.125 r0.1, 0 r0.1]],
                numparticles       = [[1.5 r1]],
                particlelife       = 6,
                particlelifespread = 7,
                particlesize       = 2,
                particlesizespread = 5.5,
                particlespeed      = 0.2,
                particlespeedspread = 0.55,
                pos                = [[-3 r6, -3 r25, -3 r6]],
                sizegrowth         = 0.8,
                sizemod            = 0.9,
                texture            = [[fire]],
            },
        },
    }
}


function tableMerge(t1, t2)
    for k,v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                tableMerge(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end

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

local largeSize = 1.45
definitions['crashing-large'] = deepcopy(definitions["crashing-small"])
definitions['crashing-large'].smoke.properties.particlesize = definitions['crashing-large'].smoke.properties.particlesize * largeSize
definitions['crashing-large'].smoke.properties.particlesize = definitions['crashing-large'].smoke.properties.particlesizespread * largeSize
definitions['crashing-large'].smoke.properties.particlesize = definitions['crashing-large'].dustparticles.properties.particlesize * largeSize
definitions['crashing-large'].smoke.properties.particlesize = definitions['crashing-large'].dustparticles.properties.particlesizespread * largeSize
definitions['crashing-large'].smoke.properties.particlesize = definitions['crashing-large'].flame.properties.particlesize * largeSize
definitions['crashing-large'].smoke.properties.particlesize = definitions['crashing-large'].flame.properties.particlesizespread * largeSize


return definitions