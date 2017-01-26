-- $Id: tablebin.lua 3171 2008-11-06 09:06:29Z det $
--[[
	Binary Search a Table
	Binary Insert into Table (faster than table.insert and table.sort combined)
	v 0.3

	Lua 5.1 compatible
]]--
--[[
	table.binsearch( table, value [, compval [, reversed] ] )
	
	Searches the table through BinarySearch for the given value.
	If the  value is found:
		it returns a table holding all the mathing indices (e.g. { startindice,endindice } )
		endindice may be the same as startindice if only one matching indice was found
	If compval is given:
		then it must be a function that takes one value and returns a second value2,
		to be compared with the input value, e.g.:
		compvalue = function( value ) return value[1] end
	If reversed is set to true:
		then the search assumes that the table is sorted in reverse order (largest value at position 1)
		note when reversed is given compval must be given as well, it can be nil/_ in this case
	Return value:
		on success: a table holding matching indices (e.g. { startindice,endindice } )
		on failure: nil
]]--
do
	-- Avoid heap allocs for performance
	local default_fcompval = function( value ) return value end
	local fcompf = function( a,b ) return a < b end
	local fcompr = function( a,b ) return a > b end
	function table.binsearch( t,value,fcompval,reversed )
		-- Initialise functions
		local fcompval = fcompval or default_fcompval
		local fcomp = reversed and fcompr or fcompf
		--  Initialise numbers
		local iStart,iEnd,iMid = 1,#t,0
		-- Binary Search
		while iStart <= iEnd do
			-- calculate middle
			iMid = math.floor( (iStart+iEnd)/2 )
			-- get compare value
			local value2 = fcompval( t[iMid] )
			-- get all values that match
			if value == value2 then
				local tfound,num = { iMid,iMid },iMid - 1
				while value == fcompval( t[num] ) do
					tfound[1],num = num,num - 1
				end
				num = iMid + 1
				while value == fcompval( t[num] ) do
					tfound[2],num = num,num + 1
				end
				return tfound
			-- keep searching
			elseif fcomp( value,value2 ) then
				iEnd = iMid - 1
			else
				iStart = iMid + 1
			end
		end
	end
end
--[[
	table.bininsert( table, value [, comp] )
	
	Inserts a given value through BinaryInsert into the table sorted by [, comp].
	
	If 'comp' is given, then it must be a function that receives
	two table elements, and returns true when the first is less
	than the second, e.g. comp = function(a, b) return a > b end,
	will give a sorted table, with the biggest value on position 1.
	[, comp] behaves as in table.sort(table, value [, comp])
	returns the index where 'value' was inserted
]]--
do
	-- Avoid heap allocs for performance
	local fcomp_default = function( a,b ) return a < b end
	function table.bininsert(t, value, fcomp)
		-- Initialise compare function
		local fcomp = fcomp or fcomp_default
		--  Initialise numbers
		local iStart,iEnd,iMid,iState = 1,#t,1,0
		-- Get insert position
		while iStart <= iEnd do
			-- calculate middle
			iMid = math.floor( (iStart+iEnd)/2 )
			-- compare
			if fcomp( value,t[iMid] ) then
				iEnd,iState = iMid - 1,0
			else
				iStart,iState = iMid + 1,1
			end
		end
		table.insert( t,(iMid+iState),value )
		return (iMid+iState)
	end
end
-- CHILLCODE™