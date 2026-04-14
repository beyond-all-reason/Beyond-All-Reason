---@meta

--- BAR integration-test DSL injected into each test file's setfenv by the
--- `dbg_test_runner` widget. Methods here match the inline `Test` table in
--- `luaui/Widgets/dbg_test_runner.lua:662` plus the extras merged from
--- `common/testing/test_extra_utils.lua:76`.
---
--- Available only inside the `skip`/`setup`/`test`/`cleanup` hooks that
--- each test file returns. Not a runtime global outside that context; the
--- `---@meta` marker keeps this file analysis-only.
---@class Test
Test = {}

--- Yield the test coroutine until `predicate` returns truthy, or `timeout`
--- frames elapse.
---@param predicate fun():boolean?
---@param timeout? integer frames; default `config.waitTimeout`
---@param errorOffset? integer stack depth offset added to any raised error
function Test.waitUntil(predicate, timeout, errorOffset) end

--- Yield the test coroutine for `frames` simulation frames.
---@param frames integer
function Test.waitFrames(frames) end

--- Yield the test coroutine until `milliseconds` of wall-clock time elapse
--- (or `timeout` frames, whichever comes first).
---@param milliseconds integer
---@param timeout? integer frames; defaults to `milliseconds * 30 / 1000 + 5`
function Test.waitTime(milliseconds, timeout) end

--- Register interest in a widget/gadget callin so subsequent invocations
--- are buffered for inspection via `waitUntilCallin`/`waitUntilCallinArgs`.
---@param name string Spring callin name (e.g. "UnitCommand", "UnitCreated")
---@param countOnly? boolean if true, only counts are tracked (no arg buffer)
---@param depth? integer stack depth offset for error reporting
function Test.expectCallin(name, countOnly, depth) end

--- Undo a prior `expectCallin` — stop buffering for `name`.
---@param name string
function Test.unexpectCallin(name) end

--- Yield until the `name` callin has fired at least `count` times with args
--- that satisfy `predicate`. Requires a prior `expectCallin`.
---@param name string
---@param predicate? fun(...):boolean
---@param timeout? integer frames
---@param count? integer default 1
---@param depth? integer
function Test.waitUntilCallin(name, predicate, timeout, count, depth) end

--- Like `waitUntilCallin` but matches positional args against `expectedArgs`
--- (`nil` entries are wildcards).
---@param name string
---@param expectedArgs table positional args with `nil` wildcards
---@param timeout? integer frames
---@param count? integer default 1
---@param depth? integer
function Test.waitUntilCallinArgs(name, expectedArgs, timeout, count, depth) end

--- Wraps a method in a recorder that lets you inspect `.calls` after.
--- Forwards to the real method unless overridden via `mock`.
---@param target table
---@param methodName string
---@param impl? function optional replacement implementation
---@return { calls: any[], remove: fun() } spyControl
function Test.spy(target, methodName, impl) end

--- Wraps a method with a fake implementation. Original is restored by
--- `.remove()` or automatically on test teardown.
---@param target table
---@param methodName string
---@param impl? function
---@return { calls: any[], remove: fun() } mockControl
function Test.mock(target, methodName, impl) end

--- Destroy every unit and feature on the map. Used in setup/cleanup to
--- return the map to a known-empty state between tests.
function Test.clearMap() end

--- Toggle whether callin buffering records ALL invocations or just the safe
--- subset (avoids yielding across C-call boundaries during hot callins).
---@param unsafe boolean
function Test.setUnsafeCallins(unsafe) end

--- Remove every registered callin recorder.
function Test.clearCallins() end

--- Reset the recorded buffer + count for one callin (or all, if `name` nil).
---@param name? string
function Test.clearCallinBuffer(name) end

--- Ensure `widgetName` is enabled with locals-access, track its prior
--- enabled state for automatic restore, and return the live widget table.
---@param widgetName string
---@return table widget the live widget table
function Test.prepareWidget(widgetName) end

--- Restore one widget's enabled state to what it was before `prepareWidget`.
--- Can be called manually; otherwise the runner calls it automatically.
---@param widgetName string
function Test.restoreWidget(widgetName) end

--- Restore every widget enabled through `prepareWidget` to its pre-test
--- state. Invoked automatically by the runner at the end of each test.
function Test.restoreWidgets() end

--- Flatten the map's heightmap to a fixed level. Used by tests that need
--- reproducible unit positioning regardless of map terrain.
--- (From `common/testing/test_extra_utils.lua`.)
function Test.levelHeightMap() end

--- Restore the heightmap saved by a prior `levelHeightMap`.
--- (From `common/testing/test_extra_utils.lua`.)
function Test.restoreHeightMap() end

--- Bare-global assertion + util entries injected into the test file's setfenv
--- alongside `Test`. Sources:
---   `common/testing/assertions.lua` (exports assertThrows etc.)
---   `common/testing/util.lua`       (pack)
--- These aren't on the `Test` namespace because the runner merges them flat
--- into the chunk's environment; declaring them here as `@meta` keeps
--- emmylua happy inside the test files without leaking a visible global
--- outside the test context (the @meta marker scopes them to analysis-only).

--- Recursively compare two tables for structural equality. Numbers are
--- compared with optional `margin` tolerance. Fails via `assert()` at the
--- first mismatch with a path-qualified message.
---@param expected any
---@param actual any
---@param margin? number numeric equality tolerance (default 0)
function assertTablesEqual(expected, actual, margin) end

--- Call `fn` repeatedly every `frames` simulation frames until it returns
--- truthy, or fail after `seconds` elapse. Errors with `errorMsg` (or a
--- default) if the deadline passes with no success.
---@param seconds number
---@param frames integer
---@param fn fun():boolean?
---@param errorMsg? string
---@param depthOffset? integer stack depth offset for the error
function assertSuccessBefore(seconds, frames, fn, errorMsg, depthOffset) end

--- Assert `fn` throws. `errorMsg` override is used when it unexpectedly
--- doesn't throw. Prefer `assertThrowsMessage` when possible — this
--- catches any throw, including unrelated ones.
---@param fn fun()
---@param errorMsg? string
---@param depthOffset? integer
function assertThrows(fn, errorMsg, depthOffset) end

--- Assert `fn` throws an error whose message matches `testMsg` exactly
--- (after stripping the Lua file:line prefix). `errorMsg` is used for
--- the thrown error when the test itself fails.
---@param fn fun()
---@param testMsg string
---@param errorMsg? string
---@param depthOffset? integer
function assertThrowsMessage(fn, testMsg, errorMsg, depthOffset) end

--- Lua-5.1 compatible `table.pack` reimplementation exposed to tests as a
--- bare global. Returns a table with args by index + an `n` field holding
--- the count (including embedded nils).
---@param ... any
---@return table
function pack(...) end

return Test
