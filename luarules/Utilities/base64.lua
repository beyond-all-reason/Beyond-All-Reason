-- $Id: api_base64.lua 3171 2008-11-06 09:06:29Z det $
-- Author: Alex Kloss
-- Contact: http://www.it-rfc.de
-- Date: 2006-2008
-- License: LGPL2

-- Public functions:
--  * Spring.Utilities.Base64Encode(string data) -> string
--  * Spring.Utilities.Base64Decode(string data) -> string

-- bitshift functions (<<, >> equivalent)
-- shift left
local function lsh(value,shift)
	return (value*(2^shift)) % 256
end

-- shift right
local function rsh(value,shift)
	return math.floor(value/2^shift) % 256
end

-- return single bit (for OR)
local function bit(x,b)
	return (x % 2^b - x % 2^(b-1) > 0)
end

-- logic OR for number values
local function lor(x,y)
	result = 0
	for p=1,8 do result = result + (((bit(x,p) or bit(y,p)) == true) and 2^(p-1) or 0) end
	return result
end

-- encryption table
local base64chars = {[0]='A',[1]='B',[2]='C',[3]='D',[4]='E',[5]='F',[6]='G',[7]='H',[8]='I',[9]='J',[10]='K',[11]='L',[12]='M',[13]='N',[14]='O',[15]='P',[16]='Q',[17]='R',[18]='S',[19]='T',[20]='U',[21]='V',[22]='W',[23]='X',[24]='Y',[25]='Z',[26]='a',[27]='b',[28]='c',[29]='d',[30]='e',[31]='f',[32]='g',[33]='h',[34]='i',[35]='j',[36]='k',[37]='l',[38]='m',[39]='n',[40]='o',[41]='p',[42]='q',[43]='r',[44]='s',[45]='t',[46]='u',[47]='v',[48]='w',[49]='x',[50]='y',[51]='z',[52]='0',[53]='1',[54]='2',[55]='3',[56]='4',[57]='5',[58]='6',[59]='7',[60]='8',[61]='9',[62]='-',[63]='_'}

-- function encode
-- encodes input string to base64.
function Spring.Utilities.Base64Encode(data)
	local bytes = {}
	local result = ""
	for spos=0,string.len(data)-1,3 do
		for byte=1,3 do bytes[byte] = string.byte(string.sub(data,(spos+byte))) or 0 end
		result = string.format('%s%s%s%s%s',result,base64chars[rsh(bytes[1],2)],base64chars[lor(lsh((bytes[1] % 4),4), rsh(bytes[2],4))] or "=",((#data-spos) > 1) and base64chars[lor(lsh(bytes[2] % 16,2), rsh(bytes[3],6))] or "=",((#data-spos) > 2) and base64chars[(bytes[3] % 64)] or "=")
	end
	return result
end

-- decryption table
local base64bytes = {['A']=0,['B']=1,['C']=2,['D']=3,['E']=4,['F']=5,['G']=6,['H']=7,['I']=8,['J']=9,['K']=10,['L']=11,['M']=12,['N']=13,['O']=14,['P']=15,['Q']=16,['R']=17,['S']=18,['T']=19,['U']=20,['V']=21,['W']=22,['X']=23,['Y']=24,['Z']=25,['a']=26,['b']=27,['c']=28,['d']=29,['e']=30,['f']=31,['g']=32,['h']=33,['i']=34,['j']=35,['k']=36,['l']=37,['m']=38,['n']=39,['o']=40,['p']=41,['q']=42,['r']=43,['s']=44,['t']=45,['u']=46,['v']=47,['w']=48,['x']=49,['y']=50,['z']=51,['0']=52,['1']=53,['2']=54,['3']=55,['4']=56,['5']=57,['6']=58,['7']=59,['8']=60,['9']=61,['-']=62,['_']=63,['=']=nil}

-- function decode
-- decode base64 input to string
function Spring.Utilities.Base64Decode(data)
	local chars = {}
	local result=""
	for dpos=0,string.len(data)-1,4 do
		for char=1,4 do chars[char] = base64bytes[(string.sub(data,(dpos+char),(dpos+char)) or "=")] end
		result = string.format('%s%s%s%s',result,string.char(lor(lsh(chars[1],2), rsh(chars[2],4))),(chars[3] ~= nil) and string.char(lor(lsh(chars[2],4), rsh(chars[3],2))) or "",(chars[4] ~= nil) and string.char(lor(lsh(chars[3],6) % 192, (chars[4]))) or "")
	end
	return result
end
