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
                colormap           = [[0.05 0.04 0.033 0.62   0.04 0.038 0.034 0.57   0.04 0.036 0.032 0.48   0.025 0.025 0.025 0.3   0.014 0.014 0.014 0.15    0.006 0.006 0.006 0.06   0 0 0 0.01]],
                directional        = true,
                emitrot            = -180,
                emitrotspread      = 28,
                emitvector         = [[dir]],
                gravity            = [[0.0, -0.03, 0.0]],
                numparticles       = [[1 r1]],
                particlelife       = 45,
                particlelifespread = 65,
                particlesize       = 3,
                particlesizespread = 5,
                particlespeed      = 0.4,
                particlespeedspread = 2,
                pos                = [[-5 r10, -5 r10, -5 r10]],
                sizegrowth         = 0.1,
                sizemod            = 1,
                texture            = [[smoke]],
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
                colormap           = [[0.12 0.09 0.08 0.48   0.095 0.085 0.07 0.42   0.08 0.072 0.07 0.29   0.05 0.045 0.04 0.17   0.027 0.027 0.027 0.09    0.012 0.012 0.012 0.04   0 0 0 0.01]],
                directional        = true,
                emitrot            = -180,
                emitrotspread      = 28,
                emitvector         = [[dir]],
                gravity            = [[0.0, -0.03, 0.0]],
                numparticles       = [[0.7 r1]],
                particlelife       = 45,
                particlelifespread = 55,
                particlesize       = 2.8,
                particlesizespread = 4.8,
                particlespeed      = 0.4,
                particlespeedspread = 2,
                pos                = [[-5 r10, -5 r10, -5 r10]],
                sizegrowth         = 0.1,
                sizemod            = 1,
                texture            = [[smoke]],
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
                airdrag            = 0.91,
                colormap           = [[0.9 0.6 0.4 0.01    0.95 0.63 0.38 0.02    0.54 0.33 0.2 0.017    0.16 0.125 0.09 0.016    0.052 0.045 0.04 0.015    0 0 0 0.01]],
                directional        = true,
                emitrot            = -180,
                emitrotspread      = 28,
                emitvector         = [[dir]],
                gravity            = [[0, -0.025, 0]],
                numparticles       = [[0.5 r1]],
                particlelife       = 24,
                particlelifespread = 20,
                particlesize       = 2.4,
                particlesizespread = 2.2,
                particlespeed      = 0.05,
                particlespeedspread = 0.6,
                pos                = [[-3 r6, -3 r6, -3 r6]],
                sizegrowth         = 0.07,
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
                airdrag            = 0.92,
                colormap           = [[0.5 0.32 0.15 0.01  0.22 0.22 0.1 0.01   0.15 0.15 0.04 0.01   0.08 0.08 0.025 0.01   0 0 0 0.01]],
                directional        = true,
                emitrot            = 5,
                emitrotspread      = 40,
                emitvector         = [[-0.1 r0.2, 1, -0.1 r0.2]],
                gravity            = [[0, -0.011, 0]],
                numparticles       = [[0.6 r1]],
                particlelife       = 3,
                particlelifespread = 8,
                particlesize       = 1.5,
                particlesizespread = 6.5,
                particlespeed      = 0.3,
                particlespeedspread = 0.8,
                pos                = [[-7 r14, -7 r14, -7 r14]],
                sizegrowth         = 0.25,
                sizemod            = 0.97,
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
definitions['crashing-small2'].dustparticles.properties.particlelife = definitions['crashing-small2'].dustparticles.properties.particlelife * 2
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
definitions['crashing-small3'].dustparticles.properties.particlelife = definitions['crashing-small3'].dustparticles.properties.particlelife * 0.5
definitions['crashing-small3'].dustparticles.properties.particlelifespread = definitions['crashing-small3'].dustparticles.properties.particlelifespread * 0.5

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
definitions['crashing-large3'].dustparticles.properties.particlelife = definitions['crashing-large3'].dustparticles.properties.particlelife * 0.5
definitions['crashing-large3'].dustparticles.properties.particlelifespread = definitions['crashing-large3'].dustparticles.properties.particlelifespread * 0.5

return definitions