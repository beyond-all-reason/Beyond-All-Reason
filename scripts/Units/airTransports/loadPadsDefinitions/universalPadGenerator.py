#!/usr/bin/env python3
"""
Generate universalPad.s3o and universalPadDefs.lua.
Logic ported from loadpadGenerator.lua.

Grid:  9×9, 1-based indices 1..9, center = 5
Beam positions: x = (col - 5) * SPACING,  z = (row - 5) * SPACING
NBEAMS == TRANSPORTERSIZE for every size 1-16.
"""
import struct, os, math


# ── S3O constants ──────────────────────────────────────────────────────────────
MAGIC       = b"Spring unit\0"
HEADER_SIZE = 52
PIECE_SIZE  = 52
SPACING     = 16      # elmos between adjacent grid positions
BEAM_Y      = 0.0
LINK_Y      = -10.0

# ── Grid constants (match loadpadGenerator.lua) ───────────────────────────────
MAX_SIZE    = 16
GRID_SIZE   = MAX_SIZE // 2 + 1     # 9  (1-based positions 1..9)
GRID_CENTER = (GRID_SIZE - 1) / 2 + 1   # 5.0

RECT_SIZES = [1, 2, 4, 8, 16, 32, 64]

RECT_DEFS = {
    1:  [[1]],
    2:  [[1, 0, 1], [2]],
    4:  [[2, 0, 2]],
    8:  [[2, 0, 2, 0, 2, 0, 2], [4, 0, 4]],
    16: [[4, 0, 4, 0, 4, 0, 4]],
    32: [[8, 0, 8, 0, 8, 0, 8],
         [4, 0, 4, 0, 4, 0, 4, 0, 4, 0, 4, 0, 4, 0, 4]],
    64: [[8, 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0, 8, 0, 8]],
}

# (slot_size, num_cols, num_rows)  – both dims step by 2 in the grid
LINK_SHAPES = [
    (1,  1, 1),
    (2,  1, 2),
    (2,  2, 1),
    (4,  2, 2),
    (8,  2, 4),
    (8,  4, 2),
    (16, 4, 4),
]


# ── Column-distribution logic (exact 1-based port of Lua doSize) ─────────────

def _arr1():
    """1-based array of zeros, indices 1..GRID_SIZE (index 0 unused)."""
    return [0] * (GRID_SIZE + 1)


def do_size(size):
    """Exact port of Lua doSize(size). Returns {arr, length, width} or None.
    arr is 1-based (index 0 unused), arr[col] = beam depth in that column."""

    def Decompose(inputSize):
        maxRectSize = 0
        for s in RECT_SIZES:
            if inputSize >= s:
                maxRectSize = s
        return maxRectSize, inputSize - maxRectSize

    def StackRectangles(inputSize):
        allRects = []
        excess = inputSize
        while excess > 0:
            r, excess = Decompose(excess)
            allRects.append(r)
        return allRects

    rectangles = StackRectangles(size)

    def CreateAllArrangements(rectSize):
        arrangements = []
        for defsArr in RECT_DEFS[rectSize]:
            n = len(defsArr)
            # Lua: for offset = 0, (gridSize - #defsArr)
            for offset in range(GRID_SIZE - n + 1):
                newArr = _arr1()
                for localindex in range(1, GRID_SIZE + 1):
                    lua_j = localindex - offset   # 1-based index into pattern
                    if 1 <= lua_j <= n:
                        newArr[localindex] = defsArr[lua_j - 1]
                arrangements.append(newArr)
        return arrangements

    rectArrangements = {s: CreateAllArrangements(s) for s in RECT_SIZES}

    AllArrangements = []

    def Generate(rectIndex, current):
        if rectIndex >= len(rectangles):
            AllArrangements.append(current)
            return
        for candidate in rectArrangements[rectangles[rectIndex]]:
            merged = _arr1()
            for row in range(1, GRID_SIZE + 1):
                merged[row] = current[row] + candidate[row]
            Generate(rectIndex + 1, merged)

    Generate(0, _arr1())

    def filterOutSize(arrangements):
        result = []
        for arr in arrangements:
            lengthEven = 0; widthEven = 0
            lengthOdd  = 0; widthOdd  = 0
            # Lua: for row = 2, gridSize-1, 2  → even 1-based: 2,4,6,8
            for row in range(2, GRID_SIZE, 2):
                if arr[row] > 0:   lengthEven += 1
                if arr[row] > widthEven: widthEven = arr[row]
            # Lua: for row = 1, gridSize, 2   → odd 1-based: 1,3,5,7,9
            for row in range(1, GRID_SIZE + 1, 2):
                if arr[row] > 0:   lengthOdd += 1
                if arr[row] > widthOdd:  widthOdd = arr[row]
            length = max(lengthOdd, lengthEven)
            width  = widthOdd + widthEven
            if length <= GRID_CENTER and width <= GRID_CENTER:
                result.append({'arr': arr, 'length': length, 'width': width})
        return result

    filtered = filterOutSize(AllArrangements)

    def filterOutAsymmetry(inputTab):
        gc = int(math.floor(GRID_CENTER))   # 5
        symTab = []
        for item in inputTab:
            arr = item['arr']
            symmetric = True
            # Lua: for offset = 0, math.floor(gridCenter)-1  → 0..4
            for offset in range(gc):
                if arr[gc - offset] != arr[gc + offset]:
                    symmetric = False
                    break
            if symmetric:
                symTab.append(item)
        return symTab

    symmetric = filterOutAsymmetry(filtered)

    def _sort_key(a):
        sq = abs(a['length'] - a['width'])
        return (sq, a['length'], a['width'])

    symmetric.sort(key=_sort_key)
    return symmetric[0] if symmetric else None


# ── Beam placement (exact 1-based port of Lua GenerateBeams) ──────────────────

def GenerateBeams(tab):
    """Exact port of Lua GenerateBeams(inputTab).
    Returns compose[col][row] = 0|1, both 1-based (1..GRID_SIZE)."""
    if not tab:
        return {}

    arr    = tab['arr']
    width  = tab['width']

    oddComponent  = _arr1()
    pairComponent = _arr1()
    oddCompSize   = 0
    pairCompSize  = 0

    for i in range(1, GRID_SIZE + 1):
        val = arr[i]
        if i % 2 == 1:   # odd 1-based index
            oddComponent[i]   = val
            oddCompSize      += val
        else:             # even 1-based index
            pairComponent[i]  = val
            pairCompSize     += val

    if pairCompSize < oddCompSize:
        frontRows, backRows = pairComponent, oddComponent
    else:
        frontRows, backRows = oddComponent, pairComponent

    # Lua: rowStart = math.floor(gridCenter - width/2) + 1
    rowStart = int(GRID_CENTER + 1 - width )
    rowEnd   = GRID_SIZE - rowStart + 1

    compose = {col: {} for col in range(1, GRID_SIZE + 1)}

    # Lua: for row = rowStart, gridSize-rowStart+1, 2
    for col in range(1, GRID_SIZE + 1):
        toPlace = frontRows[col]
        placed, row = 0, rowStart
        while row <= rowEnd and placed < toPlace:
            compose[col][row] = 1
            placed += 1
            row    += 2

    # Lua: for row = gridSize-rowStart+1, rowStart, -2
    for col in range(1, GRID_SIZE + 1):
        toPlace = backRows[col]
        placed, row = 0, rowEnd
        while row >= rowStart and placed < toPlace:
            compose[col][row] = 1
            placed += 1
            row    -= 2

    # Fill zeros
    for col in range(1, GRID_SIZE + 1):
        for row in range(1, GRID_SIZE + 1):
            compose[col].setdefault(row, 0)

    return compose




def beam_name(col, row):
    return f'beam_{col}_{row}'


def _xz(col, row):
    return float((col - GRID_CENTER) * SPACING), float(-(row - GRID_CENTER) * SPACING)


# ── Build global beam list and per-size active sets ───────────────────────────

def build_beams():
    tabs      = {size: do_size(size) for size in range(1, MAX_SIZE + 1)}
    active    = {}
    all_beams = {}
    footprints = {}

    for size in range(1, MAX_SIZE + 1):
        compose = GenerateBeams(tabs[size])
        active[size] = set()
        for col in range(1, GRID_SIZE + 1):
            for row in range(1, GRID_SIZE + 1):
                if compose.get(col, {}).get(row, 0) == 1:
                    name = beam_name(col, row)
                    active[size].add(name)
                    if name not in all_beams:
                        x, z = _xz(col, row)
                        all_beams[name] = {'name': name, 'col': col, 'row': row,
                                           'x': x, 'y': BEAM_Y, 'z': z}

        # Footprint: bounding box of active beams + 1 grid step margin on each side
        if active[size]:
            cols = [all_beams[n]['col'] for n in active[size]]
            rows = [all_beams[n]['row'] for n in active[size]]
            min_c, max_c = min(cols), max(cols)
            min_r, max_r = min(rows), max(rows)
            w_elmos = (max_c - min_c + 2) * SPACING
            h_elmos = (max_r - min_r + 2) * SPACING
            footprints[size] = {
                'min_col': min_c, 'max_col': max_c,
                'min_row': min_r, 'max_row': max_r,
                'width_elmos':  w_elmos,
                'height_elmos': h_elmos,
            }
        else:
            footprints[size] = None

        n = len(active[size])
        assert n == size, f"size{size}: expected {size} beams, got {n}"

    return all_beams, active, tabs, footprints


# ── Link generation (port of Lua GenerateLinks) ───────────────────────────────

def generate_links_for_size(size_active):
    """Return list of link dicts for one size, deduplicated by covered-beam set."""
    links = []
    seen  = set()
    for slot_size, num_cols, num_rows in LINK_SHAPES:
        max_sc = GRID_SIZE - (num_cols - 1) * 2
        max_sr = GRID_SIZE - (num_rows - 1) * 2
        for sc in range(1, max_sc + 1):
            for sr in range(1, max_sr + 1):
                covered = []
                valid   = True
                for dc in range(num_cols):
                    for dr in range(num_rows):
                        bn = beam_name(sc + dc * 2, sr + dr * 2)
                        if bn not in size_active:
                            valid = False
                            break
                        covered.append(bn)
                    if not valid:
                        break
                if valid:
                    key = tuple(sorted(covered))
                    if key not in seen:
                        seen.add(key)
                        centroid_col = sc + (num_cols - 1)
                        centroid_row = sr + (num_rows - 1)
                        cx, cz = _xz(centroid_col, centroid_row)
                        name = f'{slot_size}_link_{sc}_{sr}_{num_cols}x{num_rows}'
                        links.append({
                            'name':     name,
                            'size':     slot_size,
                            'beams':    covered,
                            'col':      sc,
                            'row':      sr,
                            'num_cols': num_cols,
                            'num_rows': num_rows,
                            'x':        cx,
                            'y':        LINK_Y,
                            'z':        cz,
                        })
    return links


def build_links(active):
    """
    Returns:
      all_links      : dict  name → link dict  (union across all sizes)
      links_per_size : dict  size → list of links
    """
    all_links      = {}
    links_per_size = {}
    for size in range(1, MAX_SIZE + 1):
        ls = generate_links_for_size(active[size])
        links_per_size[size] = ls
        for l in ls:
            all_links[l['name']] = l
    return all_links, links_per_size


# ── Pad defs (port of Lua GeneratePadDefs) ────────────────────────────────────

def _pick_non_overlapping(links, n):
    """Greedily pick up to n mutually non-overlapping links (by beam set)."""
    selected, rest = [], []
    used = set()
    for l in links:
        if len(selected) < n and not (set(l['beams']) & used):
            selected.append(l)
            used.update(l['beams'])
        else:
            rest.append(l)
    return selected, rest


def build_pad_defs(links_per_size):
    """
    Returns dict  size → {links: [...sorted...], requires: {name: [...]}}
    Sorted: largest slot first, preferred non-overlapping first within each slot size.
    """
    pad_defs = {}
    for size in range(1, MAX_SIZE + 1):
        links = links_per_size[size]

        groups = {}
        for l in links:
            groups.setdefault(l['size'], []).append(l)

        ordered = []
        for slot_size in sorted(groups, reverse=True):
            group = sorted(groups[slot_size], key=lambda l: l['name'])
            n = size // slot_size
            selected, rest = _pick_non_overlapping(group, n)
            ordered.extend(selected)
            ordered.extend(rest)

        beam_sets = {l['name']: set(l['beams']) for l in ordered}
        requires  = {}
        for la in ordered:
            req = sorted(
                [lb['name'] for lb in ordered
                 if lb['name'] != la['name'] and beam_sets[lb['name']] & beam_sets[la['name']]],
                key=lambda n: n
            )
            requires[la['name']] = req

        pad_defs[size] = {'links': ordered, 'requires': requires}
    return pad_defs


# ── S3O writer ────────────────────────────────────────────────────────────────

def _pack_piece(name_off, num_children, children_off, x, y, z):
    return struct.pack('<10I3f',
        name_off, num_children, children_off,
        0, 0, 0, 0, 0, 0, 0,
        x, y, z)


def generate_s3o(all_beams, all_links, output_path):
    beams    = list(all_beams.values())
    links    = list(all_links.values())
    children = beams + links
    N = len(children)

    root_piece_offset    = HEADER_SIZE
    root_children_offset = root_piece_offset + PIECE_SIZE
    first_child_offset   = root_children_offset + N * 4
    string_table_offset  = first_child_offset + N * PIECE_SIZE

    string_table   = bytearray()
    string_offsets = {}

    def intern(s):
        if s not in string_offsets:
            string_offsets[s] = string_table_offset + len(string_table)
            string_table.extend((s + '\0').encode('ascii'))
        return string_offsets[s]

    tex_off       = intern('')
    root_name_off = intern('base')
    child_offs    = [intern(c['name']) for c in children]

    radius = 4 * SPACING * math.sqrt(2)

    out  = bytearray()
    out += MAGIC
    out += struct.pack('<I',   0)
    out += struct.pack('<f',   radius)
    out += struct.pack('<f',   0.0)
    out += struct.pack('<fff', 0.0, 0.0, 0.0)
    out += struct.pack('<I',   root_piece_offset)
    out += struct.pack('<I',   0)
    out += struct.pack('<II',  tex_off, tex_off)
    assert len(out) == HEADER_SIZE

    out += _pack_piece(root_name_off, N, root_children_offset, 0.0, 0.0, 0.0)
    for i in range(N):
        out += struct.pack('<I', first_child_offset + i * PIECE_SIZE)
    assert len(out) == first_child_offset

    for i, child in enumerate(children):
        out += _pack_piece(child_offs[i], 0, 0, child['x'], child['y'], child['z'])
    assert len(out) == string_table_offset

    out += string_table

    with open(output_path, 'wb') as f:
        f.write(out)

    print(f"Written:  {output_path}  ({len(out)} bytes)")
    print(f"Pieces:   1 root + {len(beams)} beams + {len(links)} links = {1 + N} total")


# ── Lua defs writer ───────────────────────────────────────────────────────────

def generate_lua_defs(pad_defs, footprints, output_path):
    lines = ['local loadPads = {']

    for size in range(1, MAX_SIZE + 1):
        defs    = pad_defs[size]
        links   = defs['links']
        requires = defs['requires']
        fp      = footprints[size]

        lines.append(f'    size{size} = {{')
        lines.append(f'        cargo = {{')
        if fp:
            lines.append(f'            footprint = {{ width = {fp["width_elmos"]}, height = {fp["height_elmos"]} }},')
        lines.append(f'            slots = {{')
        for l in links:
            req = requires[l['name']]
            if req:
                req_lua = '{ ' + ', '.join(f'"{n}"' for n in req) + ' }'
            else:
                req_lua = '{}'
            lines.append(
                f'                {{ name = "{l["name"]}", size = {l["size"]}, requires = {req_lua} }},')
        lines.append(f'            }},')
        lines.append(f'        }},')
        lines.append(f'        loadMethod = {{')
        lines.append(f'            beams = {{')
        for l in links:
            beams_str = ', '.join(f'"{b}"' for b in l['beams'])
            lines.append(f'                ["{l["name"]}"] = {{ {beams_str} }},')
        lines.append(f'            }},')
        lines.append(f'        }},')
        lines.append(f'    }},')
        lines.append('')

    lines.append('}')
    lines.append('return loadPads')

    with open(output_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')

    total = sum(len(pad_defs[s]['links']) for s in range(1, MAX_SIZE + 1))
    print(f"Written:  {output_path}")
    print(f"Sizes:    1–{MAX_SIZE}  ({total} total slots across all sizes)")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    base = os.path.dirname(os.path.abspath(__file__))

    all_beams, active, tabs, footprints = build_beams()

    print("Beam layout per size:")
    for size in range(1, MAX_SIZE + 1):
        tab = tabs[size]
        fp  = footprints[size]
        fp_str = (f"{fp['width_elmos']}x{fp['height_elmos']} elmos"
                  f"  (col {fp['min_col']}–{fp['max_col']}, row {fp['min_row']}–{fp['max_row']})"
                  if fp else "None")
        print(f"  size{size:2d}: {len(active[size]):2d} beams  footprint={fp_str}")

    print(f"\nBeam list ({len(all_beams)}):")
    for name in sorted(all_beams):
        b = all_beams[name]
        print(f"  {name:15s}  col={b['col']}  row={b['row']}  x={b['x']:6.0f}  z={b['z']:6.0f}")

    all_links, links_per_size = build_links(active)
    pad_defs = build_pad_defs(links_per_size)

    print(f"\nLink count per size:")
    for size in range(1, MAX_SIZE + 1):
        print(f"  size{size:2d}: {len(links_per_size[size])} links")

    s3o_path  = os.path.join(base, 'universalPad.s3o')
    defs_path = os.path.join(base, 'universalPadDefs.lua')

    generate_s3o(all_beams, all_links, s3o_path)
    generate_lua_defs(pad_defs, footprints, defs_path)


if __name__ == '__main__':
    main()

