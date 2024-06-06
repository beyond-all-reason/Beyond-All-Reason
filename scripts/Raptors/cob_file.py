# written by ashdnazg https://github.com/ashdnazg/bos2cob
# released under the GNU GPL v3 license

import struct

PACK_FORMAT = "<%dL"
COB_HEADER_FIELDS = (
	"VersionSignature",
	"NumberOfScripts",
	"NumberOfPieces",
	"TotalScriptLen",
	"NumberOfStaticVars",
	"Unknown_2",
	"OffsetToScriptCodeIndexArray",
	"OffsetToScriptNameOffsetArray",
	"OffsetToPieceNameOffsetArray",
	"OffsetToScriptCode",
	"OffsetToNamesArray",
)

COB_TAK_HEADER_FIELDS = (
	"OffsetToSoundNameArray",
	"NumberOfSounds"
)



class COB(object):

	def write_strings(self, strings):
		offsets = []
		content = ""
		for s in strings:
			offsets.append(self._offset)
			s += '\0'
			content += s
			self._offset += len(s)

		return offsets, content

	def write_functions_code_array(self, functions_code_array):
		code_offsets = []
		code_offset = 0
		for code in functions_code_array:
			self._content += code
			code_offsets.append(code_offset)
			code_offset += len(code) / 4
			self._offset += len(code)

		return code_offsets

	def write_array(self, array, is_header = False):
		if is_header:
			self._content = struct.pack(PACK_FORMAT % (len(array),), *array) + self._content
		else:
			self._content += struct.pack(PACK_FORMAT % (len(array),), *array)
			self._offset += len(array) * 4

	def __init__(self, function_names, functions_code, piece_names, static_vars, sound_names):
		self._content = ""
		is_tak = len(sound_names) > 0
		header = {
			"VersionSignature"                  : is_tak and 6 or 4,
			"NumberOfScripts"                   : len(function_names),
			"NumberOfPieces"                    : len(piece_names),
			"TotalScriptLen"                    : sum(len(c) for c in functions_code.values()) / 4,
			"NumberOfStaticVars"                : len(static_vars),
			"Unknown_2"                         : 0,
			"NumberOfSounds"                    : len(sound_names)
		}
		self._offset = len(COB_HEADER_FIELDS) * 4
		if is_tak:
			self._offset += len(COB_TAK_HEADER_FIELDS) * 4

		header['OffsetToScriptCode'] = self._offset

		code_offsets = self.write_functions_code_array(functions_code[n] for n in function_names)

		header['OffsetToScriptCodeIndexArray'] = self._offset

		self.write_array(code_offsets)


		#reserving space for later
		header['OffsetToScriptNameOffsetArray'] = self._offset
		self._offset += len(function_names) * 4
		header['OffsetToPieceNameOffsetArray'] = self._offset
		self._offset += len(piece_names) * 4

		header['OffsetToNamesArray'] = self._offset
		script_name_offsets, script_name_content = self.write_strings(function_names)
		piece_name_offsets, piece_name_content = self.write_strings(piece_names)

		self._offset = header['OffsetToScriptNameOffsetArray']
		self.write_array(script_name_offsets)

		self.write_array(piece_name_offsets)

		self.write_array(tuple(header[n] for n in COB_HEADER_FIELDS), True)
		if is_tak:
			self.write_array(tuple(header[n] for n in COB_TAK_HEADER_FIELDS), True)
		self._content += script_name_content + piece_name_content

	def get_content(self):
		return self._content








