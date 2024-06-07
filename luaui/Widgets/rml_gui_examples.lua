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

	local textareas = tabset:QuerySelectorAll('panel:last-child > textarea')
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
	rml_result = rml_result .. '<textarea class="example-code" value="' .. escaped_content .. '">'
	rml_result = rml_result .. '</textarea>\n'	
	return rml_result
end

function widget:Initialize()
	widget.rmlContext = RmlUi.GetContext(widget.whInfo.name)
	if not widget.rmlContext then
		widget.rmlContext = RmlUi.CreateContext(widget.whInfo.name)
	end

	widget.rmlContext:RemoveDataModel("data_model_test")
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
	tabset:QuerySelector('tabs'):SetClass('container', true)
	tabset:QuerySelector('panels'):SetClass('container', true)

	createBasicElementsPage()
	createLayoutElementsPage()
	createMediaElementsPage()
	createInputElementsPage()
	createBasicStylesPage()

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

function widget:OnReloadClick()
	widget.rmlContext = nil
	widgetHandler:DisableWidget(widget:GetInfo().name)
	widgetHandler:EnableWidget(widget:GetInfo().name)
end

------------------------
---- BASIC ELEMENTS ----
------------------------
function createBasicElementsPage()

	local layoutSection = createSection('Basic Layout', [[
<div>div</div>
Horizontal Rule<hr/>
<p>paragraph</p>
<span>span</span>
<div class="container">styled 'container' element using a class</div>
]])

	local textDecorationSection = createSection('Text Decoration', [[
<b>Bold </b> <strong>Strong</strong><br/>
<i>Italic </i> <em>Emphasis</em><br/>
<u>Underline</u><br/>
<s>Strikethrough</s><br/>
<code>code</code><br/>
<pre>
Preformatted
       text
</pre>
]])

	local headingsSection = createSection('Headings', [[
<div style="display: flex; flex-direction: row; align-items: flex-end;">
	<h1>h1</h1>
	<h2>h2</h2>
	<h3>h3</h3>
	<h4>h4</h4>
	<h5>h5</h5>
	<h6>h6</h6>
</div>
]])
	addPage(
		'Basic .rml Elements',
		layoutSection ..
			textDecorationSection ..
			headingsSection
	)
end

-------------------------
---- LAYOUT ELEMENTS ----
-------------------------
function createLayoutElementsPage()

	local listsSection = createSection('Lists', [[
<ol>
	<li>1. ordered lists</li>
	<li>2. and</li>
	<li>3. unordered lists</li>
</ol>
<ul>
	<li>• both no not have inherent</li>
	<li>• bullet points/numbering</li>
	<li>• due to RmlUi limitations</li>
</ul>
]])

	local tableSection = createSection('Table', [[
<table style="border: 1dp white; gap: 0.5em;">
	<colgroup>
		<col style="background-color: maroon;"/>
		<col style="background-color: gray;"/>
		<col style="background-color: #060;"/>
	</colgroup>
	<thead style="background-color: black; color: white;">
		<tr>
			<th colspan="2" style="text-align: center;">th colspan 2</th>
			<th>th</th>
		</tr>
	</thead>
	<tbody>
		<tr>
			<td rowspan="2" style="position: relative; vertical-align: center;">
				<div style="display: flex; align-items: center; justify-content: center; height: 58dp;">
					<span>td rowspan 2</span>
				</div>
			</td>
			<td>data</td>
			<td>data</td>
		</tr>
		<tr>
			<td>data</td>
			<td>data</td>
		</tr>
	</tbody>
	<tfoot style="background-color: black; color: white;">
		<tr>
			<td>td</td>
			<td>td</td>
			<td>td</td>
		</tr>
	</tfoot>
</table>
]])

	local flexBoxSection = createSection('Flex Box', [[
<div style="display: flex; flex-direction: row;">
	<div>div</div>
	<div>div</div>
	<div>div</div>
</div>
]])

	local nestedFlexBoxSection = createSection('Nested Flex Box', [[
<div style="display: flex; flex-direction: column;">
	<div style="display: flex; flex-direction: row;">
		<div>div</div>
		<div>div</div>
		<div>div</div>
	</div>
	<div style="display: flex; flex-direction: row; justify-content: space-between;">
		<div>div</div>
		<div>div</div>
		<div>div</div>
	</div>
	<div style="display: flex; flex-direction: row; justify-content: flex-end;">
		<div>div</div>
		<div>div</div>
		<div>div</div>
	</div>
</div>
]])

	addPage(
		'Layout .rml Elements',
		listsSection ..
			tableSection ..
			flexBoxSection ..
			nestedFlexBoxSection
	)
end

------------------------
---- MEDIA ELEMENTS ----
------------------------
function createMediaElementsPage()
	local imagesSection = createSection('Images (Relative Paths)', [[
<div style="max-width: 100%">
	<img src="/bitmaps/loadpictures/armada.jpg" style="width: 50%;"/>
	<img src="/bitmaps/loadpictures/cortex.jpg" style="width: 50%;"/>
</div>
]])

	local imageTextureExamplesSection = createSection('Image Texture Examples (Custom Element, Absolute Paths, Tints)', [[
<div style="max-width: 100%">
	<texture src=":t0,1,1:bitmaps/loadpictures/armada.jpg" style="width: 50%;"/>
	<texture src=":t1,0,1:bitmaps/loadpictures/cortex.jpg" style="width: 50%;"/>
</div>
]])

	local textureTypesSection = createSection('Texture Types', [[
<div style="display: flex; flex-direction: row;">
	<div>
		<h5>Build Picture</h5>
		<texture src="#101" style="width: 100dp; height: 100dp"/>
	</div>
	<div>
		<h5>Radar Icon</h5>
		<texture src="^101" style="width: 100dp; height: 100dp"/>
	</div>
	<div>
		<h5>Color Tex</h5>
		<texture src="%101:0" style="width: 100dp; height: 100dp"/>
	</div>
	<div>
		<h5>Other Tex</h5>
		<texture src="%101:1" style="width: 100dp; height: 100dp"/>
	</div>
	<div>
		<h5>Heightmap</h5>
		<texture src="$heightmap" style="width: 100dp; height: 100dp"/>
	</div>
	<div>
		<h5>Named</h5>
		<texture src="luaui/images/backgroundtile.png" style="width: 100dp; height: 100dp"/>
	</div>
</div>
]])

	local namedTextureModifiersSection = createSection("Named Texture Modifiers (Non .dds Only)", [[
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
		<texture src=":n:bitmaps/logo.png" style="width: 128dp; height: 128dp"/>
	</div>
	<div>
		<h5>Linear Scaling</h5>
		<texture src=":l:bitmaps/logo.png" style="width: 128dp; height: 128dp"/>
	</div>
	<div>
		<h5>Anisotropic Filter</h5>
		<texture src=":a:bitmaps/logo.png" style="width: 128dp; height: 128dp"/>
	</div>
</div>
]])

	addPage(
		'Media .rml Elements',
		imagesSection ..
			imageTextureExamplesSection ..
			textureTypesSection ..
			namedTextureModifiersSection
	)
end

------------------------
---- INPUT ELEMENTS ----
------------------------
--[[
<input>

Attributes

type = cdata (CI)
    The type of the input field. Must be one of:

        text - A one-line text-entry field.
        password - Like text, but replaces the entered text with asterisks.
        radio - A radio button.
        checkbox - A checkbox.
        range - A slider bar.
        button - A button.
        submit - A button for submitting the form.

Text and Password types

size = number (CN)
    For types of text and password, defines the length (in characters) of the element.
maxlength = number (CN)
    For types of text and password, defines the maximum length (in characters) that the element will accept.

Radio and Checkbox types

checked (CI)
    For types of radio and checkbox, if this attribute is set then the element is “on”.

Range type

min = number (CN)
    For the range type, defines the value at the lowest (left or top) end of the slider.
max = number (CN)
    For the range type, defines the value at the highest (right or bottom) end of the slider.
step = number (CN)
    For the range type, defines the increment that the slider will move by.
orientation = cdata (CI)
    For the range type, specifies if it is a vertical or horizontal slider. Values can be horizontal or vertical. 
]]
function createInputElementsPage()
	local inputSection = createSection('Input Types', [[
<form>
	<div>
		<label>
			<h4>Text Input</h4>
			<input type="text" value="Text"/>
		</label>
		<label>
			<h4>Text Input with maxlength = 10</h4>
			<input type="text" size="6.5" maxlength="10" value="1234567890"/>
		</label>
		<label>
			<h4>Password Input</h4>
			<input type="password" value="password"/>
		</label>
		<h4>Radio Buttons</h4>
		<div style="display: flex; flex-direction: row;">
			<label><input type="radio" name="radio" value="1"/>1</label>
			<label><input type="radio" name="radio" value="2"/>2</label>
			<label><input type="radio" name="radio" value="3"/>3</label>
		</div>
		<h4>Checkboxes</h4>
		<div style="display: flex; flex-direction: row;">
			<label><input type="checkbox" name="checkbox" value="1"/>1</label>
			<label><input type="checkbox" name="checkbox" value="2"/>2</label>
			<label><input type="checkbox" name="checkbox" value="3"/>3</label>
		</div>
		<label>
			<h4>Range Input</h4>
			<input type="range" min="0" max="100" step="1"/>
		</label>
		<h4>Button and Submit</h4>
		<input type="button" value="button">Button</input>
		<input type="submit" value="submit">Submit</input>
	</div>
</form>
]])

	local textareaSection = createSection('Textarea', [[
<textarea placeholder="textarea"></textarea>
]])

	local selectSection = createSection('Select', [[
<select>
	<option value="1">Option 1</option>
	<option value="2">Option 2</option>
	<option value="3">Option 3</option>
</select>
]])

	addPage(
		'Input .rml Elements',
		inputSection ..
			textareaSection ..
			selectSection
	)
end

-----------------------
---- BASIC STYLING ----
-----------------------
function createBasicStylesPage()
	local boxModelSection = createSection('Box Model Properties', [[
		<div class="container" style="display: flex; flex-direction: row; align-items: center;">
			<div style="width: 100dp; height: 100dp; border: 1dp white; background-color: #444">Sized</div>
			<div style="border: 1dp white; margin: 10dp; background-color: #444">Margin</div>
			<div style="border: 1dp white; padding: 10dp; background-color: #444">Padding</div>
			<div style="border: 1dp white; border-radius: 10dp; background-color: #444">Border Radius</div>
		</div>
	]])

	local shadowPropertiesSection = createSection('Box Shadow Property', [[
		<div class="container" style="display: flex; flex-direction: row; padding: 50dp 8dp; background-color: white;">
			<div style="width: 100dp; height: 100dp; border: 1dp white; background-color: #555; 
				box-shadow: 10dp 10dp 6dp 10dp black; filter: opacity(1);"
			>
				Box Shadow
			</div>
			<div style="width: 100dp; height: 100dp; border: 1dp white; background-color: #555;
				box-shadow:
					#f66 30dp 30dp 0 0,
					#c88 60dp 60dp 0 0,
					#baa 90dp 90dp 0 0,
					#ffac 0 0 .8em 8dp inset;
				margin-bottom: 100dp;
				filter: opacity(1);"
			>
				Multiple Box Shadows
			</div>
			<div style="width: 100dp; height: 100dp; border: 1dp white; background-color: #555;
				box-shadow:
					#f00f  40dp  30dp 25dp 0dp,
					#00ff -40dp -30dp 45dp 0dp,
					#0f08 -60dp  70dp 60dp 0dp,
					#333a  0dp  0dp 30dp 15dp inset;
				margin-top: 100dp;
				margin-left: 100dp;
				margin-bottom: 100dp;"
			>
				Blurry Box Shadows
			</div>
		</div>
	]])

	local textPropertiesSection = createSection('Text Properties', [[
		<div class="container" style="display: flex; flex-direction: row; align-items: center;">
			<div style="width: 100dp; height: 100dp; border: 1dp white; font-size: 24dp; font-weight: bold; color: white; background-color: #444">Font Size & Weight</div>
			<div style="width: 100dp; height: 100dp; border: 1dp white; line-height: 2; background-color: #444">Line Height</div>
			<div style="width: 100dp; height: 100dp; border: 1dp white; text-align: center; background-color: #444">Text Align</div>
			<div style="width: 100dp; height: 100dp; border: 1dp white; text-decoration: underline; background-color: #444">Text Decoration</div>
		</div>
	]])

	local fontEffectsSection = createSection('Font Effects (RmlUi Property)', [[
		<div class="container" style="display: flex; flex-direction: row; align-items: center; background-color: gray;">
			<div style="padding: 4dp; font-effect: outline(2dp black)">Outline</div>
			<div style="padding: 4dp; font-effect: shadow(2dp 2dp black)">Shadow</div>
			<div style="padding: 4dp; font-effect: blur(3dp #ed5)">Blur</div>
			<div style="padding: 4dp; color: transparent; font-effect: blur(3dp #ed5)">Blur<br/>(seethru font)</div>
			<div style="font-size: 2em; padding: 4dp; color: #AAA; font-effect: glow( 3dp 1dp #ee9 );">Glow</div>
			<div style="padding: 4dp; color: #ed5; font-effect: glow(2dp 4dp 2dp 3dp #644)">Glow (Offset)</div>
			<div style="padding: 4dp; font-effect: outline(2dp black), glow(2dp 4dp 2dp 3dp #644);">Outline + Glow</div>
		</div>
	]])

	addPage(
		'Basic .rcss Styling',
		boxModelSection ..
			shadowPropertiesSection ..
			textPropertiesSection ..
			fontEffectsSection
	)
end
