--[[
	This file contains a ROT13-encoded list of words and patterns used by the
	client-side chat filter. The list is intentionally stored ROT13'd to avoid
	placing offensive words in plaintext in the repository. Each entry is a
	Lua pattern (regular expression) -- keep regex metacharacters (e.g. ^, $, [], etc.)
	intact when adding new entries.

	Guidelines:
	- Add new words in ROT13 form (to encode, use any ROT13 tool) OR add the
		plain form and let the decode loop below convert them for you (prefer ROT13 when
		possible so reviewers don't see plaintext in the diff).
	- Use case-insensitive patterns where appropriate and avoid overly-broad
		patterns which could cause false positives.
	- Keep comments minimal and do not include raw offensive words in plaintext.
]]

local wordList = {
	"^er?r?gneqf?$",
	"^er?r?gneqrq$",
	"^nffshpxre$",
	"^ornare[f]?$",
	"^ohgpuqvxr$",
	"^puvatpubat$",
	"^pbbaf?$",
	"^pheelavttref?$",
	"^pheelzhapuref?$",
	"^qntbf?$",
	"^qnexr?lf?$",
	"^qnexvrf?$",
	"^qvncreurnqf?$",
	"^qvzjvg$",
	"^qbtshpxre$",
	"^qbgurnq$",
	"^qbgurnqf$",
	"^qhzonff$",
	"^qhzonffrf$",
	"^qhzoovgpu$",
	"^qhzoshpx$",
	"^qhzofuvg$",
	"^qharpbba$",
	"^qharpbbaf$",
	"^qvxrf?$",
	"^qlxrf?$",
	"^sntt?[v1rb]?g?[mf]?$",
	"^sntont$",
	"^sntshpxre$",
	"^snttrq$",
	"^snttvat$",
	"^snttvgg$",
	"^snttbgpbpx$",
	"^sntgneq$",
	"^snaalshpxre$",
	"^sngshpx$",
	"^sngshpxre$",
	"^shpxgneqf?$",
	"^t[b0][b0]xf?$",
	"^tnlobl$",
	"^tnltvey$",
	"^tnlgneq$",
	"^tnljnq$",
	"^tbbxrlrf?$",
	"^tebvqf?$",
	"^thvqb$",
	"^tjnvyb$",
	"^tjnvybf$",
	"^tjrvyb$",
	"^tjrvybf$",
	"^u[b0]z[b0]f?$",
	"^ubaxr?lf?$",
	"^ubaxvrf?$",
	"^x[lv]xrf?$",
	"^zpsntt[rvb]g$",
	"^zbeba$",
	"^zhssqvire$",
	"^a[v1]tt?nf?$",
	"^a[1v]tt?ref?$",
	"^a[1v]tt?[n3hb]ef?$",
	"^a1te$",
	"^artebvq$",
	"^avtabt$",
	"^avtn?e?f?$",
	"^a[1v]trggrf?$",
	"^a[1v]tt$",
	"^avttneqyl$",
	"^avttneqf?$",
	"^avttreurnq$",
	"^avttreubyr$",
	"^arterff?$",
	"^avtt?erff$",
	"^avtterffrf$",
	"^avtthuf?$",
	"^avtyrg$",
	"^avten?f?$",
	"^avtf$",
	"^enturnqf?$",
	"^fnaqavttref?$",
	"^fabjavttref?$",
	"^fcnturggvavttref?$",
	"^fcvpf?$",
	"^gneqf?$",
	"^gvzoreavttref?$",
	"^gbjryurnqf?$",
	"^genaavrf?$",
	"^genaalf?$",
	"^juvttref?$",
	"^mvccreurnqf?$",
}

local from = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
local to =   "NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm"

for index, w in ipairs(wordList) do
	local dword = string.gsub(w, '%a', function(c)
		local decodeIndex = from:find(c, 1, true)
		return decodeIndex and string.sub(to, decodeIndex, decodeIndex)
	end)
	wordList[index] = dword
end

return wordList
