-- Utility
-- A SetList is a data structure used for storing only keys, any key is valid (no values!)
-- It consists of a hash part for fast containment checks
-- And a list part for fast random generation
local function tstr(t,n)
	if t==nil then return end
	local res = tostring(n or "") .. ' {'
	for k,v in pairs(t) do res = res .. tostring(k) .. "=" .. tostring(v) ..", " end 
	print( res .. '}')
end

local mRandom = math.random
local SetListMT = {}
SetListMT.__index = SetListMT
function SetListMT:Add(key)
	if self.hash[key] == nil then -- So that we dont add twice
		self.count = self.count + 1
		self.hash[key] = self.count 
		self.list[self.count] = key
	end
end
function SetListMT:Remove(key)
	local popindex = self.hash[key]
	if popindex then
		if popindex ~= self.count then 
			-- If not last element, then take the element at the very back, and emplace it at popindex
			local popkey = self.list[self.count]
			self.list[popindex] =  popkey -- bring it back in list
			self.hash[popkey] = popindex
		end
		self.list[self.count] = nil
		self.hash[key] = nil 
		self.count = self.count - 1
	end
	
end
function SetListMT:GetRandom()
	if self.count > 0 then return self.list[mRandom(1, self.count)] end
end
local function NewSetList()
	local t = {
		hash = {}, -- Hash table map keys to positions in list 
		list = {}, -- List table maps positions in list to keys
		count = 0, -- Keeps a tally of how many elements
		}
	setmetatable(t, SetListMT)
	return t
end


-- A SetListMin is a data structure used for storing only positive integer keys  or strings (no values!)
-- It consists of only a hash part. Negative numbers are not allowed
local setListMinMT = {}
setListMinMT.__index = setListMinMT
function setListMinMT:Add(key)
	if self.hash[key] == nil then -- So that we dont add twice
		self.count = self.count + 1
		self.hash[key] = self.count
		self.hash[-1 * self.count] = key
	end
end
function setListMinMT:Remove(key)
	local popindex = self.hash[key]
	if popindex then
		if popindex ~= self.count then 
			-- If not last element, then take the element at the very back, and emplace it at popindex
			local popkey = self.hash[-1 * self.count]
			self.hash[-1 * popindex] =  popkey -- bring it back in list
			self.hash[popkey] = popindex
		end
		self.hash[-1* self.count] = nil
		self.hash[key] = nil 
		self.count = self.count - 1
	end
end
function setListMinMT:GetRandom()
	if self.count > 0 then return self.hash[-1 * mRandom(1, self.count)] end
end
local function NewSetListMin()
	local t = {
		hash = {}, -- Hash table map keys to positions in list 
		count = 0, -- Keeps a tally of how many elements
		}
	setmetatable(t, setListMinMT)
	return t
end

	
-- A SetListNoTable is a data structure used for storing only positive integer keys, or string keys which arent called 'count'
-- It consists of only the table itself. Negative numbers are not allowed

local SetListNoTableMT = {}
SetListNoTableMT.__index = SetListNoTableMT -- This is needed so that the index metamethod can find functions in itself
function SetListNoTableMT:Add(key)
	if self[key] == nil then -- So that we dont add twice
		self.count = self.count + 1
		self[key] = self.count
		self[-1 * self.count] = key
	end
end
function SetListNoTableMT:Remove(key)
	local popindex = self[key]
	if popindex then
		if popindex ~= self.count then 
			-- If not last element, then take the element at the very back, and emplace it at popindex
			local popkey = self[-1 * self.count]
			self[-1 * popindex] =  popkey -- bring it back in list
			self[popkey] = popindex
		end
		self[-1 * self.count] = nil
		self[key] = nil 
		self.count = self.count - 1
	end
end
function SetListNoTableMT:GetRandom()
	if self.count > 0 then return self[-1 * mRandom(1, self.count)] end
end
local function NewSetListNoTable()
	local t = {count = 0} -- Keeps a tally of how many elements
	setmetatable(t, SetListNoTableMT)
	return t
end

local SetListUtilities = {
	NewSetListNoTable = NewSetListNoTable,
	NewSetListMin = NewSetListMin, 
	NewSetList = NewSetList
}
return SetListUtilities

--local tester = NewSetListNoTable()
--[[
local totest = {NewSetList = NewSetList(), NewSetListMin = NewSetListMin(), NewSetListNoTable = NewSetListNoTable()}
math.randomseed(os.clock())
for methodname, tester in pairs(totest) do
	print(methodname)
		for j = 1, 10 do 
			tester:Add(string.char(65+j))
		end
		tstr(tester.hash, 'hash')
		tstr(tester.list, 'list')
		
		for j = 1,11 do 
			local r = tester:GetRandom()
			tester:Remove(r)
			print (j,r, tester.count)
		end
		
	end
	
local rezrez = 0
for methodname, tester in pairs(totest) do
	local t0 = os.clock()
	for i = 1, 1000 do 
		for j = 1, 1000 do 
			tester:Add(j)
		end
		if tester.list then
			for k,v in pairs(tester.hash) do 
				rezrez = rezrez + k
			end
		end
		for j = 1, 1000 do
			tester:Remove(tester:GetRandom())
		end
	end
	local deltat = os.clock()-t0
	print ("Time taken to test", methodname, deltat,"s")
end
for methodname, tester in pairs(totest) do
	local t0 = os.clock()
	for i = 1, 1000 do 
		for j = 1, 1000 do 
			tester.Add(tester, j)
		end
		if tester.list then
			for k,v in pairs(tester.hash) do 
				rezrez = rezrez + k
			end
		end
		for j = 1, 1000 do
			--r = mRandom(1,1000)
			tester.Remove(tester, j)
		end
	end
	local deltat = os.clock()-t0
	print ("Time taken to test NOSUGAR", methodname, deltat,"s")
end
local t0 = os.clock()
local tester = {}
local rezres = 0
for i = 1, 1000 do 
	tester = {}
	for j = 1, 1000 do 
		tester[j] = j+ 1
	end
	rezres = tester[100] + rezres		
	for k,v in pairs(tester) do 
		rezrez = rezrez + k
	end
	for j = 1, 1000 do
		tester[mRandom(1,1000)] = nil
	end
end
local deltat = os.clock()-t0
print ("Time taken to test", "good old vanilla", deltat,"s")

	]]--