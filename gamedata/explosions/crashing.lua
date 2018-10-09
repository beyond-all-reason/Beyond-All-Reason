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
                numparticles       = [[1 r1]],
                particlelife       = 55,
                particlelifespread = 55,
                particlesize       = 2.3,
                particlesizespread = 2.9,
                particlespeed      = 0.4,
                particlespeedspread = 2,
                pos                = [[-5 r10, -5 r10, -5 r10]],
                sizegrowth         = 0.12,
                sizemod            = 1,
                texture            = [[dirt]],
                useairlos          = true,
            },
        },
        smoke2 = {
            air                = true,
            class              = [[CSimpleParticleSystem]],
            count              = 1,
            ground             = true,
            water              = true,
            properties = {
                airdrag            = 0.91,
                colormap           = [[0.24 0.18 0.16 0.35   0.19 0.17 0.14 0.4   0.16 0.145 0.14 0.3   0.1 0.09 0.08 0.2   0.055 0.055 0.055 0.11    0.025 0.025 0.025 0.05   0 0 0 0.01]],
                directional        = true,
                emitrot            = -180,
                emitrotspread      = 30,
                emitvector         = [[dir]],
                gravity            = [[0.0, -0.03, 0.0]],
                numparticles       = [[0.7 r1]],
                particlelife       = 55,
                particlelifespread = 55,
                particlesize       = 2.8,
                particlesizespread = 3.5,
                particlespeed      = 0.4,
                particlespeedspread = 2,
                pos                = [[-5 r10, -5 r10, -5 r10]],
                sizegrowth         = 0.12,
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
                particlelife       = 20,
                particlelifespread = 20,
                particlesize       = 2.9,
                particlesizespread = 2.7,
                particlespeed      = 0.05,
                particlespeedspread = 0.6,
                pos                = [[-3 r6, -3 r6, -3 r6]],
                sizegrowth         = 0.033,
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
                airdrag            = 0.94,
                colormap           = [[0.9 0.5 0.5 0.3  0.5 0.5 0.2 0.2   0.7 0.7 0.1 0.13   0.2 0.2 0.05 0.13   0.1 0.1 0.02 0.09   0 0 0 0.05   0 0 0 0.01]],
                directional        = true,
                emitrot            = 70,
                emitrotspread      = 7,
                emitvector         = [[0.3 r0.1, 1, 0.3 r0.1]],
                gravity            = [[0 r0.1, 0.125 r0.1, 0 r0.1]],
                numparticles       = [[1.5 r1]],
                particlelife       = 3,
                particlelifespread = 3,
                particlesize       = 2,
                particlesizespread = 5.5,
                particlespeed      = 0.8,
                particlespeedspread = 1.7,
                pos                = [[-7 r14, -7 r14, -7 r14]],
                sizegrowth         = 0.5,
                sizemod            = 0.9,
                texture            = [[fire]],
            },
        },
    },
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

local sizeMult = 1.2
definitions['crashing-small2'] = deepcopy(definitions["crashing-small"])
definitions['crashing-small2'].smoke.properties.particlelife = definitions['crashing-small2'].smoke.properties.particlelife * 1.3
definitions['crashing-small2'].smoke.properties.particlelifespread = definitions['crashing-small2'].smoke.properties.particlelifespread * 1.3
definitions['crashing-small2'].dustparticles.properties.particlelife = definitions['crashing-small2'].dustparticles.properties.particlelife * 1.6
definitions['crashing-small2'].dustparticles.properties.particlelifespread = definitions['crashing-small2'].dustparticles.properties.particlelifespread * 1.6
definitions['crashing-small2'].flame.properties.particlelife = definitions['crashing-small2'].flame.properties.particlelife * 1.6
definitions['crashing-small2'].flame.properties.particlelifespread = definitions['crashing-small2'].flame.properties.particlelifespread * 1.6
definitions['crashing-small2'].flame.properties.numparticles = 2
definitions['crashing-small2'].smoke.properties.particlesize = definitions['crashing-small2'].smoke.properties.particlesize * sizeMult
definitions['crashing-small2'].smoke.properties.particlesizespread = definitions['crashing-small2'].smoke.properties.particlesizespread * sizeMult
definitions['crashing-small2'].dustparticles.properties.particlesize = definitions['crashing-small2'].dustparticles.properties.particlesize * sizeMult
definitions['crashing-small2'].dustparticles.properties.particlesizespread = definitions['crashing-small2'].dustparticles.properties.particlesizespread * sizeMult
definitions['crashing-small2'].flame.properties.particlesize = definitions['crashing-small2'].flame.properties.particlesize * sizeMult
definitions['crashing-small2'].flame.properties.particlesizespread = definitions['crashing-small2'].flame.properties.particlesizespread * sizeMult

sizeMult = 0.85
definitions['crashing-small3'] = deepcopy(definitions["crashing-small"])
definitions['crashing-small3'].flame = nil
definitions['crashing-small3'].smoke.properties.particlesize = definitions['crashing-small3'].smoke.properties.particlesize * sizeMult
definitions['crashing-small3'].smoke.properties.particlesizespread = definitions['crashing-small3'].smoke.properties.particlesizespread * sizeMult
definitions['crashing-small3'].dustparticles.properties.particlesize = definitions['crashing-small3'].dustparticles.properties.particlesize * sizeMult
definitions['crashing-small3'].dustparticles.properties.particlesizespread = definitions['crashing-small3'].dustparticles.properties.particlesizespread * sizeMult

sizeMult = 1.5
definitions['crashing-large'] = deepcopy(definitions["crashing-small"])
definitions['crashing-large'].smoke.properties.particlesize = definitions['crashing-large'].smoke.properties.particlesize * sizeMult
definitions['crashing-large'].smoke.properties.particlesizespread = definitions['crashing-large'].smoke.properties.particlesizespread * sizeMult
definitions['crashing-large'].dustparticles.properties.particlesize = definitions['crashing-large'].dustparticles.properties.particlesize * sizeMult
definitions['crashing-large'].dustparticles.properties.particlesizespread = definitions['crashing-large'].dustparticles.properties.particlesizespread * sizeMult
definitions['crashing-large'].flame.properties.particlesize = definitions['crashing-large'].flame.properties.particlesize * sizeMult
definitions['crashing-large'].flame.properties.particlesizespread = definitions['crashing-large'].flame.properties.particlesizespread * sizeMult

definitions['crashing-large2'] = deepcopy(definitions["crashing-small2"])
definitions['crashing-large2'].smoke.properties.particlesize = definitions['crashing-large2'].smoke.properties.particlesize * sizeMult
definitions['crashing-large2'].smoke.properties.particlesizespread = definitions['crashing-large2'].smoke.properties.particlesizespread * sizeMult
definitions['crashing-large2'].dustparticles.properties.particlesize = definitions['crashing-large2'].dustparticles.properties.particlesize * sizeMult
definitions['crashing-large2'].dustparticles.properties.particlesizespread = definitions['crashing-large2'].dustparticles.properties.particlesizespread * sizeMult
definitions['crashing-large2'].flame.properties.particlesize = definitions['crashing-large2'].flame.properties.particlesize * sizeMult
definitions['crashing-large2'].flame.properties.particlesizespread = definitions['crashing-large2'].flame.properties.particlesizespread * sizeMult
definitions['crashing-large2'].dustparticles.properties.particlelife = definitions['crashing-large2'].dustparticles.properties.particlelife * 1.2
definitions['crashing-large2'].dustparticles.properties.particlelifespread = definitions['crashing-large2'].dustparticles.properties.particlelifespread * 1.2

sizeMult = 0.85
definitions['crashing-large3'] = deepcopy(definitions["crashing-large"])
definitions['crashing-large3'].flame = nil
definitions['crashing-large3'].smoke.properties.particlesize = definitions['crashing-large3'].smoke.properties.particlesize * sizeMult
definitions['crashing-large3'].smoke.properties.particlesizespread = definitions['crashing-large3'].smoke.properties.particlesizespread * sizeMult
definitions['crashing-large3'].dustparticles.properties.particlesize = definitions['crashing-large3'].dustparticles.properties.particlesize * sizeMult
definitions['crashing-large3'].dustparticles.properties.particlesizespread = definitions['crashing-large3'].dustparticles.properties.particlesizespread * sizeMult

return definitions