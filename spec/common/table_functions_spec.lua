describe("common.tablefunctions", function()
	describe("sortStable", function()
		local function byKey(a, b)
			if a.key ~= b.key then
				return a.key < b.key
			end
		end

		local function elementsWithKeys(...)
			local elements = {}
			for position, key in ipairs({ ... }) do
				elements[position] = { key = key, initialPosition = position }
			end
			return elements
		end

		local function toKeysAndInitialPositions(elements)
			local rendered = {}
			for index, element in ipairs(elements) do
				rendered[index] = element.key .. ":" .. element.initialPosition
			end
			return rendered
		end

		it("sorts by the given comparison", function()
			local elements = elementsWithKeys("c", "a", "b")

			table.sortStable(elements, byKey)

			assert.are.same({ "a:2", "b:3", "c:1" }, toKeysAndInitialPositions(elements))
		end)

		it("sorts without a comparison", function()
			local list = { 3, 1, 2 }

			table.sortStable(list)

			assert.are.same({ 1, 2, 3 }, list)
		end)

		it("sorts an empty list", function()
			local elements = {}

			table.sortStable(elements, byKey)

			assert.are.same({}, elements)
		end)

		it("keeps equal elements in the order they were in", function()
			local elements = elementsWithKeys("b", "a", "b", "a", "b", "a")

			table.sortStable(elements, byKey)

			assert.are.same({ "a:2", "a:4", "a:6", "b:1", "b:3", "b:5" }, toKeysAndInitialPositions(elements))
		end)

		it("keeps equal elements in the order they were in, in a long list", function()
			local keys = {}
			for position = 1, 60 do
				keys[position] = tostring(position % 3)
			end
			local elements = elementsWithKeys(unpack(keys))

			table.sortStable(elements, byKey)

			local expected = {}
			for _, sortedKey in ipairs({ "0", "1", "2" }) do
				for position, key in ipairs(keys) do
					if key == sortedKey then
						expected[#expected + 1] = key .. ":" .. position
					end
				end
			end
			assert.are.same(expected, toKeysAndInitialPositions(elements))
		end)
	end)
end)
