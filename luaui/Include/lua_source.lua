-- Pretty-prints a Lua snippet for display.
--
-- Tweakdefs reach the game base64-encoded and minified: one enormous line, statements run
-- together with semicolons and every space squeezed out. Listing that raw shows the first
-- eighty characters of it and nothing else, so it is tokenized here and laid out again -
-- one statement per line, indented by block depth, with the spacing Lua is normally
-- written with.
--
-- A formatter, not a parser: it never has to decide whether the source is valid, only
-- where a reader would have put the line breaks. Anything it cannot make sense of is
-- passed through as tokens rather than dropped.

local M = {}

local KEYWORDS = {}
for word in
	string.gmatch(
		"and break do else elseif end false for function if in local nil not or repeat return then true until while",
		"%S+"
	)
do
	KEYWORDS[word] = true
end

-- Opens a block: what follows it is indented, on its own line.
local OPENERS = { ["do"] = true, ["then"] = true, ["repeat"] = true }
-- Closes one: it goes back out a level and starts a line of its own.
local CLOSERS = { ["end"] = true, ["until"] = true, ["else"] = true, ["elseif"] = true }

-- Both sides get a space. `=` is in here too: it is not an operator in Lua, but it reads
-- like one and every style writes it spaced.
local BINARY = {}
for op in string.gmatch("+ - * / % ^ .. == ~= < > <= >= =", "%S+") do
	BINARY[op] = true
end

-- After one of these a `-` is a sign rather than a subtraction, so it sticks to what
-- follows it.
local PREFIX = { ["("] = true, ["["] = true, ["{"] = true, [","] = true, [";"] = true }

local CLOSING = { [")"] = true, ["]"] = true, ["}"] = true }

-- Punctuation rather than arithmetic. It is the most common token in any source, so it is
-- reported apart from the operators: tinting all of it the same is what turns highlighting
-- into noise.
local PUNCT = {}
for _, mark in ipairs({ ",", ";", ".", ":", "(", ")", "[", "]", "{", "}" }) do
	PUNCT[mark] = true
end

-- Keywords that can only begin a statement. Minified source runs statements together with
-- nothing between them, and one of these arriving after a finished expression is the only
-- sign of where the next one starts.
local STARTERS = {}
for word in string.gmatch("local if for while repeat return function break", "%S+") do
	STARTERS[word] = true
end

----------------------------------------------------------------
-- Tokens
----------------------------------------------------------------

-- The end of a long bracket opened at `from`, or the end of the source when it is never
-- closed. Shared by long strings and long comments, which differ only in what precedes.
local function longBracketEnd(src, from, eq)
	local close = "]" .. eq .. "]"
	local at = string.find(src, close, from, true)

	return at and (at + #close - 1) or #src
end

local function readString(src, i)
	local quote = string.sub(src, i, i)
	local j = i + 1
	local n = #src
	while j <= n do
		local c = string.sub(src, j, j)
		if c == "\\" then
			j = j + 2
		elseif c == quote then
			return j
		elseif c == "\n" then
			-- Unterminated: stop at the line rather than swallowing the rest of the file.
			return j - 1
		else
			j = j + 1
		end
	end

	return n
end

local function readNumber(src, i)
	return string.match(src, "^0[xX]%x+", i)
		or string.match(src, "^%d+%.?%d*[eE][-+]?%d+", i)
		or string.match(src, "^%.%d+[eE][-+]?%d+", i)
		or string.match(src, "^%d+%.?%d*", i)
		or string.match(src, "^%.%d+", i)
		or string.sub(src, i, i)
end

-- The source as a flat list of { k = kind, s = text }; whitespace is dropped, since the
-- layout below decides all of it again.
local function tokenize(src)
	local toks = {}
	local i, n = 1, #src
	while i <= n do
		local c = string.sub(src, i, i)
		if string.find(c, "%s") then
			i = i + 1
		elseif string.sub(src, i, i + 1) == "--" then
			local eq = string.match(src, "^%-%-%[(=*)%[", i)
			local stop
			if eq then
				stop = longBracketEnd(src, i + 4 + #eq, eq)
			else
				stop = (string.find(src, "\n", i, true) or (n + 1)) - 1
			end
			toks[#toks + 1] = { k = "comment", s = string.sub(src, i, stop) }
			i = stop + 1
		elseif string.match(src, "^%[=*%[", i) then
			local eq = string.match(src, "^%[(=*)%[", i)
			local stop = longBracketEnd(src, i + 2 + #eq, eq)
			toks[#toks + 1] = { k = "string", s = string.sub(src, i, stop) }
			i = stop + 1
		elseif c == '"' or c == "'" then
			local stop = readString(src, i)
			toks[#toks + 1] = { k = "string", s = string.sub(src, i, stop) }
			i = stop + 1
		elseif string.find(c, "%d") or (c == "." and string.find(string.sub(src, i + 1, i + 1), "%d")) then
			local s = readNumber(src, i)
			toks[#toks + 1] = { k = "number", s = s }
			i = i + #s
		elseif string.find(c, "[%a_]") then
			local s = string.match(src, "^[%a_][%w_]*", i)
			toks[#toks + 1] = { k = KEYWORDS[s] and "keyword" or "name", s = s }
			i = i + #s
		else
			local s = string.match(src, "^%.%.%.", i)
				or string.match(src, "^[=~<>]=", i)
				or string.match(src, "^%.%.", i)
				or c
			toks[#toks + 1] = { k = "op", s = s }
			i = i + #s
		end
	end

	return toks
end

----------------------------------------------------------------
-- Spacing
----------------------------------------------------------------

local function isWord(t)
	return t.k == "name" or t.k == "number" or t.k == "keyword" or t.k == "string"
end

-- Whether a token can be the last one of a statement. What follows such a token is either
-- more of the same expression or, if it is a STARTER, the next statement.
local function endsStatement(t)
	if not t then
		return false
	end

	return t.k == "name" or t.k == "number" or t.k == "string" or CLOSING[t.s] or t.s == "..."
end

-- Whether a space belongs between two tokens. Only readability is at stake except for one
-- case that is not optional: two words run together become a different word.
local function spaced(a, b, prevOfA)
	if not a then
		return false
	end

	local as, bs = a.s, b.s

	-- Nothing is ever pushed away from what it closes or qualifies.
	if bs == "," or bs == ";" or bs == ")" or bs == "]" or bs == "." or bs == ":" then
		return false
	end
	if as == "." or as == ":" or as == "(" or as == "[" or as == "#" then
		return false
	end
	-- A separator's whole job is to hold things apart.
	if as == "," then
		return true
	end
	-- A call or an index hangs off the thing it applies to, and a function hugs its own
	-- parameter list; everywhere else the bracket is a grouping and wants air.
	if bs == "(" or bs == "[" then
		return not (as == "function" or a.k == "name" or CLOSING[as])
	end
	-- An empty table stays empty; anything else gets room inside its braces.
	if bs == "}" then
		return as ~= "{"
	end
	if as == "{" then
		return true
	end
	-- Sign, not arithmetic.
	if
		(as == "-" or as == "+")
		and (prevOfA == nil or PREFIX[prevOfA.s] or BINARY[prevOfA.s] or prevOfA.k == "keyword")
	then
		return false
	end
	if BINARY[as] or BINARY[bs] then
		return true
	end
	if a.k == "keyword" or b.k == "keyword" then
		return true
	end
	if isWord(a) and isWord(b) then
		return true
	end
	if CLOSING[as] and (isWord(b) or bs == "{" or bs == "#") then
		return true
	end

	return false
end

----------------------------------------------------------------
-- Layout
----------------------------------------------------------------

-- A comment is handed over as its own words, so a long one wraps like prose instead of
-- being cut off at the column.
local function commentParts(str)
	local parts = {}
	for word in string.gmatch(str, "%S+") do
		parts[#parts + 1] = { s = (#parts > 0 and " " or "") .. word, k = "comment" }
	end

	return parts
end

-- A name with a call directly after it reads as the thing being done rather than a value,
-- and colouring it apart is most of what makes a wall of source scannable. Lua's two
-- sugared call forms - `f"str"` and `f{...}` - count as well.
local function markCalls(toks)
	for i = 1, #toks - 1 do
		local t, next = toks[i], toks[i + 1]
		if t.k == "name" and (next.s == "(" or next.s == "{" or next.k == "string") then
			t.call = true
		end
	end
end

---Lays a Lua snippet out as display lines.
---
---A part is one token with whatever space belongs in front of it, and the kind it was
---lexed as, so the caller can both break lines between parts and colour them. Kinds are
---`comment`, `string`, `number`, `keyword`, `call`, `name`, `op` and `punct`.
---@param src string
---@return table lines Each `{ depth = <indent levels>, parts = { { s = <text>, k = <kind> } } }`
function M.format(src)
	local toks = tokenize(src)
	markCalls(toks)
	local lines = {}
	local parts = {}
	local depth, lineDepth = 0, 0
	local prev, prevPrev
	-- ( and [ nesting, and the nesting each open function's parameter list closes at, so
	-- the body starts on a line of its own without a parser to say where it begins.
	local paren = 0
	local fnParen = {}
	local fnPending = false

	local function flush()
		if #parts > 0 then
			lines[#lines + 1] = { depth = lineDepth, parts = parts }
			parts = {}
		end
		lineDepth = depth
		prev, prevPrev = nil, nil
	end

	local function push(t)
		local kind = t.k
		if t.call then
			kind = "call"
		elseif kind == "op" and PUNCT[t.s] then
			kind = "punct"
		end
		parts[#parts + 1] = { s = (spaced(prev, t, prevPrev) and " " or "") .. t.s, k = kind }
		prevPrev, prev = prev, t
	end

	for i = 1, #toks do
		local t = toks[i]
		local s = t.s

		-- Nothing separates two statements written side by side, so a keyword that can only
		-- open one, arriving where the line so far already reads as finished, is the break.
		-- Only outside brackets: the same words appear inside expressions.
		if STARTERS[s] and paren == 0 and endsStatement(prev) then
			flush()
		end

		if t.k == "comment" then
			flush()
			-- A long comment carries its own line breaks; each becomes a line here.
			for line in string.gmatch(s .. "\n", "([^\n]*)\n") do
				if string.find(line, "%S") then
					lines[#lines + 1] = { depth = depth, parts = commentParts(line) }
				end
			end
			lineDepth = depth
		elseif s == ";" then
			-- The separator itself is what the line break now says, so it is dropped.
			flush()
		elseif CLOSERS[s] then
			depth = math.max(0, depth - 1)
			flush()
			lineDepth = depth
			push(t)
			if s == "end" then
				flush()
			elseif s == "else" then
				depth = depth + 1
				flush()
			end
			-- `elseif` is left open: its own `then` puts the level back.
			-- `until` keeps its condition beside it.
		elseif OPENERS[s] then
			push(t)
			depth = depth + 1
			flush()
		else
			if s == "function" then
				fnPending = true
			end

			if s == "(" or s == "[" or s == "{" then
				paren = paren + 1
				if s == "(" and fnPending then
					fnParen[#fnParen + 1] = paren
					fnPending = false
				end
				push(t)
			elseif CLOSING[s] then
				push(t)
				if s == ")" and fnParen[#fnParen] == paren then
					fnParen[#fnParen] = nil
					depth = depth + 1
					flush()
				end
				paren = math.max(0, paren - 1)
			else
				push(t)
			end
		end
	end
	flush()

	return lines
end

return M
