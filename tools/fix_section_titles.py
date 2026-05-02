import re, shutil, sys

path = r'luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.rml'
shutil.copy(path, path + '.bak2')

with open(path, encoding='utf-8') as f:
    content = f.read()

c0 = content.count('text-base text-keybind')

# 1. Replace title divs with style margin-right (DISPLAY/INSTRUMENTS/CONTROLS)
content = content.replace(
    'class="text-base text-keybind" style="margin-right: 2dp;">',
    'class="tf-collapsible-title">'
)
c1 = content.count('text-base text-keybind')

# 2. Replace remaining title divs that follow tf-icon-sm images (FILTERS/CONTROLS/COLOR)
content = re.sub(
    r'(<img[^>]*class="tf-icon-sm"[^>]*/>\s*\n\s*)<div class="text-base text-keybind">',
    r'\1<div class="tf-collapsible-title">',
    content
)
c2 = content.count('text-base text-keybind')
print(f'start: {c0}, after margin-right fix: {c1}, after img-preceding fix: {c2}')

# 3. Wrap cl-undo in frame
old = '\t\t\t<!-- Undo & Redo -->\n\t\t\t<div id="btn-toggle-cl-undo" class="flex flex-row items-center mb-0-5" style="cursor: pointer;">'
new = '\t\t\t<!-- Undo & Redo -->\n\t\t\t<div class="tf-section-frame" id="frame-cl-undo">\n\t\t\t<div id="btn-toggle-cl-undo" class="tf-section-title-row" style="cursor: pointer;">'
cnt = content.count(old)
if cnt != 1:
    print(f'ERROR: cl-undo open found {cnt} times')
    sys.exit(1)
content = content.replace(old, new)

old = '\t\t\t</div><!-- /section-cl-undo -->\n\n\n\t\t\t<!-- Paste transform controls -->'
new = '\t\t\t</div><!-- /section-cl-undo -->\n\t\t\t</div><!-- /frame-cl-undo -->\n\n\n\t\t\t<!-- Paste transform controls -->'
cnt = content.count(old)
if cnt != 1:
    print(f'ERROR: cl-undo close found {cnt} times')
    sys.exit(1)
content = content.replace(old, new)

# 4. Wrap cl-paste in frame
old = '\t\t\t<div id="cl-paste-transforms" data-if="clonePasteTransformsVisible">\n\t\t\t\t<div id="btn-toggle-cl-paste" class="flex flex-row items-center mb-0-5" style="cursor: pointer;">'
new = '\t\t\t<div id="cl-paste-transforms" data-if="clonePasteTransformsVisible">\n\t\t\t<div class="tf-section-frame" id="frame-cl-paste">\n\t\t\t\t<div id="btn-toggle-cl-paste" class="tf-section-title-row" style="cursor: pointer;">'
cnt = content.count(old)
if cnt != 1:
    print(f'ERROR: cl-paste open found {cnt} times')
    sys.exit(1)
content = content.replace(old, new)

old = '\t\t\t\t</div><!-- /section-cl-paste -->\n\t\t\t</div>\n\n\t\t</div><!-- /section-cl-controls -->'
new = '\t\t\t\t</div><!-- /section-cl-paste -->\n\t\t\t</div><!-- /frame-cl-paste -->\n\t\t\t</div>\n\n\t\t</div><!-- /section-cl-controls -->'
cnt = content.count(old)
if cnt != 1:
    print(f'ERROR: cl-paste close found {cnt} times')
    sys.exit(1)
content = content.replace(old, new)

# 5. Wrap cl-quality in frame
old = '\t\t\t\t<!-- Terrain quality -->\n\t\t\t\t<div id="btn-toggle-cl-quality" class="flex flex-row items-center mb-0-5" style="cursor: pointer;">'
new = '\t\t\t\t<div class="tf-section-frame" id="frame-cl-quality">\n\t\t\t\t<div id="btn-toggle-cl-quality" class="tf-section-title-row" style="cursor: pointer;">'
cnt = content.count(old)
if cnt != 1:
    print(f'ERROR: cl-quality open found {cnt} times')
    sys.exit(1)
content = content.replace(old, new)

old = '\t\t\t\t</div><!-- /section-cl-quality -->\n\n\t\t\t\t<!-- Rotation -->'
new = '\t\t\t\t</div><!-- /section-cl-quality -->\n\t\t\t\t</div><!-- /frame-cl-quality -->\n\n\t\t\t\t<!-- Rotation -->'
cnt = content.count(old)
if cnt != 1:
    print(f'ERROR: cl-quality close found {cnt} times')
    sys.exit(1)
content = content.replace(old, new)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Done. Remaining text-base text-keybind:', content.count('text-base text-keybind'))
print('cl-paste frame wrappers:', content.count('frame-cl-paste'))
print('cl-quality frame wrappers:', content.count('frame-cl-quality'))
print('cl-undo frame wrappers:', content.count('frame-cl-undo'))
