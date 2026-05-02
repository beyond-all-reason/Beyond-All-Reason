"""
wrap_sections.py
Transforms gui_terraform_brush.rml:
  - Wraps each (btn-toggle-X / section-X) and (btn-env-toggle-X / env-section-X) pair
    in <div class="tf-section-frame" id="frame-X"> ... </div>
  - Changes the toggle button class to "tf-section-title-row" (preserving other attrs)
  - Removes <div class="divider-horizontal-dark"></div> that appear directly
    before a toggle button (or after a section body close)
"""

import re, sys

RML = r"C:\Games\Beyond-All-Reason\data\games\Beyond-All-Reason.sdd\luaui\RmlWidgets\gui_terraform_brush\gui_terraform_brush.rml"
OUT = RML  # overwrite in-place (script saves a .bak first)

DIVIDER_PAT = re.compile(r'^\s*<div\s+class="divider-horizontal-dark"></div>\s*$')
TOGGLE_PAT  = re.compile(r'^(\s*)<div\s+id="(btn-(?:env-)?toggle-([^"]+))"([^>]*)>\s*$')


def get_indent(line):
    return line[: len(line) - len(line.lstrip())]


def strip_class_attr(attrs):
    """Remove class="..." from an attribute string."""
    return re.sub(r'\s*class="[^"]*"', '', attrs).strip()


def frame_id_for_section(section_id):
    """
    section-terrain      -> frame-terrain
    env-section-skyrot   -> env-frame-skyrot
    """
    return re.sub(r'(?:^|(?<=-))(section)-', 'frame-', section_id, count=1)


def process(lines):
    out = []
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]

        # ── Toggle button? ──────────────────────────────────────────────────
        tm = TOGGLE_PAT.match(line)
        if tm:
            indent      = tm.group(1)          # leading whitespace of toggle
            btn_id      = tm.group(2)          # e.g. "btn-toggle-terrain"
            suffix      = tm.group(3)          # e.g. "terrain"
            extra_attrs = tm.group(4).strip()  # everything after id="..."

            if btn_id.startswith('btn-env-toggle-'):
                section_id = 'env-section-' + suffix
            else:
                section_id = 'section-' + suffix
            fid = frame_id_for_section(section_id)

            clean_attrs = strip_class_attr(extra_attrs)

            # ── Emit frame wrapper open ──────────────────────────────────────
            out.append(indent + f'<div class="tf-section-frame" id="{fid}">')

            # ── Emit title row (toggle button with new class) ────────────────
            inner_indent = indent + '\t'
            if clean_attrs:
                out.append(inner_indent + f'<div id="{btn_id}" class="tf-section-title-row" {clean_attrs}>')
            else:
                out.append(inner_indent + f'<div id="{btn_id}" class="tf-section-title-row">')

            # ── Copy toggle button body until its closing </div> ─────────────
            i += 1
            while i < n:
                inner = lines[i]
                inner_s = inner.strip()
                inner_ind = get_indent(inner)
                if inner_s.startswith('</div>') and inner_ind == indent:
                    # Closing </div> of the toggle button — re-indent inside frame
                    out.append(inner_indent + '</div>')
                    i += 1
                    break
                else:
                    # Re-indent: add one tab (since button is now inside frame)
                    out.append('\t' + inner)
                    i += 1

            # ── Skip blank lines / comments between toggle close & section ───
            while i < n and lines[i].strip() in ('', ):
                out.append(lines[i])
                i += 1

            # ── Must be at the section body div now ──────────────────────────
            if i >= n:
                break

            section_line = lines[i]
            section_indent = get_indent(section_line)
            out.append(section_line)
            i += 1

            # ── Copy section body, tracking div depth ────────────────────────
            depth = 1
            while i < n:
                sl = lines[i]
                ss = sl.strip()

                # Count div opens/closes on this line.
                # Self-closing <div ... /> must NOT count as opens.
                div_opens  = len(re.findall(r'<div\b', ss)) - len(re.findall(r'<div\b[^>]*/>', ss))
                div_closes = ss.count('</div>')
                depth += div_opens - div_closes

                out.append(sl)
                i += 1

                if depth <= 0:
                    # Section body closed — close the frame
                    out.append(indent + f'</div><!-- /frame-{suffix} -->')

                    # ── Skip trailing blank lines, then remove divider if next ──
                    while i < n and lines[i].strip() == '':
                        out.append(lines[i])
                        i += 1

                    if i < n and DIVIDER_PAT.match(lines[i]):
                        i += 1  # eat the divider
                    break

            continue  # don't fall through to the default append

        # ── Standalone divider that precedes a toggle button ─────────────────
        # (handles the case where divider comes BEFORE the frame, not after)
        if DIVIDER_PAT.match(line):
            # Peek ahead (skip blanks / comments) to see if next element is a toggle
            j = i + 1
            while j < n and lines[j].strip() in ('',):
                j += 1
            # Also skip a leading comment
            if j < n and lines[j].strip().startswith('<!--'):
                j += 1
                while j < n and lines[j].strip() in ('',):
                    j += 1
            if j < n and TOGGLE_PAT.match(lines[j]):
                i += 1          # skip the divider
                continue

        # ── Default: pass through unchanged ──────────────────────────────────
        out.append(line)
        i += 1

    return '\n'.join(out)


if __name__ == '__main__':
    with open(RML, 'r', encoding='utf-8') as f:
        content = f.read()

    # Save backup
    with open(RML + '.bak', 'w', encoding='utf-8') as f:
        f.write(content)

    lines = content.split('\n')
    result = process(lines)

    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        f.write(result)

    print(f"Done. Wrote {OUT}")
    print(f"Backup at {RML}.bak")
