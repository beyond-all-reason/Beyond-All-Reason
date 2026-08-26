require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

-- Mock tracking; action only calls tracking.TrackUnit at runtime.
local trackedUnitIDs   = {}
local trackedUnitNames = {}
GG['MissionAPI'].trackedUnitIDs   = trackedUnitIDs
GG['MissionAPI'].trackedUnitNames = trackedUnitNames
GG['MissionAPI'].Modules.Tracking = {
    TrackUnit = function(name, id)
        trackedUnitIDs[name]       = trackedUnitIDs[name] or {}
        trackedUnitIDs[name][id]   = true
        trackedUnitNames[id]       = trackedUnitNames[id] or {}
        trackedUnitNames[id][name] = true
    end,
}

-- Mock Spring unit query functions. These are shared across the whole busted
-- run, so the originals are kept and restored in after_each; leaving them
-- replaced changes what later spec files see (an empty allyTeam list, say).
local SPRING_QUERIES = {
    'GetTeamUnits',
    'GetTeamUnitsByDefs',
    'GetAllyTeamList',
    'GetTeamList',
    'GetUnitsInRectangle',
    'GetUnitsInCylinder',
}

local savedSpringQueries = {}
local savedUnitDefNames

local function installEmptyQueries()
    _G.UnitDefNames = {}
    for _, name in ipairs(SPRING_QUERIES) do
        Spring[name] = function() return {} end
    end
end

local function saveEngineGlobals()
    savedUnitDefNames = _G.UnitDefNames
    for _, name in ipairs(SPRING_QUERIES) do
        savedSpringQueries[name] = Spring[name]
    end
end

local function restoreEngineGlobals()
    _G.UnitDefNames = savedUnitDefNames
    for _, name in ipairs(SPRING_QUERIES) do
        Spring[name] = savedSpringQueries[name]
    end
end

saveEngineGlobals()
installEmptyQueries()

local actions  = VFS.Include('luarules/mission_api/actions/units/name_units.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local function clearTracking()
    for k in pairs(trackedUnitIDs)   do trackedUnitIDs[k]   = nil end
    for k in pairs(trackedUnitNames) do trackedUnitNames[k] = nil end
end

describe("mission_api.actions.name_units", function()

    before_each(function()
        clearTracking()
        installEmptyQueries()
    end)

    after_each(function()
        restoreEngineGlobals()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type          = 'NameUnits',
            unitName      = 'UnitName!',
            teamID        = 'Number',
            unitDefName   = 'String',
            area          = 'Area',
            requiresOneOf = { 'teamID', 'unitDefName', 'area' },
        }, summarizeSchema(action))
    end)

    describe("actionFunction - teamID only", function()
        it("tracks all units returned by GetTeamUnits", function()
            Spring.GetTeamUnits = function(teamID) return { 10, 11, 12 } end
            action.actionFunction('bots', 1, nil, nil)
            assert.is_not_nil(trackedUnitIDs['bots'])
            assert.is_true(trackedUnitIDs['bots'][10] == true)
            assert.is_true(trackedUnitIDs['bots'][11] == true)
            assert.is_true(trackedUnitIDs['bots'][12] == true)
        end)

        it("tracks nothing when the team has no units", function()
            Spring.GetTeamUnits = function() return {} end
            action.actionFunction('empty', 1, nil, nil)
            assert.is_nil(trackedUnitIDs['empty'])
        end)
    end)

    describe("actionFunction - unitDefName filter", function()
        it("tracks units matching the unitDefName from all teams when teamID is nil", function()
            _G.UnitDefNames = { mybot = { id = 7 } }
            Spring.GetAllyTeamList    = function() return { 0 } end
            Spring.GetTeamList        = function() return { 1 } end
            Spring.GetTeamUnitsByDefs = function(teamID, defID)
                if defID == 7 then return { 50, 51 } end
                return {}
            end
            action.actionFunction('bots', nil, 'mybot', nil)
            assert.is_true(trackedUnitIDs['bots'][50] == true)
            assert.is_true(trackedUnitIDs['bots'][51] == true)
        end)

        it("tracks units by def within a specific team when teamID is also provided", function()
            _G.UnitDefNames = { tank = { id = 3 } }
            Spring.GetTeamUnitsByDefs = function(teamID, defID)
                return { 100 }
            end
            action.actionFunction('tanks', 2, 'tank', nil)
            assert.is_true(trackedUnitIDs['tanks'][100] == true)
        end)

        it("skips tracking when unitDefName is not in UnitDefNames", function()
            _G.UnitDefNames = {}
            action.actionFunction('ghosts', nil, 'unknown', nil)
            assert.is_nil(trackedUnitIDs['ghosts'])
        end)
    end)

    describe("actionFunction - area filter (rectangle)", function()
        it("tracks units returned by GetUnitsInRectangle", function()
            Spring.GetUnitsInRectangle = function(x1, z1, x2, z2, teamID)
                return { 200, 201 }
            end
            local area = { x1 = 0, z1 = 0, x2 = 10, z2 = 10 }
            action.actionFunction('zone', nil, nil, area)
            assert.is_true(trackedUnitIDs['zone'][200] == true)
            assert.is_true(trackedUnitIDs['zone'][201] == true)
        end)
    end)

    describe("actionFunction - area filter (circle)", function()
        it("tracks units returned by GetUnitsInCylinder", function()
            Spring.GetUnitsInCylinder = function(x, z, radius, teamID)
                return { 300 }
            end
            local area = { x = 5, z = 5, radius = 100 }
            action.actionFunction('circle', nil, nil, area)
            assert.is_true(trackedUnitIDs['circle'][300] == true)
        end)
    end)

end)
