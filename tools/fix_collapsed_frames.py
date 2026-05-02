import re, shutil

path = r'luaui/RmlWidgets/gui_terraform_brush/gui_terraform_brush.rml'
shutil.copy(path, path + '.bak3')

with open(path, encoding='utf-8') as f:
    content = f.read()

# Find all section divs that start with class="hidden" in the HTML
hidden_section_ids = set(re.findall(r'<div id="(section-[^"]+)" class="hidden"', content))
print(f'Found {len(hidden_section_ids)} hidden sections')

count = 0
already = 0
no_frame = []
for sid in sorted(hidden_section_ids):
    fid = sid.replace('section-', 'frame-', 1)
    old = f'class="tf-section-frame" id="{fid}"'
    new = f'class="tf-section-frame tf-collapsed" id="{fid}"'
    already_pat = f'class="tf-section-frame tf-collapsed" id="{fid}"'
    if already_pat in content:
        already += 1
    elif old in content:
        content = content.replace(old, new)
        count += 1
    else:
        no_frame.append(fid)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print(f'Added tf-collapsed to {count} frames, {already} already had it')
if no_frame:
    print(f'No matching frame found for: {no_frame}')
