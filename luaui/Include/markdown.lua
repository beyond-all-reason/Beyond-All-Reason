-- Markdown for widget text panels.
--
-- Three stages, each usable on its own:
--   Markdown.parse(text)             -> doc    blocks and headings, inline markup resolved
--   Markdown.layout(doc, ctx)        -> rows   word-wrapped rows of styled segments
--   Markdown.draw(rows, i, j, x, y, ctx)       paints rows i..j with their top edge at y
--
-- Block level: ATX and setext headings, paragraphs (soft breaks joined, hard breaks on
-- a trailing backslash, two trailing spaces or <br>), nested bullet and numbered lists
-- with continuation paragraphs, blockquotes, fenced code, horizontal rules, pipe tables,
-- link reference definitions and HTML comments. Inline: **bold**, *italic*, `code`,
-- ~~strike~~, [text](url), <url> and bare http(s) links, images as their alt text, and
-- backslash escapes. Indented code blocks are deliberately not recognised; an indented
-- line outside a list is ordinary paragraph text, which is what changelog authors mean.
--
-- Bold uses a heavier face and code a monospaced one, so the wrapping measures every
-- word with the face it will be drawn in. Italic is the regular face sheared with a
-- matrix, which the engine's batched font path cannot do, so italic segments print
-- unbatched; ctx.italicShear = 0 turns that into plain text.

local Markdown = {}

local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local strSub = string.sub
local strFind = string.find
local strMatch = string.match
local strGsub = string.gsub
local strLower = string.lower
local strRep = string.rep
local tableConcat = table.concat

----------------------------------------------------------------------------------------
-- Inline markup
----------------------------------------------------------------------------------------

-- A run is { text = s, b = bold, i = italic, c = code, s = strike, link = url } or
-- { br = true } for a hard break. Runs that share a style are merged as they are added.
local function sameStyle(a, b)
	return a.b == b.b and a.i == b.i and a.c == b.c and a.s == b.s and a.link == b.link
end

local function withStyle(st, key, value)
	local t = { b = st.b, i = st.i, c = st.c, s = st.s, link = st.link }
	t[key] = value
	return t
end

local function isSpaceAt(s, i)
	local c = strSub(s, i, i)
	return c == "" or c == " " or c == "\n" or c == "\t"
end

local function isPunctAt(s, i)
	local c = strSub(s, i, i)
	return c ~= "" and strFind(c, "%p") ~= nil
end

local function isWordAt(s, i)
	local c = strSub(s, i, i)
	return c ~= "" and strFind(c, "[%w]") ~= nil
end

-- CommonMark's flanking test for a delimiter run at i..i+len-1: whether it may open
-- or close emphasis, judged by the characters on either side of it.
local function delimiterFlags(s, i, len, c)
	local prevSpace = isSpaceAt(s, i - 1)
	local nextSpace = isSpaceAt(s, i + len)
	local prevPunct = isPunctAt(s, i - 1)
	local nextPunct = isPunctAt(s, i + len)
	local left = not nextSpace and (not nextPunct or prevSpace or prevPunct)
	local right = not prevSpace and (not prevPunct or nextSpace or nextPunct)
	if c == "_" then
		return left and (not right or prevPunct), right and (not left or nextPunct)
	end
	return left, right
end

-- The matching close bracket for the one at `i`, honouring nesting and escapes.
local function matchBracket(s, i, open, close)
	local depth = 0
	local p = i
	local n = #s
	while p <= n do
		local ch = strSub(s, p, p)
		if ch == "\\" then
			p = p + 2
		else
			if ch == open then
				depth = depth + 1
			elseif ch == close then
				depth = depth - 1
				if depth == 0 then
					return p
				end
			end
			p = p + 1
		end
	end
	return nil
end

local function findTickClose(s, ticks, from)
	local p = from
	while true do
		local q = strFind(s, ticks, p, true)
		if not q then
			return nil
		end
		local after = q + #ticks
		if strSub(s, q - 1, q - 1) ~= "`" and strSub(s, after, after) ~= "`" then
			return q
		end
		p = after
	end
end

local parseInline

-- The text of a run list with the markup dropped, for labels and searches.
function Markdown.plainText(runs)
	local out = {}
	for k = 1, #runs do
		local r = runs[k]
		out[#out + 1] = r.br and " " or r.text
	end
	return tableConcat(out)
end

-- Walks `s` in style `st`, appending tokens: text { text, st }, breaks { br } and
-- emphasis delimiter runs { delim, n, open, close }, which are matched up afterwards.
local function scan(s, st, tokens, refs)
	local n = #s
	local i = 1
	local buf = {}

	local function text(t, style)
		if t ~= "" then
			tokens[#tokens + 1] = { text = t, st = style }
		end
	end

	local function flush()
		if #buf > 0 then
			text(tableConcat(buf), st)
			buf = {}
		end
	end

	local function inlineRuns(label, style)
		local runs = parseInline(label, refs, style)
		for k = 1, #runs do
			local r = runs[k]
			if r.br then
				tokens[#tokens + 1] = { br = true }
			else
				tokens[#tokens + 1] = { text = r.text, st = r }
			end
		end
	end

	while i <= n do
		local c = strSub(s, i, i)
		local handled = false

		if c == "\\" then
			local nx = strSub(s, i + 1, i + 1)
			if nx ~= "" and strFind(nx, "%p") then
				buf[#buf + 1] = nx
				i = i + 2
			else
				buf[#buf + 1] = c
				i = i + 1
			end
			handled = true
		elseif c == "\n" then
			flush()
			tokens[#tokens + 1] = { br = true }
			i = i + 1
			handled = true
		elseif c == "`" then
			local ticks = strMatch(s, "^`+", i)
			local close = findTickClose(s, ticks, i + #ticks)
			if close then
				local code = strSub(s, i + #ticks, close - 1)
				code = strGsub(code, "\n", " ")
				if #code >= 2 and strSub(code, 1, 1) == " " and strSub(code, -1) == " " and strFind(code, "%S") then
					code = strSub(code, 2, -2)
				end
				flush()
				text(code, withStyle(st, "c", true))
				i = close + #ticks
			else
				buf[#buf + 1] = ticks
				i = i + #ticks
			end
			handled = true
		elseif c == "*" or c == "_" or c == "~" then
			local run = strMatch(s, "^" .. (c == "*" and "%*+" or (c == "_" and "_+" or "~+")), i)
			local len = #run
			-- Only a double tilde strikes, so the lone "~" of "~25%" stays literal.
			if c ~= "~" or len == 2 then
				local open, close = delimiterFlags(s, i, len, c)
				flush()
				tokens[#tokens + 1] = { delim = c, n = len, orig = len, open = open, close = close, st = st, opens = {}, closes = {} }
			else
				buf[#buf + 1] = run
			end
			i = i + len
			handled = true
		elseif c == "[" or (c == "!" and strSub(s, i + 1, i + 1) == "[") then
			local isImage = c == "!"
			local start = isImage and i + 1 or i
			local close = matchBracket(s, start, "[", "]")
			if close then
				local label = strSub(s, start + 1, close - 1)
				local after = close + 1
				local url
				local resume
				local nextChar = strSub(s, after, after)
				if nextChar == "(" then
					local pclose = matchBracket(s, after, "(", ")")
					if pclose then
						local inner = strSub(s, after + 1, pclose - 1)
						url = strMatch(inner, "^%s*<([^>]*)>") or strMatch(inner, "^%s*(%S+)") or ""
						resume = pclose + 1
					end
				elseif nextChar == "[" then
					local rclose = strFind(s, "]", after + 1, true)
					if rclose then
						local id = strSub(s, after + 1, rclose - 1)
						if id == "" then
							id = label
						end
						url = refs[strLower(id)]
						if url then
							resume = rclose + 1
						end
					end
				else
					url = refs[strLower(label)]
					if url then
						resume = after
					end
				end
				if resume then
					flush()
					if isImage then
						-- No pictures here: the alt text stands in for the image.
						text(Markdown.plainText(parseInline(label, refs)), withStyle(st, "i", true))
					else
						inlineRuns(label, withStyle(st, "link", url))
					end
					i = resume
					handled = true
				end
			end
			if not handled then
				buf[#buf + 1] = c
				i = i + 1
				handled = true
			end
		elseif c == "<" then
			local url = strMatch(s, "^<(%a[%w+.-]*://[^%s<>]*)>", i)
			if url then
				flush()
				text(url, withStyle(st, "link", url))
				i = i + #url + 2
			else
				local br = strMatch(s, "^<[bB][rR]%s*/?>", i)
				if br then
					flush()
					tokens[#tokens + 1] = { br = true }
					i = i + #br
				else
					buf[#buf + 1] = c
					i = i + 1
				end
			end
			handled = true
		elseif c == "h" and (strFind(s, "^https?://", i)) and not isWordAt(s, i - 1) then
			local url = strMatch(s, "^https?://[^%s<]+", i)
			-- Trailing punctuation belongs to the sentence, not the address.
			local trimmed = strMatch(url, "^(.-)[%.,:;!%?%)]*$")
			if trimmed ~= "" then
				url = trimmed
			end
			flush()
			text(url, withStyle(st, "link", url))
			i = i + #url
			handled = true
		end

		if not handled then
			buf[#buf + 1] = c
			i = i + 1
		end
	end
	flush()
end

-- CommonMark's "process emphasis": every closing delimiter run looks back for the
-- nearest opener of its kind, they hand each other as many delimiters as both can
-- spare (two for bold, one for italic), and any delimiters between them are spent.
local function processEmphasis(tokens)
	local i = 1
	while i <= #tokens do
		local c = tokens[i]
		if c.delim and c.close and c.n > 0 then
			local j = i - 1
			local o
			while j >= 1 do
				local t = tokens[j]
				if t.delim and t.delim == c.delim and t.open and t.n > 0 and not t.spent then
					-- One run that could both open and close may not pair with another
					-- when their lengths add up to a multiple of three, unless both do.
					local odd = (t.close or c.open) and (t.orig + c.orig) % 3 == 0 and not (t.orig % 3 == 0 and c.orig % 3 == 0)
					if c.delim == "~" then
						odd = t.n ~= c.n
					end
					if not odd then
						o = t
						break
					end
				end
				j = j - 1
			end
			if o then
				local use
				if c.delim == "~" then
					use = 2
				else
					use = (o.n >= 2 and c.n >= 2) and 2 or 1
				end
				local kind = c.delim == "~" and "s" or (use == 2 and "b" or "i")
				o.opens[#o.opens + 1] = kind
				c.closes[#c.closes + 1] = kind
				o.n = o.n - use
				c.n = c.n - use
				for k = j + 1, i - 1 do
					if tokens[k].delim then
						tokens[k].spent = true
					end
				end
				if c.n == 0 then
					i = i + 1
				end
			else
				i = i + 1
			end
		else
			i = i + 1
		end
	end
end

-- Turns matched tokens into runs: leftover delimiters print literally, and the
-- emphasis they opened or closed nests as bold/italic/strike depth.
local function flattenTokens(tokens, runs)
	local depth = { b = 0, i = 0, s = 0 }

	local function emit(t, st)
		if t == "" then
			return
		end
		local style = {
			b = st.b or depth.b > 0,
			i = st.i or depth.i > 0,
			s = st.s or depth.s > 0,
			c = st.c,
			link = st.link,
		}
		local last = runs[#runs]
		if last and not last.br and sameStyle(last, style) then
			last.text = last.text .. t
		else
			style.text = t
			runs[#runs + 1] = style
		end
	end

	for k = 1, #tokens do
		local t = tokens[k]
		if t.br then
			runs[#runs + 1] = { br = true }
		elseif t.text then
			emit(t.text, t.st)
		else
			-- A closer's matches close innermost first; an opener's open outermost
			-- first, which is the reverse of the order they were found in.
			for m = 1, #t.closes do
				local kind = t.closes[m]
				depth[kind] = depth[kind] - 1
			end
			if t.n > 0 then
				emit(strRep(t.delim, t.n), t.st)
			end
			for m = #t.opens, 1, -1 do
				local kind = t.opens[m]
				depth[kind] = depth[kind] + 1
			end
		end
	end
end

parseInline = function(text, refs, style)
	local tokens = {}
	scan(text, style or {}, tokens, refs or {})
	processEmphasis(tokens)
	local runs = {}
	flattenTokens(tokens, runs)
	return runs
end

Markdown.parseInline = parseInline

----------------------------------------------------------------------------------------
-- Block structure
----------------------------------------------------------------------------------------

local function expandTabs(line)
	return (strGsub(line, "\t", "    "))
end

local function indentOf(line)
	local _, e = strFind(line, "^ *")
	return e
end

local function isBlank(line)
	return strFind(line, "^%s*$") ~= nil
end

-- Level and text of an ATX heading, or nil.
local function atxHeading(s)
	local hashes, rest = strMatch(s, "^(#+)[ \t]+(.-)[ \t]*$")
	if not hashes then
		hashes = strMatch(s, "^(#+)[ \t]*$")
		rest = ""
	end
	if not hashes or #hashes > 6 then
		return nil
	end
	rest = strGsub(rest, "[ \t]+#+$", "")
	if strFind(rest, "^#+$") then
		rest = ""
	end
	return #hashes, rest
end

local function isRule(s)
	local t = strGsub(s, "[ \t]", "")
	return #t >= 3 and (strFind(t, "^%-+$") or strFind(t, "^%*+$") or strFind(t, "^_+$")) ~= nil
end

local function fenceOpen(s)
	local sp, fence, info = strMatch(s, "^( *)(```+)(.*)$")
	if not fence then
		sp, fence, info = strMatch(s, "^( *)(~~~+)(.*)$")
	end
	if not fence then
		return nil
	end
	if strSub(fence, 1, 1) == "`" and strFind(info, "`") then
		return nil
	end
	return #sp, fence, strMatch(info, "^%s*(%S*)")
end

local function fenceClose(s, fence)
	local t = strMatch(s, "^ *(%S+)%s*$")
	return t ~= nil and #t >= #fence and strFind(t, "^" .. strSub(fence, 1, 1) .. "+$") ~= nil
end

-- Indent, content column, ordered flag, number and text of a list item line, or nil.
local function listMarker(s)
	local sp, mark = strMatch(s, "^( *)([-*+])[ \t]*$")
	if mark then
		return #sp, #sp + 2, false, nil, ""
	end
	local gap, text
	sp, mark, gap, text = strMatch(s, "^( *)([-*+])( +)(.*)$")
	if mark then
		local g = #gap
		if g > 4 then
			g = 1
		end
		return #sp, #sp + 1 + g, false, nil, text
	end
	local num
	sp, num, mark = strMatch(s, "^( *)(%d+)([.)])[ \t]*$")
	if num and #num <= 9 then
		return #sp, #sp + #num + 2, true, tonumber(num), ""
	end
	sp, num, mark, gap, text = strMatch(s, "^( *)(%d+)([.)])( +)(.*)$")
	if num and #num <= 9 then
		local g = #gap
		if g > 4 then
			g = 1
		end
		return #sp, #sp + #num + 1 + g, true, tonumber(num), text
	end
	return nil
end

local function splitCells(s)
	s = strGsub(s, "^%s*|", "")
	s = strGsub(s, "|%s*$", "")
	local cells = {}
	local cur = {}
	local i = 1
	local n = #s
	while i <= n do
		local c = strSub(s, i, i)
		if c == "\\" and strSub(s, i + 1, i + 1) == "|" then
			cur[#cur + 1] = "|"
			i = i + 2
		elseif c == "|" then
			cells[#cells + 1] = tableConcat(cur)
			cur = {}
			i = i + 1
		else
			cur[#cur + 1] = c
			i = i + 1
		end
	end
	cells[#cells + 1] = tableConcat(cur)
	for k = 1, #cells do
		cells[k] = strMatch(cells[k], "^%s*(.-)%s*$")
	end
	return cells
end

-- Column alignments of a table delimiter row such as | --- | :-: | --: |, or nil.
local function delimiterRow(s)
	if not strFind(s, "|", 1, true) or not strFind(s, "%-") then
		return nil
	end
	local cells = splitCells(s)
	local align = {}
	for k, c in ipairs(cells) do
		if not strFind(c, "^:?%-+:?$") then
			return nil
		end
		local l = strSub(c, 1, 1) == ":"
		local r = strSub(c, -1) == ":"
		align[k] = (l and r and "center") or (r and "right") or "left"
	end
	return align
end

local function isQuoteLine(s)
	return strFind(s, "^ ? ? ?>") ~= nil
end

local function stripQuote(s)
	return (strGsub(s, "^ ? ? ?> ?", ""))
end

local function startsBlock(s, nextLine)
	if atxHeading(s) or isRule(s) or fenceOpen(s) or isQuoteLine(s) or listMarker(s) then
		return true
	end
	if strFind(s, "|", 1, true) and nextLine and delimiterRow(nextLine) then
		return true
	end
	return false
end

-- Paragraph lines become one string: a soft break is a space, a hard break (trailing
-- backslash or two spaces) a newline for the inline scanner.
local function joinLines(lines)
	local out = {}
	local n = #lines
	for k = 1, n do
		local l = lines[k]
		local body = strGsub(l, "%s+$", "")
		if k < n then
			local hard = strFind(l, "  $") ~= nil
			if not hard and strFind(body, "\\$") then
				hard = true
				body = strSub(body, 1, -2)
			end
			out[#out + 1] = body
			out[#out + 1] = hard and "\n" or " "
		else
			out[#out + 1] = body
		end
	end
	return tableConcat(out)
end

local parseBlocks

-- Parses `lines` into `blocks`. `quote` is the blockquote depth of everything found.
parseBlocks = function(lines, blocks, quote, refs)
	local n = #lines
	local i = 1
	-- Open list items, innermost last: { col = content column, ordered, count }.
	local stack = {}
	-- Lists that a new item at each depth would continue: { ordered, count }.
	local listAt = {}
	-- The paragraph or item still collecting text lines.
	local open = nil
	local blankSeen = false

	local function closeOpen()
		open = nil
	end

	local function add(block)
		block.quote = quote
		blocks[#blocks + 1] = block
		return block
	end

	local function closeListsBelow(level)
		for k = #listAt, level + 1, -1 do
			listAt[k] = nil
		end
	end

	while i <= n do
		local line = expandTabs(lines[i])
		if isBlank(line) then
			closeOpen()
			blankSeen = true
			i = i + 1
		else
			local ind = indentOf(line)
			local nextLine = lines[i + 1] and expandTabs(lines[i + 1]) or nil
			local t0 = strSub(line, ind + 1)
			local lazy = open ~= nil and not blankSeen and not startsBlock(t0, nextLine) and not strFind(t0, "^=+%s*$")
			if lazy then
				open.lines[#open.lines + 1] = strSub(line, ind + 1)
				i = i + 1
			else
				while #stack > 0 and ind < stack[#stack].col do
					stack[#stack] = nil
				end
				local level = #stack
				local base = level > 0 and stack[level].col or 0
				local s = strSub(line, base + 1)
				local t = strSub(s, indentOf(s) + 1)

				local fenceIndent, fence, lang = fenceOpen(s)
				local hLevel, hText = atxHeading(t)
				local _, mCol, ordered, number, mText = listMarker(s)

				if fence then
					closeOpen()
					closeListsBelow(level)
					local code = {}
					i = i + 1
					while i <= n do
						local l = expandTabs(lines[i])
						if fenceClose(strSub(l, base + 1), fence) then
							i = i + 1
							break
						end
						-- Lines keep their own indentation past the fence's.
						local strip = mathMin(base + fenceIndent, indentOf(l))
						code[#code + 1] = strSub(l, strip + 1)
						i = i + 1
					end
					add({ kind = "code", lines = code, lang = lang, indent = level })
					blankSeen = false
				elseif hLevel then
					closeOpen()
					closeListsBelow(level)
					add({ kind = "heading", level = hLevel, lines = { hText }, indent = level })
					blankSeen = false
					i = i + 1
				elseif open and open.kind == "para" and not blankSeen and (strFind(t, "^=+%s*$") or strFind(t, "^%-+%s*$")) then
					-- A setext underline turns the paragraph above into a heading.
					open.kind = "heading"
					open.level = strFind(t, "^=") and 1 or 2
					closeOpen()
					i = i + 1
				elseif isRule(t) then
					closeOpen()
					closeListsBelow(level)
					add({ kind = "rule", indent = level })
					blankSeen = false
					i = i + 1
				elseif isQuoteLine(s) then
					closeOpen()
					closeListsBelow(level)
					local inner = {}
					while i <= n do
						local l = expandTabs(lines[i])
						local rel = strSub(l, base + 1)
						if isQuoteLine(rel) then
							inner[#inner + 1] = stripQuote(rel)
						elseif not isBlank(l) and #inner > 0 and not startsBlock(strSub(l, indentOf(l) + 1), nil) and not isBlank(inner[#inner]) then
							-- Lazy continuation of the quoted paragraph.
							inner[#inner + 1] = strSub(l, indentOf(l) + 1)
						else
							break
						end
						i = i + 1
					end
					local sub = {}
					parseBlocks(inner, sub, quote + 1, refs)
					for k = 1, #sub do
						sub[k].indent = (sub[k].indent or 0) + level
						blocks[#blocks + 1] = sub[k]
					end
					blankSeen = false
				elseif strFind(t, "|", 1, true) and nextLine and delimiterRow(strSub(nextLine, base + 1)) then
					closeOpen()
					closeListsBelow(level)
					local align = delimiterRow(strSub(nextLine, base + 1))
					local header = splitCells(t)
					local rows = {}
					i = i + 2
					while i <= n do
						local l = expandTabs(lines[i])
						if isBlank(l) or not strFind(l, "|", 1, true) then
							break
						end
						rows[#rows + 1] = splitCells(strSub(l, indentOf(l) + 1))
						i = i + 1
					end
					add({ kind = "table", header = header, align = align, rows = rows, indent = level })
					blankSeen = false
				elseif mCol then
					closeOpen()
					local newLevel = level + 1
					closeListsBelow(newLevel)
					local list = listAt[newLevel]
					local loose = false
					if list and list.ordered == ordered then
						list.count = list.count + 1
						loose = blankSeen
					else
						list = { ordered = ordered, count = number or 1 }
						listAt[newLevel] = list
					end
					stack[newLevel] = { col = base + mCol }
					local item = add({
						kind = "item",
						level = newLevel,
						ordered = ordered,
						number = list.count,
						lines = { mText },
						loose = loose,
						indent = newLevel,
					})
					open = item
					blankSeen = false
					i = i + 1
				else
					local id, url = strMatch(t, "^%[([^%]]+)%]:%s*(%S+)")
					if id and not open then
						refs[strLower(id)] = url
						i = i + 1
					else
						closeListsBelow(level)
						local para = add({ kind = "para", lines = { t }, indent = level, loose = blankSeen and level > 0 })
						open = para
						blankSeen = false
						i = i + 1
					end
				end
			end
		end
	end
end

-- Parses a whole document. Blocks carry `inline` (runs) where they hold text, `indent`
-- (enclosing list depth) and `quote` (blockquote depth). `doc.headings` lists every
-- heading with its block index; `doc.chapterLevel` is the shallowest level used, the
-- one a table of contents should be built from.
function Markdown.parse(text)
	text = text or ""
	if strSub(text, 1, 3) == "\239\187\191" then
		text = strSub(text, 4)
	end
	text = strGsub(text, "<!%-%-.-%-%->", "")
	local lines = {}
	for line in string.gmatch(text .. "\n", "(.-)\r?\n") do
		lines[#lines + 1] = line
	end

	local refs = {}
	local blocks = {}
	parseBlocks(lines, blocks, 0, refs)

	local headings = {}
	local chapterLevel = 7
	for k = 1, #blocks do
		local b = blocks[k]
		if b.lines and b.kind ~= "code" then
			b.text = joinLines(b.lines)
			b.inline = parseInline(b.text, refs)
			b.lines = nil
		end
		if b.kind == "heading" then
			b.text = Markdown.plainText(b.inline)
			headings[#headings + 1] = { level = b.level, text = b.text, block = k }
			if b.level < chapterLevel then
				chapterLevel = b.level
			end
		elseif b.kind == "table" then
			b.headerInline = {}
			for c = 1, #b.header do
				b.headerInline[c] = parseInline(b.header[c], refs)
			end
			b.rowsInline = {}
			for r = 1, #b.rows do
				local row = {}
				for c = 1, #b.header do
					row[c] = parseInline(b.rows[r][c] or "", refs)
				end
				b.rowsInline[r] = row
			end
		end
	end
	if chapterLevel == 7 then
		chapterLevel = 1
	end

	return { blocks = blocks, headings = headings, chapterLevel = chapterLevel }
end

----------------------------------------------------------------------------------------
-- Layout
----------------------------------------------------------------------------------------

-- Sizes and colours at a given UI scale. Callers override what they need to and must
-- supply ctx.fonts = { regular, bold, mono } and ctx.width.
function Markdown.defaultContext(scale)
	scale = scale or 1
	local function px(v)
		return mathFloor(v * scale)
	end
	return {
		scale = scale,
		width = 600,
		fonts = nil,
		fs = {
			body = px(15),
			code = px(14),
			h = { px(18), px(16), px(15), px(15), px(14), px(14) },
		},
		-- Row height as a multiple of the font size; 15 px text sits on a 19 px grid.
		lineMul = 1.27,
		listIndent = px(24),
		markerGap = px(14),
		numberGap = px(6),
		quoteIndent = px(14),
		quoteBar = px(3),
		cellPad = px(10),
		tableRowPad = px(3),
		gapPara = px(6),
		gapHeading = px(8),
		gapCode = px(4),
		codePad = px(5),
		gapRule = px(6),
		corner = px(3),
		italicShear = 0.18,
		bullets = { "\226\128\162", "\226\151\166", "\226\150\170" }, -- • ◦ ▪
		colors = {
			text = { 0.8, 0.77, 0.74, 1 },
			heading = { 1, 1, 1, 1 },
			bold = { 0.95, 0.94, 0.92, 1 },
			code = { 0.85, 0.9, 0.95, 1 },
			codeBg = { 1, 1, 1, 0.07 },
			codeBlockBg = { 0, 0, 0, 0.22 },
			link = { 0.55, 0.75, 1, 1 },
			strike = { 0.58, 0.56, 0.54, 1 },
			marker = { 0.6, 0.58, 0.55, 1 },
			quoteBar = { 1, 1, 1, 0.22 },
			quoteText = { 0.68, 0.66, 0.64, 1 },
			rule = { 1, 1, 1, 0.15 },
			tableBg = { 1, 1, 1, 0.04 },
			tableHeadBg = { 1, 1, 1, 0.07 },
			tableStripe = { 1, 1, 1, 0.03 },
			tableLine = { 1, 1, 1, 0.22 },
		},
	}
end

-- Word widths per face at size 1, so a page of repeated words measures once.
local widthCache = setmetatable({}, { __mode = "k" })

local function textWidth(font, s)
	local cache = widthCache[font]
	if not cache then
		cache = {}
		widthCache[font] = cache
	end
	local w = cache[s]
	if not w then
		w = font:GetTextWidth(s)
		cache[s] = w
	end
	return w
end

local function fontFor(run, ctx, forceBold)
	local fonts = ctx.fonts
	if run.c and fonts.mono then
		return fonts.mono, "mono"
	elseif (run.b or forceBold) and fonts.bold then
		return fonts.bold, "bold"
	end
	return fonts.regular, "regular"
end

local function colorFor(run, ctx, base)
	local colors = ctx.colors
	if run.link then
		return colors.link
	elseif run.c then
		return colors.code
	elseif run.s then
		return colors.strike
	elseif run.b and base == colors.text then
		return colors.bold
	end
	return base
end

-- Splits text into UTF-8 characters, for words wider than the whole column.
local function utf8Chars(s)
	local out = {}
	for ch in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
		out[#out + 1] = ch
	end
	return out
end

-- Wraps `runs` into rows of segments no wider than `width`. Segment x is relative to
-- the text column. Returns the rows as arrays of segments with `w` (used width).
local function wrapRuns(runs, width, fs, ctx, baseColor, forceBold)
	local rows = {}
	local row = { w = 0 }
	rows[1] = row
	local pendingSpace = false

	local function newRow()
		row = { w = 0 }
		rows[#rows + 1] = row
		pendingSpace = false
	end

	local function place(text, w, run, font, face, color, joinSpace, spaceW)
		local last = row[#row]
		if joinSpace and last and last.run == run then
			last.text = last.text .. " " .. text
			last.w = last.w + spaceW + w
			row.w = row.w + spaceW + w
		else
			-- Whole pixels, so glyphs do not land between them after a style change.
			local x = mathFloor(row.w + (joinSpace and spaceW or 0))
			row[#row + 1] = {
				x = x,
				w = w,
				text = text,
				font = font,
				face = face,
				fs = fs,
				color = color,
				run = run,
				code = run.c,
				strike = run.s,
				link = run.link,
				italic = run.i and ctx.italicShear ~= 0,
			}
			row.w = x + w
		end
	end

	for k = 1, #runs do
		local run = runs[k]
		if run.br then
			newRow()
		else
			local font, face = fontFor(run, ctx, forceBold)
			local color = colorFor(run, ctx, baseColor)
			local spaceW = textWidth(font, " ") * fs
			local text = run.text
			local p = 1
			local n = #text
			while p <= n do
				local a, b = strFind(text, "^%s+", p)
				if a then
					if row.w > 0 then
						pendingSpace = true
					end
					p = b + 1
				else
					a, b = strFind(text, "^%S+", p)
					local tok = strSub(text, a, b)
					p = b + 1
					local w = textWidth(font, tok) * fs
					if row.w == 0 then
						if w > width then
							-- Too wide for a whole row: break it by character.
							local chars = utf8Chars(tok)
							local piece = ""
							local pieceW = 0
							for c = 1, #chars do
								local cw = textWidth(font, chars[c]) * fs
								if pieceW + cw > width and piece ~= "" then
									place(piece, pieceW, run, font, face, color, false, 0)
									newRow()
									piece = ""
									pieceW = 0
								end
								piece = piece .. chars[c]
								pieceW = pieceW + cw
							end
							place(piece, pieceW, run, font, face, color, false, 0)
						else
							place(tok, w, run, font, face, color, false, 0)
						end
					elseif pendingSpace then
						if row.w + spaceW + w <= width then
							place(tok, w, run, font, face, color, true, spaceW)
						else
							newRow()
							if w > width then
								local chars = utf8Chars(tok)
								local piece = ""
								local pieceW = 0
								for c = 1, #chars do
									local cw = textWidth(font, chars[c]) * fs
									if pieceW + cw > width and piece ~= "" then
										place(piece, pieceW, run, font, face, color, false, 0)
										newRow()
										piece = ""
										pieceW = 0
									end
									piece = piece .. chars[c]
									pieceW = pieceW + cw
								end
								place(piece, pieceW, run, font, face, color, false, 0)
							else
								place(tok, w, run, font, face, color, false, 0)
							end
						end
					else
						-- Glued to the previous token (a style change mid-word).
						if row.w + w <= width or row.w == 0 then
							place(tok, w, run, font, face, color, false, 0)
						else
							newRow()
							place(tok, w, run, font, face, color, false, 0)
						end
					end
					pendingSpace = false
				end
			end
		end
	end
	return rows
end

-- The measured width of runs on one line, for table columns.
local function runsWidth(runs, fs, ctx)
	local w = 0
	for k = 1, #runs do
		local run = runs[k]
		if not run.br then
			local font = fontFor(run, ctx)
			w = w + textWidth(font, run.text) * fs
		end
	end
	return w
end

-- Lays a document out against ctx.width. Each row: h (advance), pad (space above the
-- text box), box (text box height), base (baseline below the row top), x (left indent),
-- segs, plus block, kind, quote, marker and decoration flags. Blocks get `firstRow`.
function Markdown.layout(doc, ctx)
	local rows = {}
	local blocks = doc.blocks
	local colors = ctx.colors
	local lineMul = ctx.lineMul

	local function boxFor(fs)
		return mathFloor(fs * lineMul + 0.5)
	end

	local function addRow(block, kind, fs, xIndent, segs, marker)
		local box = boxFor(fs)
		local row = {
			h = box,
			pad = 0,
			box = box,
			base = box,
			x = xIndent,
			w = segs and segs.w or 0,
			segs = segs or {},
			block = block,
			kind = kind,
			quote = block.quote or 0,
			marker = marker,
		}
		rows[#rows + 1] = row
		return row
	end

	local function padTop(row, gap)
		row.pad = row.pad + gap
		row.base = row.base + gap
		row.h = row.h + gap
	end

	local function gapBottom(row, gap)
		row.h = row.h + gap
	end

	for bi = 1, #blocks do
		local b = blocks[bi]
		local prev = blocks[bi - 1]
		local nxt = blocks[bi + 1]
		local xIndent = (b.indent or 0) * ctx.listIndent + (b.quote or 0) * ctx.quoteIndent
		local width = mathMax(ctx.width - xIndent, ctx.listIndent)
		local first = #rows + 1
		local baseColor = (b.quote or 0) > 0 and colors.quoteText or colors.text

		if b.kind == "heading" then
			local fs = ctx.fs.h[mathMin(b.level, 6)]
			local wrapped = wrapRuns(b.inline, width, fs, ctx, colors.heading, true)
			for r = 1, #wrapped do
				addRow(b, "heading", fs, xIndent, wrapped[r])
			end
			if prev then
				padTop(rows[first], ctx.gapHeading)
			end
			gapBottom(rows[#rows], mathFloor(ctx.gapPara * 0.34))
		elseif b.kind == "para" then
			local fs = ctx.fs.body
			local wrapped = wrapRuns(b.inline, width, fs, ctx, baseColor)
			for r = 1, #wrapped do
				addRow(b, "text", fs, xIndent, wrapped[r])
			end
			if b.loose then
				padTop(rows[first], ctx.gapPara)
			end
			if not (nxt and nxt.kind == "item" and nxt.level == (b.indent or 0)) then
				gapBottom(rows[#rows], ctx.gapPara)
			end
		elseif b.kind == "item" then
			local fs = ctx.fs.body
			local wrapped = wrapRuns(b.inline, width, fs, ctx, baseColor)
			local marker
			if b.ordered then
				local label = tostring(b.number) .. "."
				marker = {
					text = label,
					font = ctx.fonts.regular,
					face = "regular",
					fs = fs,
					color = colors.marker,
					x = -ctx.numberGap - mathFloor(textWidth(ctx.fonts.regular, label) * fs + 0.5),
				}
			else
				local glyph = ctx.bullets[((b.level - 1) % #ctx.bullets) + 1]
				marker = {
					text = glyph,
					font = ctx.fonts.mono or ctx.fonts.regular,
					face = ctx.fonts.mono and "mono" or "regular",
					fs = fs,
					color = colors.marker,
					x = -ctx.markerGap,
				}
			end
			for r = 1, #wrapped do
				addRow(b, "text", fs, xIndent, wrapped[r], r == 1 and marker or nil)
			end
			if b.loose then
				padTop(rows[first], ctx.gapPara)
			end
			-- No gap before the next item of the same list, a nested one, or the parent
			-- list resuming; a different list or anything else gets one.
			local continues = nxt
				and ((nxt.kind == "item" and (nxt.level ~= b.level or nxt.ordered == b.ordered)) or (nxt.kind == "para" and (nxt.indent or 0) > 0))
			if not continues then
				gapBottom(rows[#rows], ctx.gapPara)
			end
		elseif b.kind == "code" then
			local fs = ctx.fs.code
			local font = ctx.fonts.mono or ctx.fonts.regular
			local run = { c = true, text = "" }
			local lines = b.lines
			if #lines == 0 then
				lines = { "" }
			end
			for l = 1, #lines do
				local text = strGsub(lines[l], "%s+$", "")
				local segs = { w = 0 }
				if text ~= "" then
					-- Code keeps its spacing, so it wraps by character, not by word.
					local chars = utf8Chars(text)
					local piece = {}
					local pieceW = 0
					local innerW = width - ctx.codePad * 2
					for c = 1, #chars do
						local cw = textWidth(font, chars[c]) * fs
						if pieceW + cw > innerW and #piece > 0 then
							segs[#segs + 1] = { x = ctx.codePad, w = pieceW, text = tableConcat(piece), font = font, face = "mono", fs = fs, color = colors.code, run = run }
							segs.w = pieceW
							addRow(b, "code", fs, xIndent, segs).codeBlock = bi
							segs = { w = 0 }
							piece = {}
							pieceW = 0
						end
						piece[#piece + 1] = chars[c]
						pieceW = pieceW + cw
					end
					segs[#segs + 1] = { x = ctx.codePad, w = pieceW, text = tableConcat(piece), font = font, face = "mono", fs = fs, color = colors.code, run = run }
					segs.w = pieceW
				end
				addRow(b, "code", fs, xIndent, segs).codeBlock = bi
			end
			padTop(rows[first], ctx.gapCode + ctx.codePad)
			gapBottom(rows[#rows], ctx.gapCode + ctx.codePad)
		elseif b.kind == "rule" then
			local row = addRow(b, "rule", 0, xIndent, nil)
			row.pad = ctx.gapRule
			row.box = 1
			row.base = ctx.gapRule + 1
			row.h = ctx.gapRule * 2 + 1
			row.rule = true
		elseif b.kind == "table" then
			local fs = ctx.fs.body
			local ncol = #b.header
			local colW = {}
			local headerRuns = {}
			for c = 1, ncol do
				local runs = {}
				for k = 1, #b.headerInline[c] do
					local r = b.headerInline[c][k]
					runs[k] = r.br and r or { text = r.text, b = true, i = r.i, c = r.c, s = r.s, link = r.link }
				end
				headerRuns[c] = runs
				colW[c] = runsWidth(runs, fs, ctx)
			end
			for r = 1, #b.rowsInline do
				for c = 1, ncol do
					colW[c] = mathMax(colW[c], runsWidth(b.rowsInline[r][c], fs, ctx))
				end
			end
			for c = 1, ncol do
				colW[c] = mathFloor(colW[c] + 0.999)
			end
			local total = 0
			for c = 1, ncol do
				total = total + colW[c] + ctx.cellPad * 2
			end
			-- A table wider than the column shrinks to fit rather than running under the
			-- scrollbar.
			if total > width and total > 0 then
				local f = width / total
				fs = mathMax(mathFloor(fs * f), mathFloor(ctx.fs.body * 0.6))
				for c = 1, ncol do
					colW[c] = mathFloor(colW[c] * fs / ctx.fs.body)
				end
				total = 0
				for c = 1, ncol do
					total = total + colW[c] + ctx.cellPad * 2
				end
			end
			local colX = {}
			local x = 0
			for c = 1, ncol do
				colX[c] = x
				x = x + colW[c] + ctx.cellPad * 2
			end

			local function cellSegs(cellRuns, c, segs)
				local runs = cellRuns[c] or {}
				local cw = runsWidth(runs, fs, ctx)
				local align = b.align[c] or "left"
				local sx = colX[c] + ctx.cellPad
				if align == "center" then
					sx = sx + mathFloor((colW[c] - cw) * 0.5)
				elseif align == "right" then
					sx = sx + mathFloor(colW[c] - cw)
				end
				for k = 1, #runs do
					local run = runs[k]
					if not run.br then
						local font, face = fontFor(run, ctx)
						local w = textWidth(font, run.text) * fs
						segs[#segs + 1] = {
							x = sx,
							w = w,
							text = run.text,
							font = font,
							face = face,
							fs = fs,
							color = colorFor(run, ctx, baseColor),
							run = run,
							code = run.c,
							strike = run.s,
							link = run.link,
							italic = run.i and ctx.italicShear ~= 0,
						}
						sx = mathFloor(sx + w + 0.5)
					end
				end
			end

			local segs = { w = total }
			for c = 1, ncol do
				cellSegs(headerRuns, c, segs)
			end
			local head = addRow(b, "table", fs, xIndent, segs)
			head.tableHead = true
			head.tableW = total
			head.tableBlock = bi
			head.tableRow = 0
			padTop(head, ctx.tableRowPad)
			gapBottom(head, ctx.tableRowPad)
			for r = 1, #b.rowsInline do
				segs = { w = total }
				for c = 1, ncol do
					cellSegs(b.rowsInline[r], c, segs)
				end
				local row = addRow(b, "table", fs, xIndent, segs)
				row.tableW = total
				row.tableBlock = bi
				row.tableRow = r
				padTop(row, ctx.tableRowPad)
				gapBottom(row, ctx.tableRowPad)
			end
			gapBottom(rows[#rows], ctx.gapPara)
		end

		b.firstRow = first
		b.lastRow = #rows
	end

	return rows
end

-- Total height of rows i..j when i is the first row shown (its top padding is not
-- drawn, so the text starts flush with the top edge).
function Markdown.rowsHeight(rows, i, j)
	local h = 0
	for k = i, j do
		h = h + rows[k].h
	end
	if rows[i] then
		h = h - rows[i].pad
	end
	return h
end

----------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------

local glColor = gl.Color
local glRect = gl.Rect
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glMultMatrix = gl.MultMatrix

-- Paints rows first..last of `rows` with the text column's left edge at `x` and the
-- first row's text box starting at `top`. ctx.rectRound(x1, y1, x2, y2, cs, tl, tr, br,
-- bl, color) draws the rounded fills (FlowUI's RectRound); without it plain rects are
-- used.
function Markdown.draw(rows, first, last, x, top, ctx)
	local colors = ctx.colors
	local rectRound = ctx.rectRound
	local width = ctx.width

	local function fill(x1, y1, x2, y2, color, cs, tl, tr, br, bl)
		if rectRound and cs and cs > 0 then
			rectRound(x1, y1, x2, y2, cs, tl or 1, tr or 1, br or 1, bl or 1, color)
		else
			glColor(color)
			glRect(x1, y1, x2, y2)
		end
	end

	-- Pass 1: row tops and baselines. The first row's padding is eaten so the text
	-- starts at `top` whatever block it belongs to.
	local tops = {}
	local bases = {}
	local y = top + (rows[first] and rows[first].pad or 0)
	for i = first, last do
		local row = rows[i]
		tops[i] = y
		bases[i] = y - row.base
		y = y - row.h
	end

	-- Pass 2: block backgrounds. Code boxes span every contiguous run of their rows on
	-- this page; quote bars and rules are per row and join up seamlessly.
	local groupStart, groupBlock
	local function flushCode(i)
		if groupStart then
			local r1 = rows[groupStart]
			local yTop = tops[groupStart] - (groupStart == r1.block.firstRow and ctx.gapCode or 0)
			if yTop > top then
				yTop = top
			end
			local rN = rows[i]
			local yBot = tops[i] - rN.h + (i == rN.block.lastRow and ctx.gapCode or 0)
			fill(x + r1.x, yBot, x + width, yTop, colors.codeBlockBg, ctx.corner)
			groupStart = nil
			groupBlock = nil
		end
	end
	for i = first, last do
		local row = rows[i]
		if row.codeBlock then
			if groupBlock ~= row.codeBlock then
				if groupStart then
					flushCode(i - 1)
				end
				groupStart = i
				groupBlock = row.codeBlock
			end
		elseif groupStart then
			flushCode(i - 1)
		end
	end
	if groupStart then
		flushCode(last)
	end

	-- Tables: a faint card under every contiguous run of a table's rows on this page, a
	-- band behind the header with a line beneath it, and every other body row shaded.
	-- Bands run from the row's top to just under its text, so the trailing gap after
	-- the table stays clear.
	local function bandTop(i)
		local t = tops[i]
		if t > top then
			t = top
		end
		return t
	end
	local function bandBottom(i)
		local r = rows[i]
		return tops[i] - r.pad - r.box - ctx.tableRowPad
	end
	local tStart, tBlock
	local function flushTable(i)
		if tStart then
			local r1 = rows[tStart]
			local x1 = x + r1.x
			local x2 = x1 + r1.tableW
			fill(x1, bandBottom(i), x2, bandTop(tStart), colors.tableBg, ctx.corner)
			for k = tStart, i do
				local r = rows[k]
				local topCorner = k == tStart and 1 or 0
				local bottomCorner = k == i and 1 or 0
				if r.tableRow == 0 then
					fill(x1, bandBottom(k), x2, bandTop(k), colors.tableHeadBg, ctx.corner, topCorner, topCorner, bottomCorner, bottomCorner)
					fill(x1, bandBottom(k), x2, bandBottom(k) + 1, colors.tableLine)
				elseif r.tableRow % 2 == 0 then
					fill(x1, bandBottom(k), x2, bandTop(k), colors.tableStripe, ctx.corner, topCorner, topCorner, bottomCorner, bottomCorner)
				end
			end
			tStart = nil
			tBlock = nil
		end
	end
	for i = first, last do
		local row = rows[i]
		if row.tableBlock then
			if tBlock ~= row.tableBlock then
				if tStart then
					flushTable(i - 1)
				end
				tStart = i
				tBlock = row.tableBlock
			end
		elseif tStart then
			flushTable(i - 1)
		end
	end
	if tStart then
		flushTable(last)
	end

	for i = first, last do
		local row = rows[i]
		local rowTop = tops[i]
		local rowBottom = rowTop - row.h
		if row.quote > 0 then
			for d = 1, row.quote do
				local bx = x + row.x - (row.quote - d + 1) * ctx.quoteIndent
				fill(bx, rowBottom, bx + ctx.quoteBar, rowTop, colors.quoteBar)
			end
		end
		if row.rule then
			local ly = rowTop - ctx.gapRule
			fill(x + row.x, ly - 1, x + width, ly, colors.rule)
		end
	end

	-- Pass 3: inline decorations under the glyphs.
	for i = first, last do
		local row = rows[i]
		local segs = row.segs
		local base = bases[i]
		for k = 1, #segs do
			local seg = segs[k]
			local sx = x + row.x + seg.x
			local ex = mathFloor(sx + seg.w + 0.5)
			if seg.code and row.kind ~= "code" then
				local pad = mathFloor(seg.fs * 0.15)
				fill(sx - pad, base - mathFloor(seg.fs * 0.22), ex + pad, base + mathFloor(seg.fs * 0.82), colors.codeBg, mathFloor(ctx.corner * 0.66))
			end
			if seg.link then
				fill(sx, base - 2, ex, base - 1, seg.color)
			end
			if seg.strike then
				local ly = base + mathFloor(seg.fs * 0.3)
				fill(sx, ly, ex, ly + 1, seg.color)
			end
		end
	end

	-- Pass 4: glyphs, one batch per face. Italic segments are sheared, so they print
	-- on their own outside the batches.
	local italics = {}
	local faces = { "regular", "bold", "mono" }
	for f = 1, #faces do
		local face = faces[f]
		local font = ctx.fonts[face]
		if font then
			font:Begin()
			for i = first, last do
				local row = rows[i]
				local base = bases[i]
				local marker = row.marker
				if marker and marker.face == face then
					font:SetTextColor(marker.color)
					font:Print(marker.text, x + row.x + marker.x, base, marker.fs, "n")
				end
				local segs = row.segs
				for k = 1, #segs do
					local seg = segs[k]
					if seg.face == face then
						if seg.italic then
							italics[#italics + 1] = { seg = seg, x = x + row.x + seg.x, y = base }
						else
							font:SetTextColor(seg.color)
							font:Print(seg.text, x + row.x + seg.x, base, seg.fs, "n")
						end
					end
				end
			end
			font:End()
		end
	end

	local shear = ctx.italicShear
	for k = 1, #italics do
		local it = italics[k]
		local seg = it.seg
		glPushMatrix()
		glTranslate(it.x, it.y, 0)
		glMultMatrix(1, 0, 0, 0, shear, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
		seg.font:SetTextColor(seg.color)
		seg.font:Print(seg.text, 0, 0, seg.fs, "n")
		glPopMatrix()
	end
	glColor(1, 1, 1, 1)
end

return Markdown
