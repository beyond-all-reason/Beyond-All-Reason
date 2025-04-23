-- luaui/Include/blueprint_substitution/definitions.lua
-- Contains unit category definitions for blueprint substitution
-- Used by logic.lua

-- Make a global table for these definitions
WG.BlueprintDefinitions = WG.BlueprintDefinitions or {}
local BpDefs = WG.BlueprintDefinitions -- Local alias for convenience

-- ===================================================================
-- Configuration & Data
-- ===================================================================
Spring.Log("BlueprintDefs", LOG.INFO, "Initializing blueprint category definitions...")

local SIDES_ENUM = VFS.Include("gamedata/sides_enum.lua")
if not SIDES_ENUM then
    error("[BlueprintDefs] Failed to load sides_enum.lua!")
end
BpDefs.SIDES = SIDES_ENUM


-- Data tables for category management
BpDefs.UNIT_CATEGORIES = {} -- Enum Name -> Category Name
BpDefs.categoryUnits = {}   -- Category Name -> { Side -> Unit Name }
BpDefs.unitCategories = {}  -- Unit Name -> Category Name

-- ===================================================================
-- Define Unit Categories
-- ===================================================================

function BpDefs.defineUnitCategories()
    Spring.Log("BlueprintDefs", LOG.INFO, "Defining static unit categories START...")
    ---@type SidesEnum
    local SIDES = BpDefs.SIDES

    local UNIT_CATEGORIES = BpDefs.UNIT_CATEGORIES
    local categoryUnits = BpDefs.categoryUnits
    local unitCategories = BpDefs.unitCategories

    -- Clear existing tables WITHOUT creating new local ones
    for k in pairs(UNIT_CATEGORIES) do UNIT_CATEGORIES[k] = nil end
    for k in pairs(categoryUnits) do categoryUnits[k] = nil end
    for k in pairs(unitCategories) do unitCategories[k] = nil end

    local function DefCat(e, u)
        -- Check for duplicate category key *before* assignment
        if UNIT_CATEGORIES[e] then
            local errorMsg = string.format("[BlueprintDefs ERROR] Duplicate category key definition attempted: '%s'. The previous definition will be overwritten.", e)
            Spring.Log("BlueprintDefs", "error", errorMsg)
            -- error(errorMsg) -- Really want to do this, but caching lua and bringing down the blueprint system is a PITA
        end
        
        UNIT_CATEGORIES[e]=e; -- Enum Name maps to itself
        categoryUnits[e]=u    -- Category Name (verbose) maps to the Side->Unit table (u)

        -- Build reverse mapping
        for side, unitName in pairs(u) do
            if unitName then
                unitCategories[unitName:lower()] = e
            end
        end
    end

    -- Resource buildings
    DefCat("METAL_EXTRACTOR", {[SIDES.ARM]="armmex", [SIDES.CORE]="cormex", [SIDES.LEGION]="legmex"})
    DefCat("EXPLOITER", {[SIDES.ARM]="armamex", [SIDES.CORE]="corexp", [SIDES.LEGION]="legmext15"})
    DefCat("ADVANCED_EXTRACTOR", {[SIDES.ARM]="armmoho", [SIDES.CORE]="cormoho", [SIDES.LEGION]="legmoho"})
    DefCat("ADVANCED_EXPLOITER", {[SIDES.ARM]="armmoho", [SIDES.CORE]="cormexp", [SIDES.LEGION]="cormexp"})
    DefCat("UW_EXTRACTOR", {[SIDES.ARM]="armuwmex", [SIDES.CORE]="coruwmex", [SIDES.LEGION]="leguwmex"})
    DefCat("ADVANCED_UW_EXTRACTOR", {[SIDES.ARM]="armuwmme", [SIDES.CORE]="coruwmme", [SIDES.LEGION]="leguwmme"})
    DefCat("METAL_STORAGE", {[SIDES.ARM]="armmstor", [SIDES.CORE]="cormstor", [SIDES.LEGION]="legmstor"})
    DefCat("ADVANCED_METAL_STORAGE", {[SIDES.ARM]="armuwadvms", [SIDES.CORE]="coramstor", [SIDES.LEGION]="legamstor"})
    DefCat("UW_METAL_STORAGE", {[SIDES.ARM]="armuwms", [SIDES.CORE]="coruwms", [SIDES.LEGION]="legamstor"})
    DefCat("UW_ADVANCED_METAL_STORAGE", {[SIDES.ARM]="armuwadvms", [SIDES.CORE]="coruwadvms", [SIDES.LEGION]="coruwadvms"})

    -- Energy buildings
    DefCat("SOLAR", {[SIDES.ARM]="armsolar", [SIDES.CORE]="corsolar", [SIDES.LEGION]="legsolar"})
    DefCat("ENERGY_CONVERTER", {[SIDES.ARM]="armmakr", [SIDES.CORE]="cormakr", [SIDES.LEGION]="legeconv"})
    DefCat("ADVANCED_ENERGY_CONVERTER", {[SIDES.ARM]="armmmkr", [SIDES.CORE]="", [SIDES.LEGION]="legadveconv"})
    DefCat("ADVANCED_SOLAR", {[SIDES.ARM]="armadvsol", [SIDES.CORE]="coradvsol", [SIDES.LEGION]="legadvsol"})
    DefCat("WIND", {[SIDES.ARM]="armwin", [SIDES.CORE]="corwin", [SIDES.LEGION]="legwin"})
    DefCat("TIDAL", {[SIDES.ARM]="armtide", [SIDES.CORE]="cortide", [SIDES.LEGION]="legtide"})
    DefCat("FUSION", {[SIDES.ARM]="armfus", [SIDES.CORE]="corfus", [SIDES.LEGION]="legfus"})
    DefCat("ADVANCED_FUSION", {[SIDES.ARM]="armafus", [SIDES.CORE]="corafus", [SIDES.LEGION]="legafus"})
    DefCat("UW_FUSION", {[SIDES.ARM]="armuwfus", [SIDES.CORE]="coruwfus", [SIDES.LEGION]="leguwfus"})
    DefCat("GEOTHERMAL", {[SIDES.ARM]="armageo", [SIDES.CORE]="corbhmth", [SIDES.LEGION]="leggeo"})
    DefCat("ADVANCED_GEO", {[SIDES.ARM]="armgmm", [SIDES.CORE]="corgmm", [SIDES.LEGION]="leggmm"})
    DefCat("UW_ADV_GEO", {[SIDES.ARM]="armuwageo", [SIDES.CORE]="coruwageo", [SIDES.LEGION]="leguwageo"})
    DefCat("ENERGY_STORAGE", {[SIDES.ARM]="armestor", [SIDES.CORE]="corestor", [SIDES.LEGION]="legestor"})
    DefCat("ADVANCED_ENERGY_STORAGE", {[SIDES.ARM]="armuwadves", [SIDES.CORE]="coradvestore", [SIDES.LEGION]="legadvestore"})
    DefCat("UW_ENERGY_STORAGE", {[SIDES.ARM]="armuwes", [SIDES.CORE]="coruwes", [SIDES.LEGION]="leguwes"})
    DefCat("UW_ADVANCED_ENERGY_STORAGE", {[SIDES.ARM]="armuwadves", [SIDES.CORE]="coruwadves", [SIDES.LEGION]="legadvestore"})

    -- Factory buildings
    DefCat("BOT_LAB", {[SIDES.ARM]="armlab", [SIDES.CORE]="corlab", [SIDES.LEGION]="leglab"})
    DefCat("VEHICLE_PLANT", {[SIDES.ARM]="armvp", [SIDES.CORE]="corvp", [SIDES.LEGION]="legvp"})
    DefCat("AIRCRAFT_PLANT", {[SIDES.ARM]="armap", [SIDES.CORE]="corap", [SIDES.LEGION]="legap"})
    DefCat("ADVANCED_AIRCRAFT_PLANT", {[SIDES.ARM]="armaap", [SIDES.CORE]="coraap", [SIDES.LEGION]="legaap"})
    DefCat("SHIPYARD", {[SIDES.ARM]="armsy", [SIDES.CORE]="corsy", [SIDES.LEGION]="legsy"})
    DefCat("ADVANCED_SHIPYARD", {[SIDES.ARM]="armasy", [SIDES.CORE]="corasy", [SIDES.LEGION]="legasy"})
    DefCat("HOVER_PLATFORM", {[SIDES.ARM]="armhp", [SIDES.CORE]="corhp", [SIDES.LEGION]="leghp"})
    DefCat("AIR_REPAIR_PAD", {[SIDES.ARM]="armasp", [SIDES.CORE]="corasp", [SIDES.LEGION]="legasp"})
    DefCat("FLOATING_AIR_REPAIR_PAD", {[SIDES.ARM]="armfasp", [SIDES.CORE]="corfasp", [SIDES.LEGION]="legfasp"})
    DefCat("EXPIREMENTAL_GANTRY", {[SIDES.ARM]="armshltx", [SIDES.CORE]="corgant", [SIDES.LEGION]="leggant"})
    DefCat("SEAPLANE_PLATFORM", {[SIDES.ARM]="armplat", [SIDES.CORE]="corplat", [SIDES.LEGION]="corplat"})

    -- Static defense buildings
    DefCat("LIGHT_LASER", {[SIDES.ARM]="armllt", [SIDES.CORE]="corllt", [SIDES.LEGION]="leglht"})
    DefCat("HEAVY_LIGHT_LASER", {[SIDES.ARM]="armbeamer", [SIDES.CORE]="corhllt", [SIDES.LEGION]="legmg"})
    DefCat("HEAVY_LASER", {[SIDES.ARM]="armhlt", [SIDES.CORE]="corhlt", [SIDES.LEGION]="leghive"})
    DefCat("MISSILE_DEFENSE", {[SIDES.ARM]="armrl", [SIDES.CORE]="corrl", [SIDES.LEGION]="legrl"})
    DefCat("SAM_SITE", {[SIDES.ARM]="armcir", [SIDES.CORE]="cormadsam", [SIDES.LEGION]="legrhapsis"})
    DefCat("POPUP_AREA_DEFENSE", {[SIDES.ARM]="armpb", [SIDES.CORE]="corvipe", [SIDES.LEGION]="legbombard"})
    DefCat("POPUP_AIR_DEFENSE", {[SIDES.ARM]="armferret", [SIDES.CORE]="corerad", [SIDES.LEGION]="leglupara"})
    DefCat("FLAK", {[SIDES.ARM]="armflak", [SIDES.CORE]="corflak", [SIDES.LEGION]="legflak"})
    DefCat("FLOATING_FLAK", {[SIDES.ARM]="armfflak", [SIDES.CORE]="corfflak", [SIDES.LEGION]="legfflak"})
    DefCat("FLOATING_HEAVY_LASER", {[SIDES.ARM]="armfhlt", [SIDES.CORE]="corfhlt", [SIDES.LEGION]="legfhlt"})
    DefCat("FLOATING_MISSILE", {[SIDES.ARM]="armfrt", [SIDES.CORE]="corfrt", [SIDES.LEGION]="legfrt"})
    DefCat("LONG_RANGE_ANTI_AIR", {[SIDES.ARM]="armmercury", [SIDES.CORE]="corscreamer", [SIDES.LEGION]="leglraa"})
    DefCat("TORPEDO", {[SIDES.ARM]="armdl", [SIDES.CORE]="cordl", [SIDES.LEGION]="legdl"})
    DefCat("ADV_TORPEDO", {[SIDES.ARM]="armatl", [SIDES.CORE]="coratl", [SIDES.LEGION]="legatl"})
    DefCat("OFFSHORE_TORPEDO", {[SIDES.ARM]="armptl", [SIDES.CORE]="corptl", [SIDES.LEGION]="legptl"})
    DefCat("ARTILLERY", {[SIDES.ARM]="armguard", [SIDES.CORE]="corpun", [SIDES.LEGION]="legcluster"})
    DefCat("LONG_RANGE_PLASMA_CANNON", {[SIDES.ARM]="armbrtha", [SIDES.CORE]="corint", [SIDES.LEGION]="leglrpc"})
    DefCat("RAPID_FIRE_LONG_RANGE_PLASMA_CANNON", {[SIDES.ARM]="armvulc", [SIDES.CORE]="corbuzz", [SIDES.LEGION]="legstarfall"})
    DefCat("ANNIHILATOR", {[SIDES.ARM]="armanni", [SIDES.CORE]="cordoom", [SIDES.LEGION]="legbastion"})
    DefCat("ADVANCED_PLASMA_ARTILLERY", {[SIDES.ARM]="armamb", [SIDES.CORE]="cortoast", [SIDES.LEGION]="legacluster"})
    DefCat("DRAGONS_CLAW", {[SIDES.ARM]="armclaw", [SIDES.CORE]="cormaw", [SIDES.LEGION]="legdrag"})
    DefCat("DRAGONS_TEETH", {[SIDES.ARM]="armdrag", [SIDES.CORE]="cordrag", [SIDES.LEGION]="legdrag"})
    DefCat("ADVANCED_DRAGONS_TEETH", {[SIDES.ARM]="armfort", [SIDES.CORE]="corfort", [SIDES.LEGION]="legforti"})
    DefCat("SHIELD", {[SIDES.ARM]="armgate", [SIDES.CORE]="", [SIDES.LEGION]="legdeflector"})
    DefCat("MEDIUM_RANGE_MISSILE", {[SIDES.ARM]="armemp", [SIDES.CORE]="cortron", [SIDES.LEGION]="legperdition"})

    -- Intel and special buildings
    DefCat("RADAR", {[SIDES.ARM]="armrad", [SIDES.CORE]="corrad", [SIDES.LEGION]="legrad"})
    DefCat("ADVANCED_RADAR", {[SIDES.ARM]="armarad", [SIDES.CORE]="corarad", [SIDES.LEGION]="legarad"})
    DefCat("ADV_RADAR", {[SIDES.ARM]="armarad", [SIDES.CORE]="corarad", [SIDES.LEGION]="legarad"})
    DefCat("JAMMER", {[SIDES.ARM]="armjamt", [SIDES.CORE]="corjamt", [SIDES.LEGION]="legjam"})
    DefCat("ADVANCED_JAMMER", {[SIDES.ARM]="armveil", [SIDES.CORE]="corshroud", [SIDES.LEGION]="legajam"})
    DefCat("SONAR", {[SIDES.ARM]="armsonar", [SIDES.CORE]="corsonar", [SIDES.LEGION]="legsonar"})
    DefCat("ADV_SONAR", {[SIDES.ARM]="armason", [SIDES.CORE]="corason", [SIDES.LEGION]="legason"})
    DefCat("CAMERA", {[SIDES.ARM]="armeyes", [SIDES.CORE]="coreyes", [SIDES.LEGION]="legeyes"})
    DefCat("NUKE", {[SIDES.ARM]="armsilo", [SIDES.CORE]="corsilo", [SIDES.LEGION]="legsilo"})
    DefCat("ANTINUKE", {[SIDES.ARM]="armamd", [SIDES.CORE]="corfmd", [SIDES.LEGION]="legabm"})
    DefCat("JUNO", {[SIDES.ARM]="armjuno", [SIDES.CORE]="corjuno", [SIDES.LEGION]="legjuno"})
    DefCat("NANO_TOWER", {[SIDES.ARM]="armnanotc", [SIDES.CORE]="cornanotc", [SIDES.LEGION]="legnanotc"})
    DefCat("ADV_NANO_TOWER", {[SIDES.ARM]="armnanotct2", [SIDES.CORE]="cornanotct2", [SIDES.LEGION]="legnanotct2"})
    DefCat("STEALTH_DETECTION", {[SIDES.ARM]="armrsd", [SIDES.CORE]="corrsd", [SIDES.LEGION]="legsd"})
    DefCat("PINPOINTER", {[SIDES.ARM]="armtarg", [SIDES.CORE]="cortarg", [SIDES.LEGION]="legtarg"})

    -- Count and log results
    local unitCount = 0
    for _, units in pairs(categoryUnits) do
        for _, unit in pairs(units) do
            if unit then unitCount = unitCount + 1 end
        end
    end

    local categoryCount = 0
    for _ in pairs(UNIT_CATEGORIES) do categoryCount = categoryCount + 1 end

    Spring.Log("BlueprintDefs", LOG.INFO, string.format("Defined %d categories covering %d units. END", categoryCount, unitCount))
end

-- Return the definitions for importing
return BpDefs 