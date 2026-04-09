-- spec/Widgets/api_blueprint_spec.lua
--
-- Tests for the placeBlueprint function in api_blueprint.lua.
--
-- The function has two modes:
--
--   Sequential (isBuildSplit=false): builder groups are sorted by total build
--   power. Buildings are partitioned into cost-proportional chunks. Each
--   builder group works through its chunk in order. Buildings a group can't
--   construct (because the equivalent unit isn't in its buildOptions) become
--   "leftovers" that get redistributed to any capable group via round-robin.
--
--   Split (isBuildSplit=true): builders are grouped by faction. Buildings are
--   round-robined across capable factions. Within each faction, individual
--   builders take turns. In both modes, ARM blueprints placed with COR
--   builders are automatically substituted: armmex→cormex, armsolr→corsolr,
--   etc., via getEquivalentUnitDefID.
--
-- Test fixture
-- ============
--   Buildings (ARM): armmex=10, armsolr=11
--   Buildings (COR): cormex=20, corsolr=21
--
--   Builders:
--     armcon  defID=100  speed=100  builds {10,11}  (standard ARM con)
--     armhcon defID=101  speed=300  builds {10,11}  (heavy ARM con, 3× power)
--     armrcon defID=102  speed=200  builds {10}     (ARM recon con, armmex only)
--     corcon  defID=200  speed=100  builds {20,21}  (standard COR con)
--
--   Unit IDs:
--     1 = armcon   2 = armhcon   3 = armrcon   4 = corcon   5 = corcon (second)
--
--   Substitution: armmex(10)↔cormex(20),  armsolr(11)↔corsolr(21)
--
-- Uses setfenv to sandbox the widget — no global state is mutated.

-- ============================================================
-- Shared env builder
-- ============================================================

local function makeBaseEnv()
    local env = setmetatable({}, { __index = _G })

    env.widget        = {}
    env.GL            = {}
    env.Platform      = { gl = nil } -- isHeadless = true → skips initGL4()
    env.WG            = {}
    env.widgetHandler = { RemoveWidget = function() end, AddAction = function() end }
    env.UnitDefs      = {}
    env.UnitDefNames  = {}

    -- api_blueprint.lua captures gl.LuaShader / gl.InstanceVBOTable at load time
    env.gl = {
        LuaShader        = function() end,
        InstanceVBOTable = {
            pushElementInstance = function() end,
            popElementInstance  = function() end,
        },
    }

    env.Spring = setmetatable({
        Utilities                 = { IsDevMode = function() return false end },
        Echo                      = function() end,
        GetUnitDefID              = function() return nil end,
        ValidUnitID               = function() return false end,
        GiveOrderToUnit           = function() end,
        GiveOrderArrayToUnitArray = function() end,
        GetGroundHeight           = function() return 0 end,
        Pos2BuildPos              = function(_, x, y, z) return x, y, z end,
        GetUnitBuildFacing        = function() return 0 end,
        GetUnitPosition           = function() return 0, 0, 0 end,
        TestBuildOrder            = function() return 0 end,
        GetMyTeamID               = function() return 0 end,
    }, { __index = _G.Spring })

    return env
end

local function attachMinimalVFS(env)
    local realInclude = _G.VFS.Include
    env.VFS = setmetatable({
        Include = function(path, ...)
            if path == "luaui/Include/blueprint_substitution/definitions.lua" then
                return {
                    SIDES           = { ARMADA = "arm", CORTEX = "cor", LEGION = "leg" },
                    UNIT_CATEGORIES = {},
                    categoryUnits   = {},
                    unitCategories  = {},
                }
            elseif path == "luaui/Include/blueprint_substitution/logic.lua" then
                return {
                    SIDES                  = { ARMADA = "arm", CORTEX = "cor", LEGION = "leg" },
                    equivalentUnits        = {},
                    MasterBuildingData     = {},
                    unitCategories         = {},
                    getSideFromUnitName    = function() return nil end,
                    getEquivalentUnitDefID = function(name) return name end,
                }
            end
            return realInclude(path, ...)
        end,
    }, { __index = _G.VFS })
end

local function loadWidget(env)
    local chunk = assert(loadfile("luaui/Widgets/api_blueprint.lua"))
    setfenv(chunk, env)
    chunk()
    env.widget:Initialize()
    return env.WG["api_blueprint"].placeBlueprint
end

-- Minimal fixture — only enough to exercise early-exit guards.
local function loadPlaceBlueprint()
    local env = makeBaseEnv()
    attachMinimalVFS(env)
    local pb = loadWidget(env)
    return pb, env
end

-- Full fixture — realistic ARM/COR unit defs and substitution logic.
-- Used for algorithm tests.
local function loadWithFixture()
    local env = makeBaseEnv()

    -- ---- unit defs ----
    env.UnitDefs = {
        -- ARM buildings
        [10] = { name = "armmex",  buildSpeed = 0,   buildOptions = {}, cost = 100, xsize = 2, zsize = 2 },
        [11] = { name = "armsolr", buildSpeed = 0,   buildOptions = {}, cost = 100, xsize = 2, zsize = 2 },
        -- COR buildings
        [20] = { name = "cormex",  buildSpeed = 0,   buildOptions = {}, cost = 100, xsize = 2, zsize = 2 },
        [21] = { name = "corsolr", buildSpeed = 0,   buildOptions = {}, cost = 100, xsize = 2, zsize = 2 },
        -- ARM constructors
        [100] = { name = "armcon",  buildSpeed = 100, buildOptions = { 10, 11 }, cost = 0, xsize = 2, zsize = 2 },
        [101] = { name = "armhcon", buildSpeed = 300, buildOptions = { 10, 11 }, cost = 0, xsize = 2, zsize = 2 },
        [102] = { name = "armrcon", buildSpeed = 200, buildOptions = { 10 },     cost = 0, xsize = 2, zsize = 2 },
        -- COR constructors
        [200] = { name = "corcon",  buildSpeed = 100, buildOptions = { 20, 21 }, cost = 0, xsize = 2, zsize = 2 },
    }

    -- unit ID → unitDefID (unit IDs are the in-game identifiers for builder instances)
    local unitIDToDefID = { [1] = 100, [2] = 101, [3] = 102, [4] = 200, [5] = 200 }
    env.Spring.GetUnitDefID = function(id) return unitIDToDefID[id] end

    -- ---- SubLogic substitution ----
    local sideByName = {
        armmex  = "arm", armsolr = "arm",
        armcon  = "arm", armhcon = "arm", armrcon = "arm",
        cormex  = "cor", corsolr = "cor", corcon  = "cor",
    }
    -- arm↔cor substitution by defID
    local armToCor = { [10] = 20, [11] = 21 }
    local corToArm = { [20] = 10, [21] = 11 }

    -- ---- VFS mock with real substitution logic ----
    local realInclude = _G.VFS.Include
    env.VFS = setmetatable({
        Include = function(path, ...)
            if path == "luaui/Include/blueprint_substitution/definitions.lua" then
                return {
                    SIDES           = { ARMADA = "arm", CORTEX = "cor", LEGION = "leg" },
                    UNIT_CATEGORIES = {},
                    categoryUnits   = {},
                    unitCategories  = {},
                }
            elseif path == "luaui/Include/blueprint_substitution/logic.lua" then
                return {
                    SIDES               = { ARMADA = "arm", CORTEX = "cor", LEGION = "leg" },
                    equivalentUnits     = {},
                    MasterBuildingData  = {},
                    unitCategories      = {},
                    getSideFromUnitName = function(name) return sideByName[name] end,
                    -- Returns the defID of the equivalent unit on targetSide.
                    -- Identity if no cross-faction substitution exists.
                    getEquivalentUnitDefID = function(unitDefID, targetSide)
                        if targetSide == "arm" then return corToArm[unitDefID] or unitDefID end
                        if targetSide == "cor" then return armToCor[unitDefID] or unitDefID end
                        return unitDefID
                    end,
                }
            end
            return realInclude(path, ...)
        end,
    }, { __index = _G.VFS })

    local pb = loadWidget(env)
    return pb, env
end

-- ============================================================
-- Fixture helpers
-- ============================================================

--- Spy: captures every GiveOrderArrayToUnitArray call (sequential mode).
--- Returns the captured-calls table.
local function captureArrayOrders(env)
    local calls = {}
    env.Spring.GiveOrderArrayToUnitArray = function(unitIDs, orders, _)
        table.insert(calls, { unitIDs = unitIDs, orders = orders })
    end
    return calls
end

--- Spy: captures every GiveOrderToUnit call (split mode).
local function captureUnitOrders(env)
    local calls = {}
    env.Spring.GiveOrderToUnit = function(unitID, cmdID, _, _)
        table.insert(calls, { unitID = unitID, cmdID = cmdID })
    end
    return calls
end

--- Extract the positive building defIDs from a GiveOrderArrayToUnitArray
--- orders list (each element is {negativeDefID, params, opts}).
local function orderDefIDs(orders)
    local ids = {}
    for _, order in ipairs(orders) do
        table.insert(ids, -order[1])
    end
    return ids
end

--- Convenience: build a simple ARM blueprint from a list of BlueprintUnit tables.
local function armBlueprint(units)
    return { units = units, name = "test", spacing = 0, facing = 0 }
end

--- Convenience: a single build-position at the origin.
local ORIGIN = { { 0, 0, 0 } }

-- ============================================================
-- Tests
-- ============================================================

describe("api_blueprint.placeBlueprint", function()

    -- ----------------------------------------------------------------
    -- Guard: nil / empty inputs
    -- ----------------------------------------------------------------

    describe("nil and empty input guards", function()
        local placeBlueprint, env

        before_each(function()
            placeBlueprint, env = loadPlaceBlueprint()
        end)

        it("does not error when blueprint is nil", function()
            assert.has_no.errors(function()
                placeBlueprint(nil, { { 0, 0, 0 } }, {}, false, {})
            end)
        end)

        it("does not error when buildPositions is nil", function()
            assert.has_no.errors(function()
                placeBlueprint({ units = {}, name = "t", spacing = 0, facing = 0 }, nil, {}, false, {})
            end)
        end)

        it("issues no orders when buildPositions is empty", function()
            local called = false
            env.Spring.GiveOrderArrayToUnitArray = function() called = true end
            env.Spring.GiveOrderToUnit           = function() called = true end
            placeBlueprint({ units = {}, name = "t", spacing = 0, facing = 0 }, {}, {}, false, {})
            assert.is_false(called)
        end)
    end)

    -- ----------------------------------------------------------------
    -- Guard: split mode with no usable builders
    -- ----------------------------------------------------------------

    describe("split mode builder guards", function()
        local placeBlueprint, env

        before_each(function()
            placeBlueprint, env = loadPlaceBlueprint()
        end)

        it("issues no orders when builders list is empty", function()
            local called = false
            env.Spring.GiveOrderToUnit = function() called = true end
            placeBlueprint({ units = {}, name = "t", spacing = 0, facing = 0 }, { { 0, 0, 0 } }, {}, true, {})
            assert.is_false(called)
        end)

        it("issues no orders when no builder has a valid unit def", function()
            local called = false
            env.Spring.GiveOrderToUnit = function() called = true end
            -- GetUnitDefID returns nil for all ids (default mock)
            placeBlueprint({ units = {}, name = "t", spacing = 0, facing = 0 }, { { 0, 0, 0 } }, { 100, 101 }, true, {})
            assert.is_false(called)
        end)
    end)

    -- ----------------------------------------------------------------
    -- Guard: normal mode with zero total build power
    -- ----------------------------------------------------------------

    describe("normal mode builder guards", function()
        local placeBlueprint, env

        before_each(function()
            placeBlueprint, env = loadPlaceBlueprint()
        end)

        it("issues no orders when all builders have zero build speed", function()
            env.Spring.GetUnitDefID = function(id) if id == 1 then return 42 end return nil end
            env.UnitDefs[42] = { name = "armcon", buildSpeed = 0, buildOptions = {} }

            local called = false
            env.Spring.GiveOrderArrayToUnitArray = function() called = true end
            placeBlueprint({ units = {}, name = "t", spacing = 0, facing = 0 }, { { 0, 0, 0 } }, { 1 }, false, {})
            assert.is_false(called)
        end)
    end)

    -- ----------------------------------------------------------------
    -- Sequential mode: proportional distribution
    --
    -- Builder groups are sorted by total build power (count × speed).
    -- The building list (ordered by blueprint placement) is partitioned
    -- into cost-proportional slices. The highest-power group gets the
    -- first (largest) slice; the last group takes all remaining buildings.
    -- Buildings a group cannot construct become "leftovers" and are
    -- round-robined across any capable groups.
    -- ----------------------------------------------------------------

    describe("sequential mode", function()
        local placeBlueprint, env

        before_each(function()
            placeBlueprint, env = loadWithFixture()
        end)

        it("same-faction: ARM builder with ARM blueprint issues ARM defID orders", function()
            -- armcon (ARM, speed=100) receives an ARM blueprint.
            -- No substitution needed; orders use the original ARM defIDs.
            local calls = captureArrayOrders(env)

            placeBlueprint(
                armBlueprint({
                    { blueprintUnitID = 1, unitDefID = 10, position = { 0,  0, 0 }, facing = 0, originalName = "armmex"  },
                    { blueprintUnitID = 2, unitDefID = 11, position = { 16, 0, 0 }, facing = 0, originalName = "armsolr" },
                }),
                ORIGIN,
                { 1 }, -- U_ARM_CON
                false,
                {}
            )

            assert.equals(1, #calls)
            assert.same({ 1 }, calls[1].unitIDs)
            assert.same({ 10, 11 }, orderDefIDs(calls[1].orders))
        end)

        it("cross-faction substitution: COR builder with ARM blueprint issues COR defID orders", function()
            -- corcon (COR, speed=100) receives an ARM blueprint.
            -- getEquivalentUnitDefID substitutes armmex(10)→cormex(20) and
            -- armsolr(11)→corsolr(21) so corcon can build them.
            -- This documents the bug that was fixed: passing a string name
            -- instead of a numeric defID to getEquivalentUnitDefID caused
            -- canBuild() to always return false for cross-faction placements.
            local calls = captureArrayOrders(env)

            placeBlueprint(
                armBlueprint({
                    { blueprintUnitID = 1, unitDefID = 10, position = { 0,  0, 0 }, facing = 0, originalName = "armmex"  },
                    { blueprintUnitID = 2, unitDefID = 11, position = { 16, 0, 0 }, facing = 0, originalName = "armsolr" },
                }),
                ORIGIN,
                { 4 }, -- U_COR_CON
                false,
                {}
            )

            assert.equals(1, #calls)
            assert.same({ 4 }, calls[1].unitIDs)
            -- Substituted to COR equivalents, not the original ARM defIDs
            assert.same({ 20, 21 }, orderDefIDs(calls[1].orders))
        end)

        it("distributes buildings proportionally by build power (3:1 for armhcon:armcon)", function()
            -- armhcon (speed=300, power=300) and armcon (speed=100, power=100).
            -- totalPower=400. For 4 equal-cost buildings:
            --   armhcon targets 75% of cost → gets 3 buildings (indices 1-3)
            --   armcon  takes  all remaining → gets 1 building  (index 4)
            -- Groups are sorted by power DESC, so armhcon processes first.
            local calls = captureArrayOrders(env)

            placeBlueprint(
                armBlueprint({
                    { blueprintUnitID = 1, unitDefID = 10, position = {  0, 0, 0 }, facing = 0, originalName = "armmex" },
                    { blueprintUnitID = 2, unitDefID = 10, position = { 16, 0, 0 }, facing = 0, originalName = "armmex" },
                    { blueprintUnitID = 3, unitDefID = 10, position = { 32, 0, 0 }, facing = 0, originalName = "armmex" },
                    { blueprintUnitID = 4, unitDefID = 10, position = { 48, 0, 0 }, facing = 0, originalName = "armmex" },
                }),
                ORIGIN,
                { 1, 2 }, -- U_ARM_CON + U_ARM_HCON
                false,
                {}
            )

            assert.equals(2, #calls, "expected one GiveOrderArrayToUnitArray call per builder group")

            -- Identify which call belongs to which builder group
            local hconCall, conCall
            for _, c in ipairs(calls) do
                if c.unitIDs[1] == 2 then hconCall = c end
                if c.unitIDs[1] == 1 then conCall  = c end
            end

            assert.is_not_nil(hconCall, "armhcon (unitID=2) should receive orders")
            assert.is_not_nil(conCall,  "armcon  (unitID=1) should receive orders")
            -- 3:1 power ratio → 3:1 building split
            assert.equals(3, #hconCall.orders, "armhcon (power=300) should get 3 of 4 buildings")
            assert.equals(1, #conCall.orders,  "armcon  (power=100) should get 1 of 4 buildings")
        end)

        it("leftovers: buildings a group cannot build are redistributed to capable groups", function()
            -- armrcon (speed=200, power=200) can only build armmex (defID=10).
            -- Blueprint is [armsolr, armsolr, armsolr, armmex].
            --
            -- Proportional cut (totalPower=300, totalCost=400):
            --   armrcon proportion=0.67, targetCost≈267 → chunk = [armsolr×3]
            --   armcon  is last group → chunk = [armmex×1]
            --
            -- armrcon cannot build any armsolr → all 3 become leftovers.
            -- Leftovers are redistributed: armcon is the only capable group,
            -- so armcon ends up with all 4 orders (1 armmex + 3 armsolr).
            local calls = captureArrayOrders(env)

            placeBlueprint(
                armBlueprint({
                    { blueprintUnitID = 1, unitDefID = 11, position = {  0, 0, 0 }, facing = 0, originalName = "armsolr" },
                    { blueprintUnitID = 2, unitDefID = 11, position = { 16, 0, 0 }, facing = 0, originalName = "armsolr" },
                    { blueprintUnitID = 3, unitDefID = 11, position = { 32, 0, 0 }, facing = 0, originalName = "armsolr" },
                    { blueprintUnitID = 4, unitDefID = 10, position = { 48, 0, 0 }, facing = 0, originalName = "armmex"  },
                }),
                ORIGIN,
                { 1, 3 }, -- U_ARM_CON + U_ARM_RCON
                false,
                {}
            )

            -- armrcon gets no orders (nothing in its proportional chunk was buildable)
            for _, c in ipairs(calls) do
                assert.not_equals(3, c.unitIDs[1], "armrcon (unitID=3) should not receive any orders")
            end

            -- armcon receives all 4: the 1 armmex from its own chunk plus the
            -- 3 armsolr leftovers that armrcon could not build
            local conCall
            for _, c in ipairs(calls) do
                if c.unitIDs[1] == 1 then conCall = c end
            end
            assert.is_not_nil(conCall, "armcon (unitID=1) should receive all redistributed orders")
            assert.equals(4, #conCall.orders)
            -- chunk order first (armmex from armcon's own slice), then leftovers
            assert.same({ 10, 11, 11, 11 }, orderDefIDs(conCall.orders))
        end)
    end)

    -- ----------------------------------------------------------------
    -- Split mode: round-robin distribution
    --
    -- Builders are grouped by faction (side). For each unique building
    -- type, capable factions are determined and buildings are round-robined
    -- across them. Within each faction, individual builders take turns.
    -- Buildings are always issued using the receiving faction's own defIDs.
    -- ----------------------------------------------------------------

    describe("split mode", function()
        local placeBlueprint, env

        before_each(function()
            placeBlueprint, env = loadWithFixture()
        end)

        it("same-faction: two COR builders interleave orders round-robin and receive COR defIDs", function()
            -- Two corcon builders (unitIDs 4 and 5) receive an ARM blueprint with
            -- 4 buildings. Only COR faction is present, so all buildings go to COR.
            -- Within COR, builder 4 and builder 5 alternate:
            --   building 1 → builder 4,  building 2 → builder 5,
            --   building 3 → builder 4,  building 4 → builder 5.
            -- All orders use COR defIDs (armmex→cormex=20, armsolr→corsolr=21).
            local calls = captureUnitOrders(env)

            placeBlueprint(
                armBlueprint({
                    { blueprintUnitID = 1, unitDefID = 10, position = {  0, 0, 0 }, facing = 0, originalName = "armmex"  },
                    { blueprintUnitID = 2, unitDefID = 10, position = { 16, 0, 0 }, facing = 0, originalName = "armmex"  },
                    { blueprintUnitID = 3, unitDefID = 11, position = { 32, 0, 0 }, facing = 0, originalName = "armsolr" },
                    { blueprintUnitID = 4, unitDefID = 11, position = { 48, 0, 0 }, facing = 0, originalName = "armsolr" },
                }),
                ORIGIN,
                { 4, 5 }, -- U_COR_CON + U_COR_CON2
                true,
                {}
            )

            assert.equals(4, #calls, "one GiveOrderToUnit call per building")

            -- Each builder should receive exactly 2 orders
            local by4, by5 = {}, {}
            for _, c in ipairs(calls) do
                if c.unitID == 4 then table.insert(by4, c) end
                if c.unitID == 5 then table.insert(by5, c) end
            end
            assert.equals(2, #by4, "builder 4 should receive 2 orders (round-robin)")
            assert.equals(2, #by5, "builder 5 should receive 2 orders (round-robin)")

            -- Every order must use COR defIDs, not the original ARM defIDs
            for _, c in ipairs(calls) do
                assert.is_true(
                    c.cmdID == -20 or c.cmdID == -21,
                    "expected COR defID -20 (cormex) or -21 (corsolr), got " .. tostring(c.cmdID)
                )
            end
        end)

        it("two-faction: each faction's builders receive their own faction's defIDs", function()
            -- armcon (ARM) and corcon (COR) each get one of the two armmex buildings
            -- via round-robin across capable factions. ARM keeps defID 10 (armmex);
            -- COR gets defID 20 (cormex) via ARM→COR substitution.
            -- This verifies that split mode performs per-faction substitution
            -- independently, so neither faction ever receives the other's defIDs.
            local calls = captureUnitOrders(env)

            placeBlueprint(
                armBlueprint({
                    { blueprintUnitID = 1, unitDefID = 10, position = {  0, 0, 0 }, facing = 0, originalName = "armmex" },
                    { blueprintUnitID = 2, unitDefID = 10, position = { 16, 0, 0 }, facing = 0, originalName = "armmex" },
                }),
                ORIGIN,
                { 1, 4 }, -- U_ARM_CON + U_COR_CON
                true,
                {}
            )

            assert.equals(2, #calls, "one order per building")

            local armOrder, corOrder
            for _, c in ipairs(calls) do
                if c.unitID == 1 then armOrder = c end
                if c.unitID == 4 then corOrder = c end
            end

            assert.is_not_nil(armOrder, "armcon (unitID=1) should receive an order")
            assert.is_not_nil(corOrder, "corcon (unitID=4) should receive an order")

            -- ARM builder keeps the original ARM defID
            assert.equals(-10, armOrder.cmdID, "ARM builder should receive armmex defID (10)")
            -- COR builder gets the COR-substituted defID
            assert.equals(-20, corOrder.cmdID, "COR builder should receive cormex defID (20), not armmex (10)")
        end)
    end)
end)
