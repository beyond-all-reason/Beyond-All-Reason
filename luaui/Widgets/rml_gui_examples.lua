if not RmlUi then
	return false
end

function widget:GetInfo()
	return {
		name = "RML Examples",
		desc = "Test Cases / Examples for RmlUi",
		author = "ChrisFloofyKitsune",
		date = "June 2024",
		license = "https://unlicense.org/",
		layer = -828888,
		handler = true,
		enabled = true
	}
end

widget.rmlContext = nil
local document = nil
local data_handle = nil
local tabset = nil
local tab_index = 0

local function addPage(name, content)
	tabset:SetTab(tab_index, name)
	tabset:SetPanel(tab_index, content)
	tab_index = tab_index + 1

	local textareas = tabset:QuerySelectorAll('panel:last-child > code > textarea')
	for idx = 1, #textareas do
		local textarea = RmlUi.Element.As.ElementFormControlTextArea(textareas[idx])
		local lines = textarea.value:split('\n')
		textarea.rows = math.min(5, #lines)
		textarea:AddEventListener('textinput', function(ev)
			ev:StopImmediatePropagation()
		end)
		textarea:AddEventListener('keydown', function(ev)
			local key = ev.parameters.key_identifier
			if key == RmlUi.key_identifier().BACK or key == RmlUi.key_identifier().DELETE then
				ev:StopImmediatePropagation()
			end
		end)
	end
end

local function createSection(name, content)
	content = content:trim()
	local rml_result = "<h3>" .. name .. "</h3>\n<div>" .. content .. "</div>\n"
	local escaped_content = content
	escaped_content = escaped_content:gsub('"', '&quot;')
	escaped_content = escaped_content:gsub('\t', '  ')
	rml_result = rml_result .. '<h4>Code</h4>\n'
	rml_result = rml_result .. '<code class="example-code"><textarea class="code-area" value="' .. escaped_content .. '">'
	rml_result = rml_result .. '</textarea></code>'
	return rml_result
end

function widget:Initialize()
	widget.rmlContext = RmlUi.CreateContext(widget.whInfo.name)
	
	data_handle = widget.rmlContext:OpenDataModel("data_model_test", {
		tab_name = '',
	});

	document = widget.rmlContext:LoadDocument("luaui/widgets/rml_gui_examples.rml", widget)
	document:ReloadStyleSheet()
	document:Show()

	tabset = document:QuerySelector('tabset')
	tabset = RmlUi.Element.As.ElementTabSet(tabset)
	tabset:AddEventListener('tabchange', function()
		local tab = document:QuerySelector('tab:selected')
		data_handle.tab_name = tab and tab.inner_rml or ""
	end)

	-- these elements are automatically created and must be interacted with programmatically
	tabset:QuerySelector('tabs'):SetClass('element', true)
	tabset:QuerySelector('panels'):SetClass('element', true)

	------------------------
	---- BASIC ELEMENTS ----
	------------------------

	addPage('Basic Elements',
		createSection('Layout', [[
<div>div</div>
Horizontal Rule<hr/>
<p>paragraph</p>
<span>span</span>
<div class="element">styled 'container' element</div>
]]) .. createSection('Text Decoration', [[
<b>Bold </b> <strong>Strong</strong><br/>
<i>Italic </i> <em>Emphasis</em><br/>
<u>Underline</u><br/>
<s>Strikethrough</s><br/>
<code>code</code><br/>
<pre>
Preformatted
       text
</pre>
]]) .. createSection('Headings', [[
<div style="display: flex; flex-direction: row; align-items: flex-end;">
	<h1>h1</h1>
	<h2>h2</h2>
	<h3>h3</h3>
	<h4>h4</h4>
	<h5>h5</h5>
	<h6>h6</h6>
</div>
]]))
	--for i = 1, 1 do
	--	local content = ''
	--	for j = 1, 1 do
	--		content = content .. createSection('Section ' .. i .. '.' .. j, '<div class="element">Content ' .. j .. '</div>')
	--	end
	--	addPage('tab ' .. i, content)
	--end
	
	------------------------
	---- MEDIA ELEMENTS ----
	------------------------

	addPage('Media Elements',
		createSection('Images (Relative Paths)', [[
<div style="max-width: 100%">
	<img src="/bitmaps/loadpictures/armada.jpg" style="width: 50%;"/>
	<img src="/bitmaps/loadpictures/cortex.jpg" style="width: 50%;"/>
</div>
]]) .. createSection('Image Texture Examples (Custom Element, Absolute Paths, Tints)', [[
<div style="max-width: 100%">
	<texture src=":t0,1,1:bitmaps/loadpictures/armada.jpg" style="width: 50%;"/>
	<texture src=":t1,0,1:bitmaps/loadpictures/cortex.jpg" style="width: 50%;"/>
</div>
]]) .. createSection('Texture Types', [[
<div style="display: flex; flex-direction: row;">
	<div>
		<h5>Build Picture</h5>
		<texture src="#101" style="width: 100px; height: 100px"/>
	</div>
	<div>
		<h5>Radar Icon</h5>
		<texture src="^101" style="width: 100px; height: 100px"/>
	</div>
	<div>
		<h5>Color Tex</h5>
		<texture src="%101:0" style="width: 100px; height: 100px"/>
	</div>
	<div>
		<h5>Other Tex</h5>
		<texture src="%101:1" style="width: 100px; height: 100px"/>
	</div>
	<div>
		<h5>Heightmap</h5>
		<texture src="$heightmap" style="width: 100px; height: 100px"/>
	</div>
	<div>
		<h5>Named</h5>
		<texture src="luaui/images/backgroundtile.png" style="width: 100px; height: 100px"/>
	</div>
</div>
]]) .. createSection("Named Texture Modifiers (Non .dds Only)", [[
<div style="display: flex; flex-direction: row;">
	<div>
		<h5>Normal</h5>
		<texture src="bitmaps/logo.png"/>
	</div>
	<div>
		<h5>Inverted</h5>
		<texture src=":i:bitmaps/logo.png"/>
	</div>
	<div>
		<h5>Tint</h5>
		<texture src=":t0.7,1,0.7:bitmaps/logo.png"/>
	</div>
</div>
<div style="display: flex; flex-direction: row;">
	<div>
		<h5>Resize</h5>
		<texture src=":r256,128:bitmaps/logo.png"/>
	</div>
	<div>
		<h5>Nearest Scaling</h5>
		<texture src=":n:bitmaps/logo.png" style="width: 128px; height: 128px"/>
	</div>
	<div>
		<h5>Linear Scaling</h5>
		<texture src=":l:bitmaps/logo.png" style="width: 128px; height: 128px"/>
	</div>
	<div>
		<h5>Anisotropic Filter</h5>
		<texture src=":a:bitmaps/logo.png" style="width: 128px; height: 128px"/>
	</div>
</div>
]]))
	
	tabset.active_tab = -1
	tabset.active_tab = 0
	RmlUi.SetDebugContext(widget.rmlContext)
end

function widget:Shutdown()
	RmlUi.SetDebugContext(nil)

	if document then
		document:Close()
	end
	if widget.rmlContext then
		RmlUi.RemoveContext(widget.whInfo.name)
	end
end