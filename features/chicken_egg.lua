local chicken_egg =  {
    description = "Egg",
    blocking = 0,
    category = "corpses",
    damage = 2000,
    energy = 500,
    featurereclamate = "SMUDGE01",
    footprintx = 1,
    footprintz = 1,
    height = 15,
    hitdensity = 999999,
    metal = 100,
    mass = 100,
    reclaimable = 1,
    resurrectable = 0,
    world = "All Worlds",
    smokeTime = 0,
}

local eggs = {}
local sizes = {"s","m","l",}
local colors = {"pink","white","red", "blue", "darkgreen", "purple", "green", "yellow", "darkred", "acidgreen"}
local mvalues = {s = 20, m = 50, l = 100}
local evalues = {s = 200, m = 500, l = 1000}

for _, size in pairs(sizes) do
    for _, color in pairs(colors) do
        local name = "chicken_egg_"..size.."_"..color
        local def = {}
        for k,v in pairs(chicken_egg) do def[k] = v    end
        def.customparams =     {
            model_author = "KDR11k, Beherith",
            normalmaps = "yes",
            normaltex = "unittextures/chicken_s_normals.png",
            treeshader = "yes",
            i18nfrom = 'chicken_egg'
        }
        def.name = name
        def.object =  "Chickens/chickenegg_"..size.."_"..color .. ".s3o"
        def.metal = mvalues[size]
        def.energy = evalues[size]
        def.reclaimtime = evalues[size]
        def.damage = evalues[size]*5
        eggs[name] = def
    end
end

return eggs
