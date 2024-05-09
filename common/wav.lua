-- Small library for getting the metadata of .wav files
-- Author: Beherith mysterme@gmail.com
-- Based on http://soundfile.sapp.org/doc/WaveFormat/

local wavCache = {} -- A table keyed with the absolute path to the filename,


function ReadWAV(fname)
	if wavCache[fname] then
		return wavCache[fname]
	end
	if not VFS.FileExists(fname) then
		Spring.Echo("ReadWAV: File does not exist:", fname)
		return nil
	end
	local data = VFS.LoadFile(fname)
	local ChunkID = string.sub(data, 1, 4)
	local ChunkSize = VFS.UnpackU32(string.sub(data,5,8))
	local Format = string.sub(data, 9, 12)
	if ChunkID == "RIFF" and Format == "WAVE" then
		local NumChannels = VFS.UnpackU16(string.sub(data, 23, 24))
		local SampleRate  = VFS.UnpackU32(string.sub(data, 25, 28))
		local BitsPerSample = VFS.UnpackU16(string.sub(data, 35, 36))
		--Spring.Echo(fname, ChunkID, ChunkSize, Format, NumChannels, SampleRate, BitsPerSample)

		local Length = (ChunkSize - 36) / (SampleRate * NumChannels *(BitsPerSample/8))
		--Spring.Echo(Length)
		wavCache[fname] = {
				NumChannels = NumChannels,
				SampleRate = SampleRate,
				BitsPerSample = BitsPerSample,
				Length = Length
			}
		return wavCache[fname]
	else
		Spring.Echo("ReadWAV: File is not a RIFF .wav file:", fname)
	end

end
