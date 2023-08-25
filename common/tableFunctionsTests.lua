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

testMergeInPlace(false)
testMergeInPlace(true)
