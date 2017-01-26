cmdColors = {}

local f,it,isFile = nil,nil,false
f  = io.open('cmdcolors.txt','r')
if f then
  it = f:lines()
  isFile = true
else
  f  = VFS.LoadFile('cmdcolors.txt')
  it = string.gmatch(f, "%a+.-\n")
end

local wp = '%s*([^%s]+)'           -- word pattern
local cp = '^'..wp..wp..wp..wp..wp -- color pattern
local sp = '^'..wp..wp             -- single value pattern like queuedLineWidth

for line in it do
  local _, _, n, r, g, b, a = string.find(line, cp)

  r = tonumber(r or 1.0)
  g = tonumber(g or 1.0)
  b = tonumber(b or 1.0)
  a = tonumber(a or 1.0)

  if n then
    cmdColors[n]= { r, g,b,a}
  else
    _, _, n, r= string.find(line:lower(), sp)
    if n then
      cmdColors[n]= r
    end
  end
end

if isFile then f:close() end
f,it,wp,cp,sp=nil,nil,nil,nil,nil