local Categories = VFS.Include("common/luaUtilities/team_transfer/unit_sharing_categories.lua")
local TransferEnums = VFS.Include("common/luaUtilities/team_transfer/transfer_enums.lua")

describe("unit_sharing_categories #categories", function()
    describe("classifyUnitDef", function()
        it("should classify commanders as Commander", function()
            local def = { customParams = { iscommander = "1" }, weapons = { "gun" }, isBuilder = true }
            assert.equal(TransferEnums.UnitType.Commander, Categories.classifyUnitDef(def))
        end)

        it("should classify air transports as Combat", function()
            local def = { canFly = true, transportCapacity = 8, customParams = {} }
            assert.equal(TransferEnums.UnitType.Combat, Categories.classifyUnitDef(def))
        end)

        it("should classify armed units as Combat", function()
            local def = { weapons = { "gun" }, customParams = {} }
            assert.equal(TransferEnums.UnitType.Combat, Categories.classifyUnitDef(def))
        end)

        it("should classify weapon-group units as Combat", function()
            local def = { customParams = { unitgroup = "weapon" } }
            assert.equal(TransferEnums.UnitType.Combat, Categories.classifyUnitDef(def))
        end)

        it("should classify mobile constructors as Constructor", function()
            local def = { isBuilder = true, isFactory = false, customParams = { techlevel = "1" } }
            assert.equal(TransferEnums.UnitType.Constructor, Categories.classifyUnitDef(def))
        end)

        it("should classify con turrets (assist, not factory) as Constructor", function()
            local def = { canAssist = true, isFactory = false, customParams = {} }
            assert.equal(TransferEnums.UnitType.Constructor, Categories.classifyUnitDef(def))
        end)

        it("should classify T2 constructors as Constructor (tech-agnostic)", function()
            local def = { isBuilder = true, isFactory = false, customParams = { techlevel = "2" } }
            assert.equal(TransferEnums.UnitType.Constructor, Categories.classifyUnitDef(def))
        end)

        it("should classify fast T2 engineers (corfast/armfark/armconsul) as Combat", function()
            for _, name in ipairs({ "corfast", "armfark", "armconsul" }) do
                local def = { name = name, isBuilder = true, isFactory = false, customParams = { techlevel = "2" } }
                assert.equal(TransferEnums.UnitType.Combat, Categories.classifyUnitDef(def))
            end
        end)

        it("should classify factories as Factory", function()
            local def = { isFactory = true, isBuilder = true, customParams = {} }
            assert.equal(TransferEnums.UnitType.Factory, Categories.classifyUnitDef(def))
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

        it("should default to Combat for unrecognized units", function()
            local def = { customParams = {} }
            assert.equal(TransferEnums.UnitType.Combat, Categories.classifyUnitDef(def))
        end)

        it("should classify armed transports as Combat (weapons win)", function()
            local def = { canFly = true, transportCapacity = 4, weapons = { "gun" }, customParams = {} }
            assert.equal(TransferEnums.UnitType.Combat, Categories.classifyUnitDef(def))
        end)

        it("should prioritize Constructor over Resource for assist-capable energy buildings", function()
            local def = { canAssist = true, isFactory = false, customParams = { unitgroup = "energy" } }
            assert.equal(TransferEnums.UnitType.Constructor, Categories.classifyUnitDef(def))
        end)
    end)

    describe("isTransportDef", function()
        it("should return true for flying transports (any tech)", function()
            assert.is_true(Categories.isTransportDef(
                { canFly = true, transportCapacity = 8, customParams = { techlevel = "2" } }))
        end)

        it("should return false for non-flying units", function()
            assert.is_false(Categories.isTransportDef({ canFly = false, transportCapacity = 8 }))
        end)

        it("should return false for flying units without transport capacity", function()
            assert.is_false(Categories.isTransportDef({ canFly = true, transportCapacity = 0 }))
        end)
    end)

    describe("isConstructorDef", function()
        it("should return true for mobile builders", function()
            assert.is_true(Categories.isConstructorDef({ isBuilder = true, isFactory = false }))
        end)

        it("should return true for assist-capable units (con turrets)", function()
            assert.is_true(Categories.isConstructorDef({ canAssist = true, isFactory = false }))
        end)

        it("should return false for factories", function()
            assert.is_false(Categories.isConstructorDef({ isBuilder = true, isFactory = true }))
        end)

        it("should return false for non-builders", function()
            assert.is_false(Categories.isConstructorDef({ customParams = { unitgroup = "weapon" } }))
        end)
    end)

    describe("isMobileBuilderDef", function()
        it("should return true for mobile builders", function()
            assert.is_true(Categories.isMobileBuilderDef({ isBuilder = true }))
        end)

        it("should return false for immobile builders (nano/con turrets)", function()
            assert.is_false(Categories.isMobileBuilderDef({ isBuilder = true, isImmobile = true }))
        end)

        it("should return false for assist-only turrets that are not builders", function()
            assert.is_false(Categories.isMobileBuilderDef({ canAssist = true }))
        end)

        it("should return false for factories", function()
            assert.is_false(Categories.isMobileBuilderDef({ isBuilder = true, isFactory = true }))
        end)

        it("should return false for non-builders", function()
            assert.is_false(Categories.isMobileBuilderDef({ customParams = { unitgroup = "weapon" } }))
        end)
    end)

    describe("isCombatGroupBuilderDef", function()
        it("should return true for the listed fast T2 engineers", function()
            for _, name in ipairs({ "corfast", "armfark", "armconsul" }) do
                assert.is_true(Categories.isCombatGroupBuilderDef({ name = name, isBuilder = true }))
            end
        end)

        it("should return false for other builders", function()
            assert.is_false(Categories.isCombatGroupBuilderDef({ name = "armck", isBuilder = true }))
        end)

        it("should return false when name is absent", function()
            assert.is_false(Categories.isCombatGroupBuilderDef({ isBuilder = true }))
        end)
    end)

    describe("isFactoryDef", function()
        it("should return true for factories", function()
            assert.is_true(Categories.isFactoryDef({ isFactory = true }))
        end)

        it("should return false for non-factories", function()
            assert.is_false(Categories.isFactoryDef({ isBuilder = true }))
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
