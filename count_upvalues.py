import re

file_path = r"C:\Games\Beyond-All-Reason\data\games\Beyond-All-Reason.sdd\luaui\Widgets\cmd_terraform_brush.lua"

with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

lua_keywords = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
    'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
    'true', 'until', 'while'
}

chunk_locals = set()
for line in lines:
    # Match "local name1, name2 = ..." at indentation 0
    match = re.match(r"^local\s+([a-zA-Z_][a-zA-Z0-9_,\s]*)", line)
    if match:
        content = match.group(1).split("=")[0]
        names = content.split(",")
        for n in names:
            name = n.strip()
            name = name.split("--")[0].strip()
            if " " in name:
                name = name.split()[0]
            if name and name.isidentifier() and name not in lua_keywords:
                chunk_locals.add(name)
    # Also catch "local function name(...)"
    match_func = re.match(r"^local\s+function\s+([a-zA-Z_][a-zA-Z0-9_]*)", line)
    if match_func:
        name = match_func.group(1)
        if name and name not in lua_keywords:
            chunk_locals.add(name)

start_idx = -1
for i, line in enumerate(lines):
    if "function widget:Initialize()" in line:
        start_idx = i
        break

if start_idx == -1:
    print("Not found")
    exit()

end_idx = -1
for i in range(start_idx, len(lines)):
    if i > start_idx and "function widget:Shutdown()" in lines[i]:
        end_idx = i
        break

if end_idx == -1:
    end_idx = len(lines)

# Process EACH line in the function body
found = set()
internals = set()
for i in range(start_idx, end_idx):
    line = lines[i]
    if "--" in line:
        line = line.split("--")[0]
    
    # Check for internal locals at the start of the line (simple heuristic for common patterns)
    # Inside a function, we might have `local x = ...`
    match_local = re.search(r"\blocal\s+([a-zA-Z_][a-zA-Z0-9_,\s]*)", line)
    if match_local:
        content = match_local.group(1).split("=")[0]
        names = content.split(",")
        for n in names:
            name = n.strip()
            if " " in name: name = name.split()[0]
            if name: internals.add(name)
        # Check for usage on the RIGHT hand side before adding to internals for this line's evaluation
        rhs = line.split("=", 1)[1] if "=" in line else ""
        for var in chunk_locals:
            if re.search(rf"\b{re.escape(var)}\b", rhs):
                found.add(var)
        continue # Ignore names on the left hand side of this local declaration

    for var in chunk_locals:
        # If it's used and not an internal local (simple scoping)
        if re.search(rf"\b{re.escape(var)}\b", line):
            if var not in internals:
                found.add(var)

for f in sorted(list(found)):
    print(f)
print(f"Total count: {len(found)}")
