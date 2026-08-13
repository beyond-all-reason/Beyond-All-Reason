require("spec_helper")

local BROKEN_INCLUDE = 'spec/spec_helper_spec/broken_include.lua'

describe("spec_helper", function()

    describe("VFS.Include", function()
        it("raises when an included file exists but fails while running", function()
            local ok, err = pcall(VFS.Include, BROKEN_INCLUDE)

            assert.is_false(ok)
            err = tostring(err)
            assert.is_truthy(err:find('VFS.Include failed to run', 1, true), err)
            assert.is_truthy(err:find(BROKEN_INCLUDE, 1, true), err)
            -- the underlying cause is preserved, not just the wrapper
            assert.is_truthy(err:find('intentional failure', 1, true), err)
        end)

        it("returns an empty table for a genuinely missing file", function()
            -- Deliberate: unitdefs and friends load with optional deps missing.
            local result = VFS.Include('luarules/no_such_file_used_by_specs.lua')

            assert.are.same({}, result)
        end)

        it("still loads and caches a valid file", function()
            local first  = VFS.Include('luarules/mission_api/parameter_types.lua')
            local second = VFS.Include('luarules/mission_api/parameter_types.lua')

            assert.is_table(first)
            assert.is_table(first.Types)
            assert.are.equal(first, second)
        end)
    end)

    -- Note: the per-file GG reset cannot be asserted from inside a single file
    -- (the reset fires before this file's top-level code runs, so there is
    -- nothing left to observe). It is covered by running two spec files where
    -- the first writes GG at load time and the second asserts it is absent.

end)
