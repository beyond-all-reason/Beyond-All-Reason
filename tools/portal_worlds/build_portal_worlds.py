#!/usr/bin/env python3
"""Compose native SMF maps from a manifest, preserving tiles, heights and resources.

AI assistance: OpenAI Codex authored this builder and its validation tools.
Source maps and their original authors are recorded in ATTRIBUTION.txt.
"""
from pathlib import Path
import argparse
import array
import copy
import hashlib
import io
import json
import math
import shutil
import struct
from PIL import Image
from map_sources import map_info, lua_data, write_lua
from portal_paths import ROOT, WORKSPACE, DEFAULT_GAME

FMT = '<16s7i2f7i'
TARGET = WORKSPACE / 'content/maps/portal_worlds_v3.sdd'
GAME_ROOT = None
CLASSIC_DETAIL = None


def dds_header(width, height):
    return struct.pack('<4s7I11I8I5I', b'DDS ', 124, 0x21007, height, width,
                       width * height // 2, 0, 1, *([0] * 11), 32, 4, 0x31545844,
                       0, 0, 0, 0, 0, 0x1000, 0, 0, 0, 0)


def read_tiles(source, raw, header):
    files, total = struct.unpack_from('<ii', raw, header[12])
    pos, payload = header[12] + 8, bytearray()
    for _ in range(files):
        count, = struct.unpack_from('<i', raw, pos)
        end = raw.index(0, pos + 4)
        name = raw[pos + 4:end].decode()
        smt = (source / 'maps' / name).read_bytes()
        assert struct.unpack_from('<i', smt, 20)[0] == count
        payload.extend(smt[32:32 + count * 680])
        pos = end + 1
    indices = struct.unpack_from(f'<{header[3] * header[4] // 16}i', raw, pos)
    assert len(payload) == total * 680
    return payload, total, indices


def ordered(table):
    return table if isinstance(table, list) else [table[k] for k in sorted(table, key=int)]


def source_spots(source, raw, h, info, name):
    for path in [source/'mapconfig/map_metal_layout.lua', GAME_ROOT/'LuaRules/Configs/MetalSpots'/f'{name}.lua']:
        if path.exists():
            data = lua_data(path, source)
            spots = data.get('spots') if isinstance(data, dict) else data
            if spots:
                return spots
    width, height = h[3] // 2, h[4] // 2
    metal = raw[h[14]:h[14] + width * height]
    remaining = {i for i, v in enumerate(metal) if v}
    spots, radius, scale = [], info.get('extractorradius', 100), info.get('maxmetal', 1)
    while remaining:
        queue, group = [min(remaining)], []
        remaining.remove(queue[0])
        while queue:
            i = queue.pop()
            group.append(i)
            x, z = i % width, i // width
            for dz in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    j = (z + dz) * width + x + dx
                    if 0 <= x + dx < width and 0 <= z + dz < height and j in remaining:
                        remaining.remove(j)
                        queue.append(j)
        total = sum(metal[i] for i in group)
        x = round(sum((i % width + .5) * metal[i] for i in group) / total) * 16
        z = round(sum((i // width + .5) * metal[i] for i in group) / total) * 16
        income = sum(metal[j*width+i] for j in range(max(0, int((z-radius)//16)), min(height, int((z+radius)//16)+1))
                     for i in range(max(0, int((x-radius)//16)), min(width, int((x+radius)//16)+1))
                     if ((i+.5)*16-x)**2 + ((j+.5)*16-z)**2 < radius**2) * scale * .001
        if income > .2:
            spots.append({'x': x, 'z': z, 'metal': round(income, 4)})
    return sorted(spots, key=lambda s: (s['z'], s['x']))


def merge_assets(source, target):
    for directory in ('features', 'objects3d', 'unittextures'):
        for path in (source / directory).rglob('*'):
            if path.is_file():
                out = target / path.relative_to(source)
                out.parent.mkdir(parents=True, exist_ok=True)
                if out.exists() and out.read_bytes() != path.read_bytes():
                    raise ValueError(f'Conflicting authored asset: {path}; namespace it before composition')
                shutil.copyfile(path, out)


def water_visuals(info):
    water = info.get('water', {})
    defaults = {'baseColor': [0,0,0], 'minColor': [0,0,0], 'absorb': [0,0,0], 'surfaceColor': [.5,.5,.5]}
    return {key: water.get(key.lower(), water.get('water'+key.lower(), value)) for key, value in defaults.items()}


def material(source, info, region, target, world_size, name):
    resources, lighting = info.get('resources', {}), info.get('lighting', {})
    prefix = f'maps/regions/{region["id"]}'
    dest = target / prefix
    dest.mkdir(parents=True, exist_ok=True)

    def asset(filename):
        path = source / filename
        if not path.exists():
            path = source / 'maps' / filename
        assert path.exists(), path
        out = dest / path.name
        shutil.copyfile(path, out)
        return prefix + '/' + path.name

    def positioned(filename, key, background):
        if not filename:
            Image.new('RGBA', (1, 1), background).save(dest / (key + '.png'))
        else:
            path = source / 'maps' / filename
            if not path.exists():
                path = source / filename
            image = Image.open(path).convert('RGBA')
            sx, sz = image.width / region['width'], image.height / region['height']
            canvas = Image.new('RGBA', (round(world_size[0]*sx), round(world_size[1]*sz)), background)
            canvas.paste(image, (round(region['x0']*sx), round(region['z0']*sz)))
            canvas.save(dest / (key + '.png'))
        return prefix + '/' + key + '.png'

    detail = asset(resources['detailtex']) if resources.get('detailtex') else 'bitmaps/detailtex2.bmp'
    specular = positioned(resources.get('speculartex'), 'specular', (0, 0, 0, 255))
    distribution = positioned(resources.get('splatdistrtex'), 'distribution', (255, 0, 0, 0))
    normals = []
    for i in range(1, 5):
        filename = resources.get('splatdetailnormaltex' + str(i))
        if filename:
            normals.append(asset(filename))
    if not normals:
        import io
        image = Image.open(io.BytesIO(CLASSIC_DETAIL)).convert('L')
        flat = Image.new('RGBA', image.size, (128, 128, 255, 128))
        flat.putalpha(image)
        flat.save(dest / 'classic_detail.png')
        normals = [prefix + '/classic_detail.png'] * 4
    assert len(normals) == 4, 'All four DNTS channels are required'
    defaults = {'groundAmbientColor': [.5]*3, 'groundDiffuseColor': [1]*3,
                'groundSpecularColor': [0]*3, 'unitAmbientColor': [.5]*3,
                'unitDiffuseColor': [1]*3, 'unitSpecularColor': [1]*3,
                'specularExponent': 30, 'groundShadowDensity': .75, 'modelShadowDensity': .75}
    aliases = {'unitSpecularColor': 'specularsuncolor', 'modelShadowDensity': 'unitshadowdensity'}
    sun = {k: lighting.get(aliases.get(k, k.lower()), v) for k, v in defaults.items()}
    sun['groundShadowDensity'] = min(sun['groundShadowDensity'], .75)
    sun['modelShadowDensity'] = min(sun['modelShadowDensity'], .75)
    direction = lighting.get('sundir', [1, 1, 1])
    atmosphere = info.get('atmosphere', {})
    fog = {k: atmosphere.get(k.lower(), v) for k, v in {
        'fogColor': [.8]*3, 'fogStart': .99, 'fogEnd': 1, 'cloudColor': [.8]*3,
        'skyColor': [.8]*3, 'sunColor': [.8]*3}.items()}
    override = GAME_ROOT / 'LuaUI/Configs/MapSettingsOverride' / (name + '.lua')
    if override.exists():
        overrides = lua_data(override)
        sun.update(overrides.get('sun') or {})
        fog.update(overrides.get('fog') or {})
        angles = overrides.get('direction')
        if angles:
            yaw, pitch = angles['sunDir'], angles['sunPitch']
            direction = [math.cos(pitch)*math.cos(yaw), math.sin(pitch), math.cos(pitch)*math.sin(yaw)]
    splats = info.get('splats', {})
    rendering = {'splatTexScales': splats.get('texscales', [.02]*4),
                 'splatTexMults': splats.get('texmults', [1, 0, 0, 0]),
                 'splatDetailNormalDiffuseAlpha': bool(resources.get('splatdetailnormaldiffusealpha', True)),
                 'voidWater': not bool(region.get('surface'))}
    return {'name': name, 'textures': [['$detail', detail], ['$ssmf_specular', specular],
            ['$ssmf_splat_distr', distribution]] + [['$ssmf_splat_normals', path, i] for i, path in enumerate(normals)],
            'sun': sun, 'direction': direction, 'atmosphere': fog, 'rendering': rendering, 'water': water_visuals(info), 'drawWater': not (region.get('surface', {}).get('render')=='terrain')}


def build(manifest_path=ROOT/'portal_maps.json', target=TARGET):
    manifest = json.loads(Path(manifest_path).read_text())
    loaded = []
    for entry in manifest['maps']:
        source = (WORKSPACE / entry['source']).resolve()
        smf = list((source/'maps').glob('*.smf'))
        assert len(smf) == 1, source
        raw = smf[0].read_bytes()
        h = struct.unpack_from(FMT, raw)
        assert h[3] % 128 == 0 and h[4] % 128 == 0
        loaded.append((entry, source, raw, h, map_info(source)))
    columns, gap = manifest['columns'], manifest['gap']
    assert 1 <= columns <= len(loaded) and gap >= 32 and gap % 32 == 0
    cell_x = max(h[3]*8 for _, _, _, h, _ in loaded)
    cell_z = max(h[4]*8 for _, _, _, h, _ in loaded)
    width = columns*cell_x + (columns-1)*gap
    # Native SMF diffuse/ROAM pages cover 1024 elmos. Pad only the outer edge;
    # the authored regions and internal separating strips keep their dimensions.
    width = math.ceil(width / 1024) * 1024
    rows = math.ceil(len(loaded)/columns)
    height = rows*cell_z + (rows-1)*gap
    height = math.ceil(height / 1024) * 1024
    mx, mz = width//8, height//8
    staging = target.with_suffix('.building')
    if staging.exists():
        shutil.rmtree(staging)
    (staging/'maps').mkdir(parents=True)
    # Only the generic map feature placer is needed, not original global effects.
    for directory in ('LuaGaia', 'maphelper'):
        shutil.copytree(ROOT/'map-template'/directory, staging/directory)
    low = manifest['void_height']
    high = max(info.get('smf', {}).get('maxheight', h[9]) for _, _, _, h, info in loaded)
    heights = array.array('H', [0]) * ((mx+1)*(mz+1))
    type_image, metal_image = Image.new('L', (mx//2, mz//2)), Image.new('L', (mx//2, mz//2))
    mini = Image.new('RGB', (width//4, height//4), (8, 12, 20))
    tile_payload = bytearray(bytes(680))
    tile_indices, tile_count = [0] * (mx*mz//16), 1
    features, feature_names, objectlist, spots, boxes, regions, profiles, teams = [], [], [], [], {}, [], [], []
    terrain_types = {}
    for index, (entry, source, raw, h, info) in enumerate(loaded):
        ox, oz = index % columns*(cell_x+gap), index//columns*(cell_z+gap)
        region = {'id': entry['id'], 'name': entry['name'], 'style': entry['style'], 'x0': ox, 'z0': oz,
                  'x1': ox+h[3]*8, 'z1': oz+h[4]*8, 'width': h[3]*8, 'height': h[4]*8}
        if entry.get('surface'):
            region['surface'] = dict(entry['surface'])
        regions.append(region)
        values = array.array('H')
        values.frombytes(raw[h[10]:h[10]+(h[3]+1)*(h[4]+1)*2])
        minimum = info.get('smf', {}).get('minheight', h[8])
        maximum = info.get('smf', {}).get('maxheight', h[9])
        converted = array.array('H', (round((minimum+v*(maximum-minimum)/65535-low)*65535/(high-low)) for v in values))
        for z in range(h[4]+1):
            start = (oz//8+z)*(mx+1)+ox//8
            heights[start:start+h[3]+1] = converted[z*(h[3]+1):(z+1)*(h[3]+1)]
        payload, count, indices = read_tiles(source, raw, h)
        tile_payload.extend(payload)
        for z in range(h[4]//4):
            start = (oz//32+z)*(mx//4)+ox//32
            tile_indices[start:start+h[3]//4] = [v+tile_count for v in indices[z*(h[3]//4):(z+1)*(h[3]//4)]]
        tile_count += count
        size = (h[3]//2, h[4]//2)
        src_types = Image.frombytes('L', size, raw[h[11]:h[11]+size[0]*size[1]])
        mapping = {}
        for old in sorted(set(src_types.tobytes())):
            definition = info.get('terraintypes', {}).get(str(old), {'name': 'Ground', 'hardness': 1, 'movespeeds': {'tank': 1, 'kbot': 1, 'hover': 1, 'ship': 1}})
            new = len(terrain_types)
            assert new < 255
            terrain_types[str(new)] = definition
            mapping[old] = new
        src_types = src_types.point([mapping.get(i, 0) for i in range(256)])
        type_image.paste(src_types, (ox//16, oz//16))
        metal_image.paste(Image.frombytes('L', size, raw[h[14]:h[14]+size[0]*size[1]]), (ox//16, oz//16))
        source_mini = Image.open(io.BytesIO(dds_header(1024, 1024)+raw[h[13]:h[13]+524288])).convert('RGB')
        mini.paste(source_mini.resize((region['width']//4, region['height']//4)), (ox//4, oz//4))
        native_spots = source_spots(source, raw, h, info, entry['name'])
        spots.extend(dict(s, x=s['x']+ox, z=s['z']+oz) for s in native_spots)
        region['metal_spots'] = len(native_spots)
        startfile = source/'mapconfig/map_startboxes.lua'
        if not startfile.exists():
            startfile = GAME_ROOT/'LuaRules/Configs/StartBoxes'/(entry['name']+'.lua')
        native_boxes = ordered(lua_data(startfile, source))[:2]
        for side, box in enumerate(native_boxes):
            box = copy.deepcopy(box)
            if entry.get('starts') == 'map':
                start = info.get('teams', {}).get(str(side), {}).get('startpos') or info.get('team'+str(side), {})
                x, z = start.get('x', start.get('startposx')), start.get('z', start.get('startposz'))
                assert x is not None and z is not None, 'Authored start missing for '+entry['name']
                box['startpoints'] = [[x,z]]
            box['nameLong'] = entry['name']+' '+box.get('nameLong', '')
            for point in box['startpoints']:
                point[0] += ox
                point[1] += oz
            for polygon in box['boxes']:
                for point in polygon:
                    point[0] += ox
                    point[1] += oz
            team = len(teams)
            boxes[str(team)] = box
            teams.append({'team': team, 'region': index+1, 'start': box['startpoints'][0], 'boxes': box['boxes']})
        merge_assets(source, staging)
        fp = source/'mapconfig/featureplacer/set.lua'
        if fp.exists():
            for obj in lua_data(fp, source).get('objectlist', []):
                objectlist.append(dict(obj, x=obj['x']+ox, z=obj['z']+oz))
        pos = h[15]
        types, number = struct.unpack_from('<ii', raw, pos)
        pos += 8
        remap = {}
        for i in range(types):
            end = raw.index(0, pos)
            name = raw[pos:end].decode()
            if name not in feature_names:
                feature_names.append(name)
            remap[i] = feature_names.index(name)
            pos = end+1
        for i in range(number):
            kind, x, y, z, rotation, scale = struct.unpack_from('<i5f', raw, pos+i*24)
            features.append((remap[kind], x+ox, y, z+oz, rotation, scale))
        profile = material(source, info, region, staging, (width, height), entry['name'])
        profiles.append(profile)
        if entry.get('surface', {}).get('texture'):
            filename = region['surface']['texture']
            src = source/'maps'/filename
            dest = staging/'maps/regions'/entry['id']/filename
            shutil.copyfile(src, dest)
            region['surface']['texture'] = dest.relative_to(staging).as_posix()
        print(f'{entry["name"]}: native {h[3]/64:g}x{h[4]/64:g}, {len(native_spots)} metal spots, {number} SMF features', flush=True)
    new = bytearray(80)
    header = list(loaded[0][3])
    header[2:5] = [int(hashlib.sha256(Path(manifest_path).read_bytes()).hexdigest()[:7],16), mx, mz]
    header[8:10], header[16] = [low, high], 0
    for field, data in [(10, heights.tobytes()), (11, type_image.tobytes()), (14, metal_image.tobytes())]:
        header[field] = len(new)
        new.extend(data)
    header[12] = len(new)
    new.extend(struct.pack('<iii', 1, tile_count, tile_count)+b'worlds.smt\0'+struct.pack(f'<{len(tile_indices)}i', *tile_indices))
    header[13] = len(new)
    out = io.BytesIO()
    mini.resize((1024,1024)).save(out, format='DDS', pixel_format='DXT1')
    # SMF always stores nine minimap levels, independently of the rectangular override.
    for level in range(9):
        out = io.BytesIO()
        mini.resize((1024>>level,1024>>level)).save(out, format='DDS', pixel_format='DXT1')
        new.extend(out.getvalue()[128:])
    header[15] = len(new)
    new.extend(struct.pack('<ii', len(feature_names), len(features)))
    new.extend(b''.join(n.encode()+b'\0' for n in feature_names))
    for feature in features:
        new.extend(struct.pack('<i5f', *feature))
    struct.pack_into(FMT, new, 0, *header)
    (staging/'maps/worlds.smf').write_bytes(new)
    (staging/'maps/worlds.smt').write_bytes(struct.pack('<16s4i', b'spring tilefile\0', 1, tile_count, 32, 1)+tile_payload)
    mini.save(staging/'maps/worlds_minimap.png')
    layout = {'schema': 1, 'name': manifest['name']+' '+manifest['version'], 'size': [width, height],
              'gap': gap, 'regions': regions, 'connections': manifest['connections'], 'teams': teams, 'profiles': profiles}
    for a,b in layout['connections']:
        assert 1 <= a <= len(regions) and 1 <= b <= len(regions) and a != b
    write_lua(staging/'mapconfig/portal_worlds.lua', layout)
    write_lua(staging/'mapconfig/map_startboxes.lua', boxes)
    write_lua(staging/'mapconfig/map_metal_layout.lua', {'spots': spots})
    write_lua(staging/'mapconfig/featureplacer/set.lua', {'unitlist': [], 'buildinglist': [], 'objectlist': objectlist})
    resources = {'detailTex': profiles[0]['textures'][0][1], 'specularTex': profiles[0]['textures'][1][1],
                 'splatDistrTex': profiles[0]['textures'][2][1], 'splatDetailNormalDiffuseAlpha': True}
    resources.update({'splatDetailNormalTex'+str(i+1): profiles[0]['textures'][i+3][1] for i in range(4)})
    # Resource names in mapinfo are resolved relative to maps/ by the engine.
    resources = {k: v.removeprefix('maps/') if isinstance(v,str) else v for k,v in resources.items()}
    mapinfo = {'name': manifest['name'], 'shortname': manifest['name'], 'version': manifest['version'],
               'description': str(len(regions))+' native maps connected by commander-death portals. See ATTRIBUTION.txt.',
               'author': 'Original map authors; composition assisted by OpenAI Codex', 'modtype': 3,
               'depend': ['Map Helper v1'], 'mapfile': 'maps/worlds.smf', 'maphardness': 200, 'gravity': 130,
               'maxMetal': 1, 'extractorRadius': 100, 'voidWater': True,
               'smf': {'minheight': low, 'maxheight': high, 'smtFileName0': 'maps/worlds.smt', 'minimapTex': 'maps/worlds_minimap.png'},
               'resources': resources, 'splats': {'texScales': profiles[0]['rendering']['splatTexScales'], 'texMults': profiles[0]['rendering']['splatTexMults']},
               'water': dict(profiles[0]['water'], damage=0),
               'lighting': loaded[0][4]['lighting'], 'atmosphere': loaded[0][4]['atmosphere'], 'terrainTypes': terrain_types}
    write_lua(staging/'mapinfo.lua', mapinfo)
    (staging/'composition.json').write_text(json.dumps(layout, indent=2))
    attribution = ['Native terrain dimensions, diffuse tiles and mipmaps are preserved; no rescaling.',
                   'AI assistance: OpenAI Codex authored the composition and portal code. No AI-generated media.']
    for entry, source, raw, h, info in loaded:
        attribution.append(entry['name']+': '+info.get('author', info.get('description', 'See original archive metadata.')))
        attribution.extend(entry.get('attribution', []))
    (staging/'ATTRIBUTION.txt').write_text('\n'.join(attribution)+'\n')
    if target.exists():
        shutil.rmtree(target)
    staging.rename(target)
    print(json.dumps({'archive': str(target), 'size': layout['size'], 'regions': len(regions), 'gap': gap, 'spots': len(spots), 'features': len(features)+len(objectlist)}, indent=2))
    return layout


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', type=Path, default=ROOT/'portal_maps.json')
    parser.add_argument('--game-dir', type=Path, default=ROOT/'map-metadata' if (ROOT/'map-metadata').exists() else DEFAULT_GAME,
                        help='Authored map override root (default: bundled map-metadata or this checkout)')
    engine = parser.add_mutually_exclusive_group(required=True)
    engine.add_argument('--engine-source', type=Path, help='Recoil source checkout for the classic detail texture')
    engine.add_argument('--engine-dir', type=Path, help='Recoil binary install; read its bundled classic detail texture')
    parser.add_argument('--target', type=Path, default=TARGET)
    args = parser.parse_args()
    GAME_ROOT = args.game_dir.resolve()
    assert (GAME_ROOT/'LuaRules').is_dir()
    if args.engine_source:
        CLASSIC_DETAIL = (args.engine_source/'cont/base/bitmaps/bitmaps/detailtex2.bmp').read_bytes()
    else:
        import zipfile
        with zipfile.ZipFile(args.engine_dir/'base/spring/bitmaps.sdz') as archive:
            CLASSIC_DETAIL = archive.read('bitmaps/detailtex2.bmp')
    build(args.manifest, args.target)
