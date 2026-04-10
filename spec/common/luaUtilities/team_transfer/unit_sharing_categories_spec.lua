local Categories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")

describe("unit_sharing_categories #categories", function()
    describe("classifyUnitDef", function()
        it("should classify a T1 air transport as Transport", function()
            local def = { canFly = true, transportCapacity = 8, customParams = { techlevel = "1" } }
            assert.equal(TransferEnums.UnitType.Transport, Categories.classifyUnitDef(def))
        end)

        it("should classify a T2 constructor as T2Constructor", function()
            local def = {
                isFactory = false,
                canAssist = true,
                buildOptions = { "someunit" },
                customParams = { techlevel = "2" },
            }
            assert.equal(TransferEnums.UnitType.T2Constructor, Categories.classifyUnitDef(def))
        end)

        it("should classify a T1 constructor as Production", function()
            local def = {
                canAssist = true,
                isFactory = false,
                buildOptions = { "someunit" },
                customParams = { techlevel = "1" },
            }
            assert.equal(TransferEnums.UnitType.Production, Categories.classifyUnitDef(def))
        end)

        it("should classify a factory as Production", function()
            local def = { isFactory = true, customParams = {} }
            assert.equal(TransferEnums.UnitType.Production, Categories.classifyUnitDef(def))
        end)

        it("should classify energy buildings as Resource", function()
            local def = { customParams = { unitgroup = "energy" } }
            assert.equal(TransferEnums.UnitType.Resource, Categories.classifyUnitDef(def))
        end)

        it("should classify metal extractors as Resource", function()
            local def = { customParams = { unitgroup = "metal" } }
            assert.equal(TransferEnums.UnitType.Resource, Categories.classifyUnitDef(def))
        end)

        it("should classify util buildings as Utility", function()
            local def = { customParams = { unitgroup = "util" } }
            assert.equal(TransferEnums.UnitType.Utility, Categories.classifyUnitDef(def))
        end)

        it("should classify armed units as Combat", function()
            local def = { weapons = { "gun" }, customParams = {} }
            assert.equal(TransferEnums.UnitType.Combat, Categories.classifyUnitDef(def))
        end)

        it("should classify weapon-group units as Combat", function()
            local def = { customParams = { unitgroup = "weapon" } }
            assert.equal(TransferEnums.UnitType.Combat, Categories.classifyUnitDef(def))
        end)

        it("should default to Combat for unrecognized units", function()
            local def = { customParams = {} }
            assert.equal(TransferEnums.UnitType.Combat, Categories.classifyUnitDef(def))
        end)

        it("should prioritize Transport over Combat for armed transports", function()
            local def = {
                canFly = true, transportCapacity = 4,
                weapons = { "gun" },
                customParams = { techlevel = "1" },
            }
            assert.equal(TransferEnums.UnitType.Transport, Categories.classifyUnitDef(def))
        end)

        it("should prioritize Production over Resource for assist-capable energy buildings", function()
            local def = { canAssist = true, customParams = { unitgroup = "energy" } }
            assert.equal(TransferEnums.UnitType.Production, Categories.classifyUnitDef(def))
        end)
    end)

    describe("isT1TransportDef", function()
        it("should return true for T1 flying transports", function()
            assert.is_true(Categories.isT1TransportDef(
                { canFly = true, transportCapacity = 8, customParams = { techlevel = "1" } }))
        end)

        it("should return true when techlevel is nil (defaults to T1)", function()
            assert.is_true(Categories.isT1TransportDef(
                { canFly = true, transportCapacity = 4, customParams = {} }))
        end)

        it("should return false for T2 transports", function()
            assert.is_false(Categories.isT1TransportDef(
                { canFly = true, transportCapacity = 8, customParams = { techlevel = "2" } }))
        end)

        it("should return false for non-flying units", function()
            assert.is_false(Categories.isT1TransportDef(
                { canFly = false, transportCapacity = 8, customParams = { techlevel = "1" } }))
        end)

        it("should return false for flying units without transport capacity", function()
            assert.is_false(Categories.isT1TransportDef(
                { canFly = true, transportCapacity = 0, customParams = { techlevel = "1" } }))
        end)
    end)

    describe("isT2ConstructorDef", function()
        it("should return true for T2 builders with build options", function()
            assert.is_true(Categories.isT2ConstructorDef(
                { isFactory = false, buildOptions = { "a" }, customParams = { techlevel = "2" } }))
        end)

        it("should return false for factories even at T2", function()
            assert.is_false(Categories.isT2ConstructorDef(
                { isFactory = true, buildOptions = { "a" }, customParams = { techlevel = "2" } }))
        end)

        it("should return false for T1 builders", function()
            assert.is_false(Categories.isT2ConstructorDef(
                { isFactory = false, buildOptions = { "a" }, customParams = { techlevel = "1" } }))
        end)

        it("should return false for T2 units without build options", function()
            assert.is_false(Categories.isT2ConstructorDef(
                { isFactory = false, buildOptions = {}, customParams = { techlevel = "2" } }))
        end)
    end)

    describe("isCombatUnitDef", function()
        it("should return true for weapon-group units", function()
            assert.is_true(Categories.isCombatUnitDef({ customParams = { unitgroup = "weapon" } }))
        end)

        it("should return true for aa-group units", function()
            assert.is_true(Categories.isCombatUnitDef({ customParams = { unitgroup = "aa" } }))
        end)

        it("should return true for sub-group units", function()
            assert.is_true(Categories.isCombatUnitDef({ customParams = { unitgroup = "sub" } }))
        end)

        it("should return true for nuke-group units", function()
            assert.is_true(Categories.isCombatUnitDef({ customParams = { unitgroup = "nuke" } }))
        end)

        it("should return true for units with weapons list", function()
            assert.is_true(Categories.isCombatUnitDef({ weapons = { "gun" }, customParams = {} }))
        end)

        it("should return false for unarmed non-combat units", function()
            assert.is_false(Categories.isCombatUnitDef({ customParams = { unitgroup = "energy" } }))
        end)

        it("should return false for units with empty weapons list", function()
            assert.is_false(Categories.isCombatUnitDef({ weapons = {}, customParams = {} }))
        end)
    end)

    describe("isProductionUnitDef", function()
        it("should return true for assist-capable units", function()
            assert.is_true(Categories.isProductionUnitDef({ canAssist = true }))
        end)

        it("should return true for factories", function()
            assert.is_true(Categories.isProductionUnitDef({ isFactory = true }))
        end)

        it("should return true for builder units", function()
            assert.is_true(Categories.isProductionUnitDef({ isBuilder = true }))
        end)

        it("should return false for non-production units", function()
            assert.is_false(Categories.isProductionUnitDef({ customParams = { unitgroup = "weapon" } }))
        end)
    end)

    describe("isResourceUnitDef", function()
        it("should return true for energy buildings", function()
            assert.is_true(Categories.isResourceUnitDef({ customParams = { unitgroup = "energy" } }))
        end)

        it("should return true for metal buildings", function()
            assert.is_true(Categories.isResourceUnitDef({ customParams = { unitgroup = "metal" } }))
        end)

        it("should return false for util buildings", function()
            assert.is_false(Categories.isResourceUnitDef({ customParams = { unitgroup = "util" } }))
        end)

        it("should return false for combat units", function()
            assert.is_false(Categories.isResourceUnitDef({ customParams = { unitgroup = "weapon" } }))
        end)
    end)

    describe("isUtilityUnitDef", function()
        it("should return true for util buildings", function()
            assert.is_true(Categories.isUtilityUnitDef({ customParams = { unitgroup = "util" } }))
        end)

        it("should return false for energy buildings", function()
            assert.is_false(Categories.isUtilityUnitDef({ customParams = { unitgroup = "energy" } }))
        end)

        it("should return false for combat units", function()
            assert.is_false(Categories.isUtilityUnitDef({ customParams = { unitgroup = "weapon" } }))
        end)

        it("should return false for units without customParams", function()
            assert.is_false(Categories.isUtilityUnitDef({}))
        end)
    end)
end)
