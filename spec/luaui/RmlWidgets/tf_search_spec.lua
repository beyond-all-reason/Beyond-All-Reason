-- The Terraform Brush search's matching: what a query finds and in what order.

local Search = VFS.Include("luaui/RmlWidgets/gui_terraform_brush/tf_search.lua")

local function entry(id, label, rest)
	return { id = id, label = label, hay = (label .. " " .. (rest or "")):lower(), where = "", frames = {} }
end

describe("terraform brush search", function()
	it("reads markup as the text a player sees", function()
		assert.are.equal("Save x & go", Search.plain("<div>Save {{name}}x</div>  <b>&amp;</b> go&nbsp;"))
		assert.are.equal("", Search.plain(nil))
	end)

	it("names a control without text from its id", function()
		assert.are.equal("CAPTURE UNITSIZE", Search.nameFromId("slider-capture-unitsize"))
		assert.are.equal("FOCUS", Search.nameFromId("btn-focus"))
	end)

	it("splits a query into lowercase words", function()
		assert.are.same({ "slope", "max" }, Search.words("  Slope   MAX "))
		assert.are.same({}, Search.words(""))
	end)

	it("wants every word, anywhere in the label, hint or place", function()
		local e = entry("a", "Avoid Slopes", "keeps features off cliffs FEATURES FILTERS")
		assert.is_truthy(Search.score(e, { "slope" }))
		assert.is_truthy(Search.score(e, { "cliffs", "features" }))
		assert.is_nil(Search.score(e, { "slope", "grass" }))
	end)

	it("puts a label that starts with the word first, a hint-only match last", function()
		local index = {
			entry("hint", "Ramp", "builds a slope between two points"),
			entry("inside", "Avoid Slopes"),
			entry("starts", "Slope"),
		}
		local hits, total = Search.find(index, "slope")
		assert.are.equal(3, total)
		assert.are.same({ "starts", "inside", "hint" }, { hits[1].id, hits[2].id, hits[3].id })
	end)

	it("returns at most the limit and still counts them all", function()
		local index = {}
		for i = 1, 10 do
			index[i] = entry("e" .. i, "Slope " .. i)
		end
		local hits, total = Search.find(index, "slope", 4)
		assert.are.equal(4, #hits)
		assert.are.equal(10, total)
		assert.are.equal("e1", hits[1].id)
	end)

	it("finds nothing for an empty query", function()
		local hits, total = Search.find({ entry("a", "Slope") }, "   ")
		assert.are.same({}, hits)
		assert.are.equal(0, total)
	end)
end)
