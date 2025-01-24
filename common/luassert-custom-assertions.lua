local say = require("say")

say:set_namespace("en")

local function table_has_fields(state, arguments)
    local expected = arguments[1]
    local actual = arguments[2]

    for _,key in ipairs(expected) do
        if not actual[key] then
            return false
        end
    end

    return true
end

say:set("assertion.table_has_fields.positive", "Expected fields %s in:\n%s")
say:set("assertion.table_has_fields.negative", "Expected fields %s not in:\n%s")
assert:register("assertion", "table_has_fields", table_has_fields, "assertion.table_has_fields.positive", "assertion.table_has_fields.negative")

local function has_property(state, arguments)
    local property = arguments[1]
    local table = arguments[2]
    for key, value in pairs(table) do
        if key == property then
            return true
        end
    end
    return false
end

say:set("assertion.has_property.positive", "Expected property %s in:\n%s")
say:set("assertion.has_property.negative", "Expected property %s to not be in:\n%s")
assert:register("assertion", "has_property", has_property, "assertion.has_property.positive", "assertion.has_property.negative")

