-- luaui/Include/blueprint_substitution/definitions.lua
-- Contains unit category definitions for blueprint substitution
-- Used by logic.lua

local DefinitionsModule = {}

local SIDES_ENUM = VFS.Include("gamedata/sides_enum.lua")
if not SIDES_ENUM then
    error("[BlueprintDefinitions] CRITICAL: Failed to load sides_enum.lua!")
    -- Return an empty or minimal table if sides are critical and missing
    return DefinitionsModule 
end
DefinitionsModule.SIDES = SIDES_ENUM

DefinitionsModule.UNIT_CATEGORIES = {} -- Enum Name -> Category Name
DefinitionsModule.categoryUnits = {}   -- Category Name -> { Side -> Unit Name }
DefinitionsModule.unitCategories = {}  -- Unit Name -> Category Name

-- ===================================================================
-- Define Unit Categories
-- ===================================================================

local function DefCat(enumKey, unitTable) -- Made local to definitions.lua
    if DefinitionsModule.UNIT_CATEGORIES[enumKey] then
        local errorMsg = string.format("[BlueprintDefinitions ERROR] Duplicate category key definition attempted: '%s'. The previous definition will be overwritten.", enumKey)
        Spring.Log("BlueprintDefs", LOG.ERROR, errorMsg)
    end
    
    DefinitionsModule.UNIT_CATEGORIES[enumKey] = enumKey 
    DefinitionsModule.categoryUnits[enumKey] = unitTable 

    for _, unitName in pairs(unitTable) do -- side variable isn't used here
        if unitName then
            DefinitionsModule.unitCategories[unitName:lower()] = enumKey
        end
    end
end

function DefinitionsModule.defineUnitCategories()
    Spring.Log("BlueprintDefs", LOG.INFO, "Defining static unit categories START...")
    local SIDES = DefinitionsModule.SIDES -- Use SIDES from the module

    -- Clear existing tables (important if this function could be called multiple times on the same module instance, though typically not)
    for k in pairs(DefinitionsModule.UNIT_CATEGORIES) do DefinitionsModule.UNIT_CATEGORIES[k] = nil end
    for k in pairs(DefinitionsModule.categoryUnits) do DefinitionsModule.categoryUnits[k] = nil end
    for k in pairs(DefinitionsModule.unitCategories) do DefinitionsModule.unitCategories[k] = nil end

    -- Resource buildings
    DefCat("METAL_EXTRACTOR", {[SIDES.ARMADA]="armmex", [SIDES.CORTEX]="cormex", [SIDES.LEGION]="legmex"})
    DefCat("EXPLOITER", {[SIDES.ARMADA]="armamex", [SIDES.CORTEX]="corexp", [SIDES.LEGION]="legmext15"})
    DefCat("ADVANCED_EXTRACTOR", {[SIDES.ARMADA]="armmoho", [SIDES.CORTEX]="cormoho", [SIDES.LEGION]="legmoho"})
    DefCat("ADVANCED_EXPLOITER", {[SIDES.ARMADA]="armmoho", [SIDES.CORTEX]="cormexp", [SIDES.LEGION]="cormexp"})
    DefCat("UW_EXTRACTOR", {[SIDES.ARMADA]="armuwmex", [SIDES.CORTEX]="coruwmex", [SIDES.LEGION]="leguwmex"})
    DefCat("ADVANCED_UW_EXTRACTOR", {[SIDES.ARMADA]="armuwmme", [SIDES.CORTEX]="coruwmme", [SIDES.LEGION]="leguwmme"})
    DefCat("METAL_STORAGE", {[SIDES.ARMADA]="armmstor", [SIDES.CORTEX]="cormstor", [SIDES.LEGION]="legmstor"})
    DefCat("ADVANCED_METAL_STORAGE", {[SIDES.ARMADA]="armuwadvms", [SIDES.CORTEX]="coramstor", [SIDES.LEGION]="legamstor"})
    DefCat("UW_METAL_STORAGE", {[SIDES.ARMADA]="armuwms", [SIDES.CORTEX]="coruwms", [SIDES.LEGION]="legamstor"})
    DefCat("UW_ADVANCED_METAL_STORAGE", {[SIDES.ARMADA]="armuwadvms", [SIDES.CORTEX]="coruwadvms", [SIDES.LEGION]="coruwadvms"})

    -- Energy buildings
    DefCat("SOLAR", {[SIDES.ARMADA]="armsolar", [SIDES.CORTEX]="corsolar", [SIDES.LEGION]="legsolar"})
    DefCat("ENERGY_CONVERTER", {[SIDES.ARMADA]="armmakr", [SIDES.CORTEX]="cormakr", [SIDES.LEGION]="legeconv"})
    DefCat("ADVANCED_ENERGY_CONVERTER", {[SIDES.ARMADA]="armmmkr", [SIDES.CORTEX]="", [SIDES.LEGION]="legadveconv"})
    DefCat("UW_ADVANCED_ENERGY_CONVERTER", {[SIDES.ARMADA]="armuwmmm", [SIDES.CORTEX]="coruwmmm", [SIDES.LEGION]="coruwmmm"})
    DefCat("ADVANCED_SOLAR", {[SIDES.ARMADA]="armadvsol", [SIDES.CORTEX]="coradvsol", [SIDES.LEGION]="legadvsol"})
    DefCat("WIND", {[SIDES.ARMADA]="armwin", [SIDES.CORTEX]="corwin", [SIDES.LEGION]="legwin"})
    DefCat("TIDAL", {[SIDES.ARMADA]="armtide", [SIDES.CORTEX]="cortide", [SIDES.LEGION]="legtide"})
    DefCat("FUSION", {[SIDES.ARMADA]="armfus", [SIDES.CORTEX]="corfus", [SIDES.LEGION]="legfus"})
    DefCat("ADVANCED_FUSION", {[SIDES.ARMADA]="armafus", [SIDES.CORTEX]="corafus", [SIDES.LEGION]="legafus"})
    DefCat("UW_FUSION", {[SIDES.ARMADA]="armuwfus", [SIDES.CORTEX]="coruwfus", [SIDES.LEGION]="leguwfus"})
    DefCat("GEOTHERMAL", {[SIDES.ARMADA]="armageo", [SIDES.CORTEX]="corbhmth", [SIDES.LEGION]="leggeo"})
    DefCat("ADVANCED_GEO", {[SIDES.ARMADA]="armgmm", [SIDES.CORTEX]="corgmm", [SIDES.LEGION]="leggmm"})
    DefCat("UW_ADV_GEO", {[SIDES.ARMADA]="armuwageo", [SIDES.CORTEX]="coruwageo", [SIDES.LEGION]="leguwageo"})
    DefCat("ENERGY_STORAGE", {[SIDES.ARMADA]="armestor", [SIDES.CORTEX]="corestor", [SIDES.LEGION]="legestor"})
    DefCat("ADVANCED_ENERGY_STORAGE", {[SIDES.ARMADA]="armuwadves", [SIDES.CORTEX]="coradvestore", [SIDES.LEGION]="legadvestore"})
    DefCat("UW_ENERGY_STORAGE", {[SIDES.ARMADA]="armuwes", [SIDES.CORTEX]="coruwes", [SIDES.LEGION]="leguwes"})
    DefCat("UW_ADVANCED_ENERGY_STORAGE", {[SIDES.ARMADA]="armuwadves", [SIDES.CORTEX]="coruwadves", [SIDES.LEGION]="coruwadves"})

    -- Factory buildings
    DefCat("BOT_LAB", {[SIDES.ARMADA]="armlab", [SIDES.CORTEX]="corlab", [SIDES.LEGION]="leglab"})
    DefCat("VEHICLE_PLANT", {[SIDES.ARMADA]="armvp", [SIDES.CORTEX]="corvp", [SIDES.LEGION]="legvp"})
    DefCat("AIRCRAFT_PLANT", {[SIDES.ARMADA]="armap", [SIDES.CORTEX]="corap", [SIDES.LEGION]="legap"})
    DefCat("ADVANCED_AIRCRAFT_PLANT", {[SIDES.ARMADA]="armaap", [SIDES.CORTEX]="coraap", [SIDES.LEGION]="legaap"})
    DefCat("SHIPYARD", {[SIDES.ARMADA]="armsy", [SIDES.CORTEX]="corsy", [SIDES.LEGION]="corsy"})
    DefCat("ADVANCED_SHIPYARD", {[SIDES.ARMADA]="armasy", [SIDES.CORTEX]="corasy", [SIDES.LEGION]="legasy"})
    DefCat("HOVER_PLATFORM", {[SIDES.ARMADA]="armhp", [SIDES.CORTEX]="corhp", [SIDES.LEGION]="leghp"})
    DefCat("AMPHIBIOUS_COMPLEX", {[SIDES.ARMADA]="armamsub", [SIDES.CORTEX]="coramsub", [SIDES.LEGION]="coramsub"})
    DefCat("EXPIREMENTAL_GANTRY", {[SIDES.ARMADA]="armshltx", [SIDES.CORTEX]="corgant", [SIDES.LEGION]="leggant"})
    DefCat("UW_EXPIREMENTAL_GANTRY", {[SIDES.ARMADA]="armshltxuw", [SIDES.CORTEX]="corgantuw", [SIDES.LEGION]="leggant"})
    DefCat("SEAPLANE_PLATFORM", {[SIDES.ARMADA]="armplat", [SIDES.CORTEX]="corplat", [SIDES.LEGION]="corplat"})

    -- Static defense buildings
    DefCat("LIGHT_LASER", {[SIDES.ARMADA]="armllt", [SIDES.CORTEX]="corllt", [SIDES.LEGION]="leglht"})
    DefCat("HEAVY_LIGHT_LASER", {[SIDES.ARMADA]="armbeamer", [SIDES.CORTEX]="corhllt", [SIDES.LEGION]="legmg"})
    DefCat("HEAVY_LASER", {[SIDES.ARMADA]="armhlt", [SIDES.CORTEX]="corhlt", [SIDES.LEGION]="leghive"})
    DefCat("MISSILE_DEFENSE", {[SIDES.ARMADA]="armrl", [SIDES.CORTEX]="corrl", [SIDES.LEGION]="legrl"})
    DefCat("SAM_SITE", {[SIDES.ARMADA]="armcir", [SIDES.CORTEX]="cormadsam", [SIDES.LEGION]="legrhapsis"})
    DefCat("POPUP_AREA_DEFENSE", {[SIDES.ARMADA]="armpb", [SIDES.CORTEX]="corvipe", [SIDES.LEGION]="legbombard"})
    DefCat("POPUP_AIR_DEFENSE", {[SIDES.ARMADA]="armferret", [SIDES.CORTEX]="corerad", [SIDES.LEGION]="leglupara"})
    DefCat("FLAK", {[SIDES.ARMADA]="armflak", [SIDES.CORTEX]="corflak", [SIDES.LEGION]="legflak"})
    DefCat("FLOATING_FLAK", {[SIDES.ARMADA]="armfflak", [SIDES.CORTEX]="corenaa", [SIDES.LEGION]="corenaa"})
    DefCat("FLOATING_HEAVY_LASER", {[SIDES.ARMADA]="armfhlt", [SIDES.CORTEX]="corfhlt", [SIDES.LEGION]="legfhlt"})
    DefCat("FLOATING_MISSILE", {[SIDES.ARMADA]="armfrt", [SIDES.CORTEX]="corfrt", [SIDES.LEGION]="corfrt"})
    DefCat("LONG_RANGE_ANTI_AIR", {[SIDES.ARMADA]="armmercury", [SIDES.CORTEX]="corscreamer", [SIDES.LEGION]="leglraa"})
    DefCat("TORPEDO", {[SIDES.ARMADA]="armdl", [SIDES.CORTEX]="cordl", [SIDES.LEGION]="cordl"})
    DefCat("ADV_TORPEDO", {[SIDES.ARMADA]="armatl", [SIDES.CORTEX]="coratl", [SIDES.LEGION]="legatl"})
    DefCat("OFFSHORE_TORPEDO", {[SIDES.ARMADA]="armptl", [SIDES.CORTEX]="corptl", [SIDES.LEGION]="legptl"})
    DefCat("ARTILLERY", {[SIDES.ARMADA]="armguard", [SIDES.CORTEX]="corpun", [SIDES.LEGION]="legcluster"})
    DefCat("LONG_RANGE_PLASMA_CANNON", {[SIDES.ARMADA]="armbrtha", [SIDES.CORTEX]="corint", [SIDES.LEGION]="leglrpc"})
    DefCat("RAPID_FIRE_LONG_RANGE_PLASMA_CANNON", {[SIDES.ARMADA]="armvulc", [SIDES.CORTEX]="corbuzz", [SIDES.LEGION]="legstarfall"})
    DefCat("ANNIHILATOR", {[SIDES.ARMADA]="armanni", [SIDES.CORTEX]="cordoom", [SIDES.LEGION]="legbastion"})
    DefCat("ADV_FLOATING_ANNIHILATOR", {[SIDES.ARMADA]="armkraken", [SIDES.CORTEX]="corfdoom", [SIDES.LEGION]="corfdoom"})
    DefCat("ADVANCED_PLASMA_ARTILLERY", {[SIDES.ARMADA]="armamb", [SIDES.CORTEX]="cortoast", [SIDES.LEGION]="legacluster"})
    DefCat("DRAGONS_CLAW", {[SIDES.ARMADA]="armclaw", [SIDES.CORTEX]="cormaw", [SIDES.LEGION]="legdrag"})
    DefCat("DRAGONS_TEETH", {[SIDES.ARMADA]="armdrag", [SIDES.CORTEX]="cordrag", [SIDES.LEGION]="legdrag"})
    DefCat("ADVANCED_DRAGONS_TEETH", {[SIDES.ARMADA]="armfort", [SIDES.CORTEX]="corfort", [SIDES.LEGION]="legforti"})
    DefCat("SHIELD", {[SIDES.ARMADA]="armgate", [SIDES.CORTEX]="", [SIDES.LEGION]="legdeflector"})
    DefCat("MEDIUM_RANGE_MISSILE", {[SIDES.ARMADA]="armemp", [SIDES.CORTEX]="cortron", [SIDES.LEGION]="legperdition"})

    -- Intel and special buildings
    DefCat("RADAR", {[SIDES.ARMADA]="armrad", [SIDES.CORTEX]="corrad", [SIDES.LEGION]="legrad"})
    DefCat("ADVANCED_RADAR", {[SIDES.ARMADA]="armarad", [SIDES.CORTEX]="corarad", [SIDES.LEGION]="legarad"})
    DefCat("ADV_RADAR", {[SIDES.ARMADA]="armarad", [SIDES.CORTEX]="corarad", [SIDES.LEGION]="legarad"})
    DefCat("JAMMER", {[SIDES.ARMADA]="armjamt", [SIDES.CORTEX]="corjamt", [SIDES.LEGION]="legjam"})
    DefCat("ADVANCED_JAMMER", {[SIDES.ARMADA]="armveil", [SIDES.CORTEX]="corshroud", [SIDES.LEGION]="legajam"})
    DefCat("SONAR", {[SIDES.ARMADA]="armsonar", [SIDES.CORTEX]="corsonar", [SIDES.LEGION]="legsonar"})
    DefCat("ADV_SONAR", {[SIDES.ARMADA]="armason", [SIDES.CORTEX]="corason", [SIDES.LEGION]="legason"})
    DefCat("CAMERA", {[SIDES.ARMADA]="armeyes", [SIDES.CORTEX]="coreyes", [SIDES.LEGION]="legeyes"})
    DefCat("NUKE", {[SIDES.ARMADA]="armsilo", [SIDES.CORTEX]="corsilo", [SIDES.LEGION]="legsilo"})
    DefCat("ANTINUKE", {[SIDES.ARMADA]="armamd", [SIDES.CORTEX]="corfmd", [SIDES.LEGION]="legabm"})
    DefCat("JUNO", {[SIDES.ARMADA]="armjuno", [SIDES.CORTEX]="corjuno", [SIDES.LEGION]="legjuno"})
    DefCat("NANO_TOWER", {[SIDES.ARMADA]="armnanotc", [SIDES.CORTEX]="cornanotc", [SIDES.LEGION]="legnanotc"})
    DefCat("FLOATING_NANO_TOWER", {[SIDES.ARMADA]="armnanotcplat", [SIDES.CORTEX]="cornanotcplat", [SIDES.LEGION]="legnanotcplat"})
    DefCat("ADV_NANO_TOWER", {[SIDES.ARMADA]="armnanotct2", [SIDES.CORTEX]="cornanotct2", [SIDES.LEGION]="legnanotct2"})
    DefCat("STEALTH_DETECTION", {[SIDES.ARMADA]="armrsd", [SIDES.CORTEX]="corrsd", [SIDES.LEGION]="legsd"})
    DefCat("PINPOINTER", {[SIDES.ARMADA]="armtarg", [SIDES.CORTEX]="cortarg", [SIDES.LEGION]="legtarg"})
    DefCat("FLOATING_PINPOINTER", {[SIDES.ARMADA]="armfatf", [SIDES.CORTEX]="corfatf", [SIDES.LEGION]="corfatf"})
    DefCat("FLOATING_TORPEDO_LAUNCHER_PG", {[SIDES.ARMADA]="armtl", [SIDES.CORTEX]="cortl", [SIDES.LEGION]="cortl"})
    DefCat("FLOATING_RADAR_PG", {[SIDES.ARMADA]="armfrad", [SIDES.CORTEX]="corfrad", [SIDES.LEGION]="corfrad"})
    DefCat("FLOATING_CONVERTER_PG", {[SIDES.ARMADA]="armfmkr", [SIDES.CORTEX]="corfmkr", [SIDES.LEGION]="legfmkr"})
    DefCat("FLOATING_DRAGONSTEETH_PG", {[SIDES.ARMADA]="armfdrag", [SIDES.CORTEX]="corfdrag", [SIDES.LEGION]="corfdrag"})
    DefCat("FLOATING_HOVER_PLATFORM_PG", {[SIDES.ARMADA]="armfhp", [SIDES.CORTEX]="corfhp", [SIDES.LEGION]="legfhp"})

    -- NOT BUILDINGS
    DefCat("COMMANDER", {[SIDES.ARMADA]="armcom", [SIDES.CORTEX]="corcom", [SIDES.LEGION]="legcom"})

    local unitCount = 0
    for _, units in pairs(DefinitionsModule.categoryUnits) do
        for _, unit in pairs(units) do
            if unit then unitCount = unitCount + 1 end
        end
    end
    local categoryCount = 0
    for _ in pairs(DefinitionsModule.UNIT_CATEGORIES) do categoryCount = categoryCount + 1 end
    Spring.Log("BlueprintDefs", LOG.INFO, string.format("Defined %d categories covering %d units. END", categoryCount, unitCount))
end

DefinitionsModule.defineUnitCategories() -- Call it once to populate the module table

return DefinitionsModule 