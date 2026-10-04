local Builders = VFS.Include("spec/builders/index.lua")

describe("UnitDefs", function()
    local unitDefs
    before_each(function()
        local spring = Builders.Spring.new():WithRealUnitDefs():Build()
        unitDefs = spring:GetUnitDefs()
    end)

    it("should be loaded", function()
        assert.is_table(unitDefs)
        -- Count actual entries in the hash table (UnitDefs uses string keys)
        local count = 0
        for k, v in pairs(unitDefs) do
            assert.is_string(k)
            assert.is_table(v)
            count = count + 1
        end
        assert.is_true(count > 1700)
    end)

    it("should have valid structure", function()
        local testUnits = {"armcom", "corcom", "armpw", "corak"}
        for _, unitName in ipairs(testUnits) do
            local unitDef = unitDefs[unitName]
            assert.is_table(unitDef)
            -- Unit definitions should have basic properties
            assert.is_number(unitDef.maxDamage or unitDef.health)
        end
    end)
end)