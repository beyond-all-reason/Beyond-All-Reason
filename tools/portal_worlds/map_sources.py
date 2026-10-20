#!/usr/bin/env python3
"""Read authored map metadata through Lua 5.1 or legacy TDF; no terrain rescaling."""
import json
import re
import subprocess
from pathlib import Path

from portal_paths import WORKSPACE
LUA_EXPORT = r'''
local root,filename=arg[1],arg[2]
Spring={GetMapOptions=function() return {} end,Utilities={GetTeamCount=function() return 2 end}}
VFS={DirList=function() return {} end,Include=function(path) return dofile(root..'/'..path) end}
math.randomseed(1)
local function encode(v)
 local t=type(v)
 if t=='nil' then return 'null' end
 if t=='boolean' or t=='number' then return tostring(v) end
 if t=='string' then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"' end
 assert(t=='table','Unsupported metadata type '..t)
 local n,count=#v,0
 for k in pairs(v) do count=count+1 end
 local out={}
 if n>0 and n==count then
  for i=1,n do out[i]=encode(v[i]) end
  return '['..table.concat(out,',')..']'
 end
 for k,value in pairs(v) do out[#out+1]=encode(tostring(k))..':'..encode(value) end
 table.sort(out)
 return '{'..table.concat(out,',')..'}'
end
print(encode(dofile(filename)))
'''

def lua_data(path, root=None):
    path = Path(path).resolve()
    helper = WORKSPACE / 'content/export_map.lua'
    helper.parent.mkdir(parents=True, exist_ok=True)
    if not helper.exists() or helper.read_text() != LUA_EXPORT:
        helper.write_text(LUA_EXPORT)
    return json.loads(subprocess.check_output(['lua5.1', str(helper), str(root or path.parent), str(path)], text=True))


def tdf_data(text):
    text = re.sub(r'//[^\n]*|/\*.*?\*/', '', text, flags=re.S)
    tokens = re.findall(r'\[([^\]]+)\]|([{}])|([^{};=]+)=([^;]*);', text)
    root, stack, pending = {}, [], None
    current = root
    for section, brace, key, value in tokens:
        if section:
            pending = section.strip().lower()
        elif brace == '{':
            child = {}
            current[pending] = child
            stack.append(current)
            current, pending = child, None
        elif brace == '}':
            current = stack.pop()
        elif key:
            parts = value.strip().split()
            try:
                parsed = [float(p) for p in parts]
                value = parsed[0] if len(parsed) == 1 else parsed
            except ValueError:
                value = value.strip()
            current[key.strip().lower()] = value
    return root.get('map', root)


def map_info(source):
    source = Path(source)
    if (source / 'mapinfo.lua').exists():
        return lua_data(source / 'mapinfo.lua', source)
    info = tdf_data(next((source / 'maps').glob('*.smd')).read_text())
    light = info.pop('light', {})
    rename = {'groundambiantcolor': 'groundambientcolor', 'groundsuncolor': 'grounddiffusecolor',
              'unitambiantcolor': 'unitambientcolor', 'unitsuncolor': 'unitdiffusecolor'}
    info['lighting'] = {rename.get(k, k): v for k, v in light.items()}
    return info


def lua_literal(value):
    if value is None:
        return 'nil'
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (float, int)):
        return repr(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, list):
        return '{' + ','.join(lua_literal(v) for v in value) + '}'
    return '{' + ','.join('[' + lua_literal(int(k) if str(k).isdigit() else k) + ']=' + lua_literal(v) for k, v in value.items()) + '}'


def write_lua(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('-- Generated from attributed source maps by OpenAI Codex. GPL v2 or later.\nreturn ' + lua_literal(value) + '\n')
