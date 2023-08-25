local function testMergeInPlace(deep)
  Spring.Echo(string.format("[test] [table.mergeInPlace(deep: %s)] start", tostring(deep)))
  local mergeTarget = {
    shouldBeOverriden = "no",
    shouldBeMerged = {
      shouldBeOverriden = "no",
      shouldBeMerged = { "no", "no", "yes", },
      "yes",
    },
    shouldBeKept = "yes",
    [1] = "no",
    [2] = "yes",
  }
  local mergeData = {
    shouldBeOverriden = "yes",
    shouldBeMerged = {
      shouldBeOverriden = "yes",
      shouldBeMerged = { "yes", "yes", },
      shouldBeAdded = { "yes", },
    },
    shouldBeAdded = { "yes", },
    [1] = "yes",
    [3] = "yes"
  }

  table.mergeInPlace(mergeTarget, mergeData, deep)
  Spring.Echo(string.format("[test] [table.mergeInPlace(deep: %s)] %s", tostring(deep), table.toString(mergeTarget)))

  local expectedYesCount = 12
  local yesCount = 0
  local function checkAllYes(tbl)
    for key, value in pairs(tbl) do
      if type(value) == "table" then
        checkAllYes(value)
      else
        assert(value == "yes", string.format("expected all values to be 'yes', but go '%s' for key %s", value, key))
        yesCount = yesCount + 1
      end
    end
  end
  checkAllYes(mergeTarget)
  assert(yesCount == expectedYesCount, string.format("expected %s 'yes' values, got %s", expectedYesCount, yesCount))

  if deep then
    assert(mergeData.shouldBeAdded ~= mergeTarget.shouldBeAdded,
      "expected mergeData.shouldBeAdded and mergeTarget.shouldBeAdded to be different instance, due to deep merge")
    assert(mergeData.shouldBeMerged.shouldBeAdded ~= mergeTarget.shouldBeMerged.shouldBeAdded,
      "expected mergeData.shouldBeMerged.shouldBeAdded and mergeTarget.shouldBeMerged.shouldBeAdded to be different instance, due to deep merge")
  else
    assert(mergeData.shouldBeAdded == mergeTarget.shouldBeAdded,
      "expected mergeData.shouldBeAdded and mergeTarget.shouldBeAdded to be same instance, due to non-deep merge")
    assert(mergeData.shouldBeMerged.shouldBeAdded == mergeTarget.shouldBeMerged.shouldBeAdded,
      "expected mergeData.shouldBeMerged.shouldBeAdded and mergeTarget.shouldBeMerged.shouldBeAdded to be same instance, due to non-deep merge")
  end

  Spring.Echo(string.format("[test] [table.mergeInPlace(deep: %s)] success", tostring(deep)))
end

local function testTableRemoveIf()
  Spring.Echo("[test] [table.removeIf] start")
  local t = { a = 1, b = 2, c = 3, d = 4, e = 5, }
  local tEven = table.copy(t)
  table.removeIf(tEven, function(v) return v % 2 == 1 end)
  local tOdd = table.copy(t)
  table.removeIf(tOdd, function(v) return v % 2 == 0 end)

  Spring.Echo(string.format("[test] [table.removeIf] tEven: %s", table.toString(tEven)))
  Spring.Echo(string.format("[test] [table.removeIf] tOdd: %s", table.toString(tOdd)))

  local assertions = {
    tEven = { table.count(tEven), 2 },
    tOdd = { table.count(tOdd), 3 },
  }

  for tbl, assertion in pairs(assertions) do
    assert(assertion[1] == assertion[2],
      string.format("expected %s to have %s values (actual: %s)", tbl, assertion[1], assertion[2]))
  end
  Spring.Echo("[test] [table.removeIf] success")
end

local function testTableRemoveAll()
  Spring.Echo("[test] [table.removeAll] start")
  local t = { a = 1, b = 2, c = 1, d = 2, e = 1, }
  local tOnes = table.copy(t)
  table.removeAll(tOnes, 2)
  local tTwos = table.copy(t)
  table.removeAll(tTwos, 1)

  Spring.Echo(string.format("[test] [table.removeAll] tOnes: %s", table.toString(tOnes)))
  Spring.Echo(string.format("[test] [table.removeAll] tTwos: %s", table.toString(tTwos)))

  local assertions = {
    tOnes = { table.count(tOnes), 3 },
    tTwos = { table.count(tTwos), 2 },
  }

  for tbl, assertion in pairs(assertions) do
    assert(assertion[1] == assertion[2],
      string.format("expected %s to have %s values (actual: %s)", tbl, assertion[1], assertion[2]))
  end
  Spring.Echo("[test] [table.removeAll] success")
end

local function testTableRemoveFirst()
  Spring.Echo("[test] [table.removeFirst] start")
  local tests = {
    sequence = { "a", "b", "c" }, -- indexes should be kept without any gaps for this one
    notASequence = { "a", "b", [4] = "c" },
    regularTable = { a = "a", b = "b", c = "c" },
  }

  for name, test in pairs(tests) do
    Spring.Echo(string.format("[test] [table.removeFirst] %s: %s", name, table.toString(test)))
    for _, value in pairs({ "b", "c", "a", }) do
      table.removeFirst(test, value)
      Spring.Echo(string.format("[test] [table.removeFirst] %s: %s (removed: %s)", name, table.toString(test), value))
      -- special case for sequence: check that indexes are kept without any gaps
      if name == "sequence" then
        local prev_i = 0
        for i, _ in pairs(test) do
          i = tonumber(i)
          assert(i == prev_i + 1, string.format("expected table %s to have continuous indexes, but it does not", name))
          prev_i = i
        end
      end
    end
    assert(table.count(test) == 0, string.format("expected table %s to be empty, but it's not", name))
  end
  Spring.Echo("[test] [table.removeFirst] success")
end

testMergeInPlace(false)
testMergeInPlace(true)
testTableRemoveIf()
testTableRemoveAll()
testTableRemoveFirst()
