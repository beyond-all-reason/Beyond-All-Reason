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
	"^zpsnttrg$",
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
	local dword = string.gsub(w, '.', function(c)
		if c == '[' or c == ']' or c =='^' or c == '$' then
			return c
		end
		local decodeIndex = from:find(c)
		if decodeIndex and decodeIndex > -1 then
			return string.sub(to, decodeIndex, decodeIndex)
		else
			return c
		end
	end)
	wordList[index] = dword
end

return wordList
