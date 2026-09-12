-- Shared search and filtering for the panels with a search box: the widget selector, the
-- settings, the game info and the keybind editor.
--
-- There are two kinds of search here, and the difference is deliberate:
--
--   * Ranked. `query` then `score`, and the caller sorts by what comes back. A list of
--     things you are hunting for by name - widgets, settings - where the best answer
--     should rise to the top.
--   * Plain. `query` then `matches`, and the caller keeps its own order. A list you are
--     reading rather than hunting through - the game's settings as they were authored,
--     the keybinds grouped the way they are taught - where reshuffling the rows under the
--     cursor as each letter is typed loses the reader their place.
--
-- Both are here so a panel can pick the one it wants, not so the four panels can be made
-- to search alike.
--
-- Haystacks are handed in already lowercased. Every panel here builds its rows once and
-- searches them on each keystroke, so lowercasing belongs with the row, not with the
-- search; `normalize` is for the panels whose text only exists in a coloured form.

local M = {}

local stringByte = string.byte
local stringFind = string.find
local stringLower = string.lower
local stringGsub = string.gsub
local mathMax = math.max
local mathMin = math.min

local EMPTY = {}

----------------------------------------------------------------
-- The query
----------------------------------------------------------------

-- What was typed, worked out once per keystroke rather than once per item. The words and
-- the spaceless form are only built when something is actually being searched for.
--
-- Fields: `text` lowercased, `words` the whitespace-separated parts, `joined` those parts
-- run together (what the fuzzy pass matches against), `empty` when nothing was typed.
---@param text string?
---@return table query
function M.query(text)
	if not text or text == "" then
		return { text = "", words = EMPTY, joined = "", empty = true }
	end

	local lower = stringLower(text)
	local words = {}
	for word in lower:gmatch("%S+") do
		words[#words + 1] = word
	end

	if #words == 0 then
		return { text = "", words = EMPTY, joined = "", empty = true }
	end

	return { text = lower, words = words, joined = (stringGsub(lower, "%s+", "")), empty = false }
end

-- Strips the inline colour codes from a label so it can be searched or lowercased. Text
-- that is stored coloured only: prefer keeping an uncoloured copy on the row where you
-- can, since this runs over every item on every keystroke otherwise.
---@param text string?
---@return string
function M.normalize(text)
	if not text or text == "" then
		return ""
	end
	-- \255 takes three bytes of colour after it; \008 is the reset.
	text = stringGsub(text, "\255...", "")
	text = stringGsub(text, "\008", "")
	text = stringGsub(text, "%s%s+", " ")

	return stringLower(text:match("^%s*(.-)%s*$") or text)
end

----------------------------------------------------------------
-- Plain, order-preserving
----------------------------------------------------------------

-- Does this row survive the filter? An empty query keeps everything, which is what makes
-- this the whole test at a call site rather than half of one.
---@param query table From `M.query`
---@param haystack string? Already lowercased
---@return boolean
function M.matches(query, haystack)
	if query.empty then
		return true
	end

	return haystack ~= nil and stringFind(haystack, query.text, 1, true) ~= nil
end

-- Did this heading itself match? A category, group or block whose own title matches keeps
-- everything under it, so searching for a section's name shows the section rather than
-- emptying it. Unlike `matches` an empty query is not a match: nothing is being searched
-- for, so nothing is being claimed.
---@param query table From `M.query`
---@param haystack string? Already lowercased
---@return boolean
function M.claims(query, haystack)
	if query.empty then
		return false
	end

	return haystack ~= nil and stringFind(haystack, query.text, 1, true) ~= nil
end

----------------------------------------------------------------
-- Ranked
----------------------------------------------------------------

-- How well `query` reads as a subsequence of `target`: every query character has to appear
-- in order, and the score says how tightly. Runs together, at word starts and near the
-- front all count for more; gaps count against. `0` means it does not match at all.
--
-- Both `query` and `target` are lowercased, and `query` is the spaceless form.
---@param query string
---@param target string
---@return number
function M.fuzzy(query, target)
	local qi = 1
	local qlen = #query
	local tlen = #target
	if qlen == 0 then
		return 0
	end
	if qlen > tlen then
		return 0
	end

	---@type number
	local score = 0
	local consecutive = 0
	local prevMatched = false
	---@type number?
	local firstMatchPos = nil
	local lastMatchPos = 0

	for ti = 1, tlen do
		if qi > qlen then
			break
		end
		local tc = stringByte(target, ti)
		local qc = stringByte(query, qi)
		if tc == qc then
			if not firstMatchPos then
				firstMatchPos = ti
			end
			qi = qi + 1
			-- Gap penalty: penalize distance from previous match
			if lastMatchPos > 0 then
				local gap = ti - lastMatchPos - 1
				if gap > 0 then
					score = score - gap * 0.5
				end
			end
			lastMatchPos = ti
			-- Consecutive character bonus
			if prevMatched then
				consecutive = consecutive + 1
				score = score + 3 + consecutive
			else
				consecutive = 0
				score = score + 1
			end
			-- Word boundary bonus: char after space, underscore, or start of string
			if ti == 1 then
				score = score + 5
			else
				local prev = stringByte(target, ti - 1)
				if prev == 32 or prev == 95 or prev == 45 then -- space, underscore, dash
					score = score + 4
				end
			end
			prevMatched = true
		else
			prevMatched = false
			consecutive = 0
		end
	end

	if qi <= qlen then
		return 0 -- not all query chars matched
	end

	-- Bonus for matching near the start
	if firstMatchPos then
		score = score + mathMax(0, 6 - firstMatchPos)
	end

	-- Normalize: prefer shorter targets (tighter matches)
	score = score + mathMax(0, 3 - (tlen - qlen) * 0.1)

	return score
end

-- How well one item answers the query, as three tiers that never overlap, so a whole-word
-- hit always outranks a scattered one however pretty the latter scores:
--
--   300+     the query appears whole in a `primary` field
--   100-299  every word appears somewhere; 200 when they are all in the first field
--   1-99     the query reads as a subsequence of a `primary` field
--
-- `primary` is what the item is called - its name, and whatever else names it, such as an
-- id. The first entry is the one the multi-word tier counts as a name hit. `secondary` is
-- everything else worth finding it by, a description or an author: enough to satisfy the
-- multi-word tier, never enough to match on its own.
--
-- Both are arrays of lowercased strings, read and not kept, so a caller can fill one pair
-- of tables outside its loop and rewrite them per item rather than allocating.
--
-- Returns `0` when the item does not match at all.
---@param query table From `M.query`
---@param primary string[]
---@param secondary string[]?
---@return number
function M.score(query, primary, secondary)
	if query.empty then
		return 0
	end

	local text = query.text

	-- Tier 1: the query, whole, in one of the fields the item is named by. Earlier in a
	-- shorter field is a better answer than later in a longer one.
	for i = 1, #primary do
		local field = primary[i]
		local at = field ~= "" and stringFind(field, text, 1, true)
		if at then
			return 300 + mathMax(0, 50 - at) + mathMax(0, 20 - #field)
		end
	end

	local words = query.words

	-- Tier 2: every word found somewhere. All of them in the name beats some of them
	-- landing in a description.
	if #words > 1 then
		local first = primary[1] or ""
		local nameMatches = 0
		---@type number
		local posSum = 0
		local all = true
		for i = 1, #words do
			local word = words[i]
			local inName = first ~= "" and stringFind(first, word, 1, true)
			local found = inName
			if not found and secondary then
				for j = 1, #secondary do
					local field = secondary[j]
					if field ~= "" and stringFind(field, word, 1, true) then
						found = true
						break
					end
				end
			end
			if not found then
				all = false
				break
			end
			if inName then
				nameMatches = nameMatches + 1
				posSum = posSum + inName
			end
		end
		if all then
			local base = (nameMatches == #words) and 200 or 100

			return base + mathMax(0, 50 - posSum / #words)
		end
	end

	-- Tier 3: a subsequence, which is loose enough that it needs a few characters to go on
	-- and a floor under how well it has to read before it counts at all.
	local joined = query.joined
	if #joined >= 3 then
		---@type number
		local best = 0
		for i = 1, #primary do
			local field = primary[i]
			if field ~= "" then
				local s = M.fuzzy(joined, field)
				if s > best then
					best = s
				end
			end
		end
		if best >= #joined * 2 then
			return mathMin(99, best)
		end
	end

	return 0
end

return M
