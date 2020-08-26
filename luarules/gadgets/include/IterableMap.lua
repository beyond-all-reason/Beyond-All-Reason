local IterableMap = {}

function IterableMap.New()
	local mapData = {
		indexByKey = {},
		dataByKey = {},
		indexMax = 0,
		unusedKey = 1,
		keyByIndex = {},
		nextCounter = 0,
	}
	return mapData
end

function IterableMap.GetUnusedKey(self)
	while IterableMap.InMap(self, self.unusedKey) do
		self.unusedKey = self.unusedKey + 1
	end
	return self.unusedKey
end

function IterableMap.Add(self, key, data)
	if not key then
		return
	end
	if self.indexByKey[key] then
		-- Overwrites
		self.dataByKey[key] = data
		return
	end
	data = data or true
	self.indexMax = self.indexMax + 1
	self.keyByIndex[self.indexMax] = key
	self.dataByKey[key] = data
	self.indexByKey[key] = self.indexMax
end

function IterableMap.AddSelf(self, data)
	key = IterableMap.GetUnusedKey(self)
	data.index = key
	IterableMap.Add(self, key, data)
end

function IterableMap.Remove(self, key)
	if (not key) or (not self.indexByKey[key]) then
		return false
	end
	local myIndex = self.indexByKey[key]
	local endKey = self.keyByIndex[self.indexMax]
	self.keyByIndex[myIndex] = endKey
	self.indexByKey[endKey] = myIndex
	self.keyByIndex[self.indexMax] = nil
	self.indexByKey[key] = nil
	self.dataByKey[key] = nil
	self.indexMax = self.indexMax - 1
	return true
end

function IterableMap.ReplaceKey(self, oldKey, newKey)
	if (not oldKey) or (not self.indexByKey[oldKey]) or self.indexByKey[newKey] then
		return false
	end
	self.keyByIndex[self.indexByKey[oldKey]] = newKey
	self.indexByKey[newKey] = self.indexByKey[oldKey]
	self.dataByKey[newKey] = self.dataByKey[oldKey]
	self.indexByKey[oldKey] = nil
	self.dataByKey[oldKey] = nil
	return true
end

-- Get is also set in the case of tables because tables pass by reference
function IterableMap.Get(self, key)
	return self.dataByKey[key]
end
function IterableMap.Set(self, key, data)
	if not self.indexByKey[key] then
		IterableMap.Add(self, key, data)
	else
		self.dataByKey[key] = data
	end
end

function IterableMap.InMap(self, key)
	return (self.indexByKey[key] and true) or false
end

function IterableMap.Clear(self, key)
	self.indexByKey = {}
	self.dataByKey = {}
	self.indexMax = 0
	self.unusedKey = 1
	self.keyByIndex = {}
end

-- Use Next to implement iteration spread over many updates. Returns the next
-- element using some internal counter.
function IterableMap.Next(self)
	if self.indexMax < 1 then
		return false
	end
	self.nextCounter = self.nextCounter + 1
	if self.nextCounter > self.indexMax then
		self.nextCounter = 1
	end
	return self.keyByIndex[self.nextCounter], self.dataByKey[self.keyByIndex[self.nextCounter]]
end

-- To use Iterator, write "for unitID, data in interableMap.Iterator() do"
-- This approach makes the garbage collector cry so try to use other methods
-- of iteration.
function IterableMap.Iterator(self)
	local i = 0
	return function ()
		i = i + 1
		if i <= self.indexMax then
			return self.keyByIndex[i], self.dataByKey[self.keyByIndex[i]]
		end
	end
end

-- Does the function to every element of the map. A less barbaric method
-- of iteration. Recommended for cleanliness and speed.
-- Using the third argument, index, is a little evil because index should
-- be private.
function IterableMap.Apply(self, funcToApply, ...)
	local i = 1
	while i <= self.indexMax do
		local key = self.keyByIndex[i]
		if funcToApply(key, self.dataByKey[key], i, ...) then
			-- Return true to remove element
			IterableMap.Remove(self, key)
		else
			i = i + 1
		end
	end
end

function IterableMap.ApplySelf(self, funcName, ...)
	local i = 1
	while i <= self.indexMax do
		local key = self.keyByIndex[i]
		if self.dataByKey[key][funcName](...) then
			-- Return true to remove element
			IterableMap.Remove(self, key)
		else
			i = i + 1
		end
	end
end

function IterableMap.ApplyNoArg(self, funcToApply)
	local i = 1
	while i <= self.indexMax do
		local key = self.keyByIndex[i]
		if funcToApply(key, self.dataByKey[key], i) then
			-- Return true to remove element
			IterableMap.Remove(self, key)
		else
			i = i + 1
		end
	end
end

-- This 'method' of iteration is for barbarians. Seems to have performance
-- similar to Apply.
function IterableMap.GetIndexMax(self)
	return self.indexMax
end

function IterableMap.IsEmpty(self)
	return (self.indexMax == 0)
end

function IterableMap.GetKeyByIndex(self, index)
	return self.keyByIndex[index]
end

function IterableMap.GetBarbarianData(self)
	return self.indexMax, self.keyByIndex, self.dataByKey
end

function IterableMap.GetDataByIndex(self, index)
	if self.keyByIndex[index] then
		return self.dataByKey[self.keyByIndex[index]]
	end
	return false
end

return IterableMap
