-- $Id: FreeSansBold_14.lua 3171 2008-11-06 09:06:29Z det $

local fontSpecs = {
  srcFile  = [[FreeSansBold.ttf]],
  family   = [[FreeSans]],
  style    = [[Bold]],
  yStep    = 15,
  height   = 14,
  xTexSize = 512,
  yTexSize = 256,
  outlineRadius = 2,
  outlineWeight = 100,
}

local glyphs = {}

glyphs[32] = { --' '--
  num = 32,
  adv = 4,
  oxn =   -2, oyn =   -3, oxp =    3, oyp =    2,
  txn =    1, tyn =    1, txp =    6, typ =    6,
}
glyphs[33] = { --'!'--
  num = 33,
  adv = 5,
  oxn =   -1, oyn =   -2, oxp =    6, oyp =   13,
  txn =   21, tyn =    1, txp =   28, typ =   16,
}
glyphs[34] = { --'"'--
  num = 34,
  adv = 7,
  oxn =   -2, oyn =    4, oxp =    8, oyp =   13,
  txn =   41, tyn =    1, txp =   51, typ =   10,
}
glyphs[35] = { --'#'--
  num = 35,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   12,
  txn =   61, tyn =    1, txp =   73, typ =   16,
}
glyphs[36] = { --'$'--
  num = 36,
  adv = 8,
  oxn =   -2, oyn =   -4, oxp =   10, oyp =   13,
  txn =   81, tyn =    1, txp =   93, typ =   18,
}
glyphs[37] = { --'%'--
  num = 37,
  adv = 12,
  oxn =   -2, oyn =   -3, oxp =   15, oyp =   12,
  txn =  101, tyn =    1, txp =  118, typ =   16,
}
glyphs[38] = { --'&'--
  num = 38,
  adv = 10,
  oxn =   -2, oyn =   -3, oxp =   12, oyp =   13,
  txn =  121, tyn =    1, txp =  135, typ =   17,
}
glyphs[39] = { --'''--
  num = 39,
  adv = 3,
  oxn =   -2, oyn =    4, oxp =    5, oyp =   13,
  txn =  141, tyn =    1, txp =  148, typ =   10,
}
glyphs[40] = { --'('--
  num = 40,
  adv = 5,
  oxn =   -2, oyn =   -5, oxp =    7, oyp =   13,
  txn =  161, tyn =    1, txp =  170, typ =   19,
}
glyphs[41] = { --')'--
  num = 41,
  adv = 5,
  oxn =   -2, oyn =   -5, oxp =    6, oyp =   13,
  txn =  181, tyn =    1, txp =  189, typ =   19,
}
glyphs[42] = { --'*'--
  num = 42,
  adv = 5,
  oxn =   -2, oyn =    3, oxp =    7, oyp =   13,
  txn =  201, tyn =    1, txp =  210, typ =   11,
}
glyphs[43] = { --'+'--
  num = 43,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =    9,
  txn =  221, tyn =    1, txp =  233, typ =   13,
}
glyphs[44] = { --','--
  num = 44,
  adv = 4,
  oxn =   -2, oyn =   -5, oxp =    5, oyp =    5,
  txn =  241, tyn =    1, txp =  248, typ =   11,
}
glyphs[45] = { --'-'--
  num = 45,
  adv = 5,
  oxn =   -2, oyn =    0, oxp =    7, oyp =    7,
  txn =  261, tyn =    1, txp =  270, typ =    8,
}
glyphs[46] = { --'.'--
  num = 46,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    5, oyp =    5,
  txn =  281, tyn =    1, txp =  288, typ =    8,
}
glyphs[47] = { --'/'--
  num = 47,
  adv = 4,
  oxn =   -2, oyn =   -3, oxp =    6, oyp =   12,
  txn =  301, tyn =    1, txp =  309, typ =   16,
}
glyphs[48] = { --'0'--
  num = 48,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  321, tyn =    1, txp =  333, typ =   17,
}
glyphs[49] = { --'1'--
  num = 49,
  adv = 8,
  oxn =   -2, oyn =   -2, oxp =    8, oyp =   12,
  txn =  341, tyn =    1, txp =  351, typ =   15,
}
glyphs[50] = { --'2'--
  num = 50,
  adv = 8,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   13,
  txn =  361, tyn =    1, txp =  373, typ =   16,
}
glyphs[51] = { --'3'--
  num = 51,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  381, tyn =    1, txp =  393, typ =   17,
}
glyphs[52] = { --'4'--
  num = 52,
  adv = 8,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   12,
  txn =  401, tyn =    1, txp =  413, typ =   15,
}
glyphs[53] = { --'5'--
  num = 53,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   12,
  txn =  421, tyn =    1, txp =  433, typ =   16,
}
glyphs[54] = { --'6'--
  num = 54,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  441, tyn =    1, txp =  453, typ =   17,
}
glyphs[55] = { --'7'--
  num = 55,
  adv = 8,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   12,
  txn =  461, tyn =    1, txp =  473, typ =   15,
}
glyphs[56] = { --'8'--
  num = 56,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  481, tyn =    1, txp =  493, typ =   17,
}
glyphs[57] = { --'9'--
  num = 57,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =    1, tyn =   22, txp =   13, typ =   38,
}
glyphs[58] = { --':'--
  num = 58,
  adv = 5,
  oxn =   -1, oyn =   -2, oxp =    6, oyp =   10,
  txn =   21, tyn =   22, txp =   28, typ =   34,
}
glyphs[59] = { --';'--
  num = 59,
  adv = 5,
  oxn =   -1, oyn =   -5, oxp =    6, oyp =   10,
  txn =   41, tyn =   22, txp =   48, typ =   37,
}
glyphs[60] = { --'<'--
  num = 60,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =    9,
  txn =   61, tyn =   22, txp =   73, typ =   34,
}
glyphs[61] = { --'='--
  num = 61,
  adv = 8,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =    8,
  txn =   81, tyn =   22, txp =   93, typ =   32,
}
glyphs[62] = { --'>'--
  num = 62,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =    9,
  txn =  101, tyn =   22, txp =  113, typ =   34,
}
glyphs[63] = { --'?'--
  num = 63,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   13,
  txn =  121, tyn =   22, txp =  133, typ =   37,
}
glyphs[64] = { --'@'--
  num = 64,
  adv = 14,
  oxn =   -2, oyn =   -4, oxp =   16, oyp =   13,
  txn =  141, tyn =   22, txp =  159, typ =   39,
}
glyphs[65] = { --'A'--
  num = 65,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   13,
  txn =  161, tyn =   22, txp =  175, typ =   37,
}
glyphs[66] = { --'B'--
  num = 66,
  adv = 10,
  oxn =   -1, oyn =   -2, oxp =   12, oyp =   13,
  txn =  181, tyn =   22, txp =  194, typ =   37,
}
glyphs[67] = { --'C'--
  num = 67,
  adv = 10,
  oxn =   -2, oyn =   -3, oxp =   12, oyp =   13,
  txn =  201, tyn =   22, txp =  215, typ =   38,
}
glyphs[68] = { --'D'--
  num = 68,
  adv = 10,
  oxn =   -1, oyn =   -2, oxp =   12, oyp =   13,
  txn =  221, tyn =   22, txp =  234, typ =   37,
}
glyphs[69] = { --'E'--
  num = 69,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =   11, oyp =   13,
  txn =  241, tyn =   22, txp =  253, typ =   37,
}
glyphs[70] = { --'F'--
  num = 70,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =   11, oyp =   13,
  txn =  261, tyn =   22, txp =  273, typ =   37,
}
glyphs[71] = { --'G'--
  num = 71,
  adv = 11,
  oxn =   -2, oyn =   -3, oxp =   12, oyp =   13,
  txn =  281, tyn =   22, txp =  295, typ =   38,
}
glyphs[72] = { --'H'--
  num = 72,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   13,
  txn =  301, tyn =   22, txp =  315, typ =   37,
}
glyphs[73] = { --'I'--
  num = 73,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    5, oyp =   13,
  txn =  321, tyn =   22, txp =  328, typ =   37,
}
glyphs[74] = { --'J'--
  num = 74,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =    9, oyp =   13,
  txn =  341, tyn =   22, txp =  352, typ =   38,
}
glyphs[75] = { --'K'--
  num = 75,
  adv = 10,
  oxn =   -1, oyn =   -2, oxp =   13, oyp =   13,
  txn =  361, tyn =   22, txp =  375, typ =   37,
}
glyphs[76] = { --'L'--
  num = 76,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =   11, oyp =   13,
  txn =  381, tyn =   22, txp =  393, typ =   37,
}
glyphs[77] = { --'M'--
  num = 77,
  adv = 12,
  oxn =   -2, oyn =   -2, oxp =   13, oyp =   13,
  txn =  401, tyn =   22, txp =  416, typ =   37,
}
glyphs[78] = { --'N'--
  num = 78,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   13,
  txn =  421, tyn =   22, txp =  435, typ =   37,
}
glyphs[79] = { --'O'--
  num = 79,
  adv = 11,
  oxn =   -2, oyn =   -3, oxp =   13, oyp =   13,
  txn =  441, tyn =   22, txp =  456, typ =   38,
}
glyphs[80] = { --'P'--
  num = 80,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =   11, oyp =   13,
  txn =  461, tyn =   22, txp =  473, typ =   37,
}
glyphs[81] = { --'Q'--
  num = 81,
  adv = 11,
  oxn =   -2, oyn =   -3, oxp =   13, oyp =   13,
  txn =  481, tyn =   22, txp =  496, typ =   38,
}
glyphs[82] = { --'R'--
  num = 82,
  adv = 10,
  oxn =   -1, oyn =   -2, oxp =   12, oyp =   13,
  txn =    1, tyn =   43, txp =   14, typ =   58,
}
glyphs[83] = { --'S'--
  num = 83,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   11, oyp =   13,
  txn =   21, tyn =   43, txp =   34, typ =   59,
}
glyphs[84] = { --'T'--
  num = 84,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   11, oyp =   13,
  txn =   41, tyn =   43, txp =   54, typ =   58,
}
glyphs[85] = { --'U'--
  num = 85,
  adv = 10,
  oxn =   -1, oyn =   -3, oxp =   12, oyp =   13,
  txn =   61, tyn =   43, txp =   74, typ =   59,
}
glyphs[86] = { --'V'--
  num = 86,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   13,
  txn =   81, tyn =   43, txp =   95, typ =   58,
}
glyphs[87] = { --'W'--
  num = 87,
  adv = 13,
  oxn =   -2, oyn =   -2, oxp =   16, oyp =   13,
  txn =  101, tyn =   43, txp =  119, typ =   58,
}
glyphs[88] = { --'X'--
  num = 88,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   13,
  txn =  121, tyn =   43, txp =  135, typ =   58,
}
glyphs[89] = { --'Y'--
  num = 89,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   13,
  txn =  141, tyn =   43, txp =  155, typ =   58,
}
glyphs[90] = { --'Z'--
  num = 90,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   11, oyp =   13,
  txn =  161, tyn =   43, txp =  174, typ =   58,
}
glyphs[91] = { --'['--
  num = 91,
  adv = 5,
  oxn =   -2, oyn =   -5, oxp =    7, oyp =   13,
  txn =  181, tyn =   43, txp =  190, typ =   61,
}
glyphs[92] = { --'\'--
  num = 92,
  adv = 4,
  oxn =   -3, oyn =   -3, oxp =    7, oyp =   12,
  txn =  201, tyn =   43, txp =  211, typ =   58,
}
glyphs[93] = { --']'--
  num = 93,
  adv = 5,
  oxn =   -2, oyn =   -5, oxp =    6, oyp =   13,
  txn =  221, tyn =   43, txp =  229, typ =   61,
}
glyphs[94] = { --'^'--
  num = 94,
  adv = 8,
  oxn =   -2, oyn =    1, oxp =   10, oyp =   12,
  txn =  241, tyn =   43, txp =  253, typ =   54,
}
glyphs[95] = { --'_'--
  num = 95,
  adv = 8,
  oxn =   -3, oyn =   -5, oxp =   11, oyp =    1,
  txn =  261, tyn =   43, txp =  275, typ =   49,
}
glyphs[96] = { --'`'--
  num = 96,
  adv = 5,
  oxn =   -2, oyn =    6, oxp =    5, oyp =   13,
  txn =  281, tyn =   43, txp =  288, typ =   50,
}
glyphs[97] = { --'a'--
  num = 97,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   10,
  txn =  301, tyn =   43, txp =  313, typ =   56,
}
glyphs[98] = { --'b'--
  num = 98,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   11, oyp =   13,
  txn =  321, tyn =   43, txp =  334, typ =   59,
}
glyphs[99] = { --'c'--
  num = 99,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   10,
  txn =  341, tyn =   43, txp =  353, typ =   56,
}
glyphs[100] = { --'d'--
  num = 100,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  361, tyn =   43, txp =  373, typ =   59,
}
glyphs[101] = { --'e'--
  num = 101,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   10,
  txn =  381, tyn =   43, txp =  393, typ =   56,
}
glyphs[102] = { --'f'--
  num = 102,
  adv = 5,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   13,
  txn =  401, tyn =   43, txp =  410, typ =   58,
}
glyphs[103] = { --'g'--
  num = 103,
  adv = 9,
  oxn =   -2, oyn =   -6, oxp =   10, oyp =   10,
  txn =  421, tyn =   43, txp =  433, typ =   59,
}
glyphs[104] = { --'h'--
  num = 104,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   13,
  txn =  441, tyn =   43, txp =  453, typ =   58,
}
glyphs[105] = { --'i'--
  num = 105,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    5, oyp =   13,
  txn =  461, tyn =   43, txp =  468, typ =   58,
}
glyphs[106] = { --'j'--
  num = 106,
  adv = 4,
  oxn =   -2, oyn =   -6, oxp =    5, oyp =   13,
  txn =  481, tyn =   43, txp =  488, typ =   62,
}
glyphs[107] = { --'k'--
  num = 107,
  adv = 8,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   13,
  txn =    1, tyn =   64, txp =   13, typ =   79,
}
glyphs[108] = { --'l'--
  num = 108,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    5, oyp =   13,
  txn =   21, tyn =   64, txp =   28, typ =   79,
}
glyphs[109] = { --'m'--
  num = 109,
  adv = 12,
  oxn =   -2, oyn =   -2, oxp =   14, oyp =   10,
  txn =   41, tyn =   64, txp =   57, typ =   76,
}
glyphs[110] = { --'n'--
  num = 110,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   10,
  txn =   61, tyn =   64, txp =   73, typ =   76,
}
glyphs[111] = { --'o'--
  num = 111,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   10,
  txn =   81, tyn =   64, txp =   93, typ =   77,
}
glyphs[112] = { --'p'--
  num = 112,
  adv = 9,
  oxn =   -2, oyn =   -6, oxp =   11, oyp =   10,
  txn =  101, tyn =   64, txp =  114, typ =   80,
}
glyphs[113] = { --'q'--
  num = 113,
  adv = 9,
  oxn =   -2, oyn =   -6, oxp =   10, oyp =   10,
  txn =  121, tyn =   64, txp =  133, typ =   80,
}
glyphs[114] = { --'r'--
  num = 114,
  adv = 5,
  oxn =   -2, oyn =   -2, oxp =    8, oyp =   10,
  txn =  141, tyn =   64, txp =  151, typ =   76,
}
glyphs[115] = { --'s'--
  num = 115,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   10,
  txn =  161, tyn =   64, txp =  173, typ =   77,
}
glyphs[116] = { --'t'--
  num = 116,
  adv = 5,
  oxn =   -2, oyn =   -3, oxp =    7, oyp =   12,
  txn =  181, tyn =   64, txp =  190, typ =   79,
}
glyphs[117] = { --'u'--
  num = 117,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   10,
  txn =  201, tyn =   64, txp =  213, typ =   77,
}
glyphs[118] = { --'v'--
  num = 118,
  adv = 8,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   10,
  txn =  221, tyn =   64, txp =  233, typ =   76,
}
glyphs[119] = { --'w'--
  num = 119,
  adv = 11,
  oxn =   -2, oyn =   -2, oxp =   13, oyp =   10,
  txn =  241, tyn =   64, txp =  256, typ =   76,
}
glyphs[120] = { --'x'--
  num = 120,
  adv = 8,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   10,
  txn =  261, tyn =   64, txp =  273, typ =   76,
}
glyphs[121] = { --'y'--
  num = 121,
  adv = 8,
  oxn =   -2, oyn =   -6, oxp =   10, oyp =   10,
  txn =  281, tyn =   64, txp =  293, typ =   80,
}
glyphs[122] = { --'z'--
  num = 122,
  adv = 7,
  oxn =   -2, oyn =   -2, oxp =    9, oyp =   10,
  txn =  301, tyn =   64, txp =  312, typ =   76,
}
glyphs[123] = { --'{'--
  num = 123,
  adv = 5,
  oxn =   -2, oyn =   -5, oxp =    7, oyp =   13,
  txn =  321, tyn =   64, txp =  330, typ =   82,
}
glyphs[124] = { --'|'--
  num = 124,
  adv = 4,
  oxn =   -1, oyn =   -5, oxp =    5, oyp =   13,
  txn =  341, tyn =   64, txp =  347, typ =   82,
}
glyphs[125] = { --'}'--
  num = 125,
  adv = 5,
  oxn =   -1, oyn =   -5, oxp =    7, oyp =   13,
  txn =  361, tyn =   64, txp =  369, typ =   82,
}
glyphs[126] = { --'~'--
  num = 126,
  adv = 8,
  oxn =   -2, oyn =   -1, oxp =   10, oyp =    7,
  txn =  381, tyn =   64, txp =  393, typ =   72,
}
glyphs[127] = { --''--
  num = 127,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  401, tyn =   64, txp =  410, typ =   78,
}
glyphs[128] = { --'Ä'--
  num = 128,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  421, tyn =   64, txp =  430, typ =   78,
}
glyphs[129] = { --'Å'--
  num = 129,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  441, tyn =   64, txp =  450, typ =   78,
}
glyphs[130] = { --'Ç'--
  num = 130,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  461, tyn =   64, txp =  470, typ =   78,
}
glyphs[131] = { --'É'--
  num = 131,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  481, tyn =   64, txp =  490, typ =   78,
}
glyphs[132] = { --'Ñ'--
  num = 132,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =    1, tyn =   85, txp =   10, typ =   99,
}
glyphs[133] = { --'Ö'--
  num = 133,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =   21, tyn =   85, txp =   30, typ =   99,
}
glyphs[134] = { --'Ü'--
  num = 134,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =   41, tyn =   85, txp =   50, typ =   99,
}
glyphs[135] = { --'á'--
  num = 135,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =   61, tyn =   85, txp =   70, typ =   99,
}
glyphs[136] = { --'à'--
  num = 136,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =   81, tyn =   85, txp =   90, typ =   99,
}
glyphs[137] = { --'â'--
  num = 137,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  101, tyn =   85, txp =  110, typ =   99,
}
glyphs[138] = { --'ä'--
  num = 138,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  121, tyn =   85, txp =  130, typ =   99,
}
glyphs[139] = { --'ã'--
  num = 139,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  141, tyn =   85, txp =  150, typ =   99,
}
glyphs[140] = { --'å'--
  num = 140,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  161, tyn =   85, txp =  170, typ =   99,
}
glyphs[141] = { --'ç'--
  num = 141,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  181, tyn =   85, txp =  190, typ =   99,
}
glyphs[142] = { --'é'--
  num = 142,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  201, tyn =   85, txp =  210, typ =   99,
}
glyphs[143] = { --'è'--
  num = 143,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  221, tyn =   85, txp =  230, typ =   99,
}
glyphs[144] = { --'ê'--
  num = 144,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  241, tyn =   85, txp =  250, typ =   99,
}
glyphs[145] = { --'ë'--
  num = 145,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  261, tyn =   85, txp =  270, typ =   99,
}
glyphs[146] = { --'í'--
  num = 146,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  281, tyn =   85, txp =  290, typ =   99,
}
glyphs[147] = { --'ì'--
  num = 147,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  301, tyn =   85, txp =  310, typ =   99,
}
glyphs[148] = { --'î'--
  num = 148,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  321, tyn =   85, txp =  330, typ =   99,
}
glyphs[149] = { --'ï'--
  num = 149,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  341, tyn =   85, txp =  350, typ =   99,
}
glyphs[150] = { --'ñ'--
  num = 150,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  361, tyn =   85, txp =  370, typ =   99,
}
glyphs[151] = { --'ó'--
  num = 151,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  381, tyn =   85, txp =  390, typ =   99,
}
glyphs[152] = { --'ò'--
  num = 152,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  401, tyn =   85, txp =  410, typ =   99,
}
glyphs[153] = { --'ô'--
  num = 153,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  421, tyn =   85, txp =  430, typ =   99,
}
glyphs[154] = { --'ö'--
  num = 154,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  441, tyn =   85, txp =  450, typ =   99,
}
glyphs[155] = { --'õ'--
  num = 155,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  461, tyn =   85, txp =  470, typ =   99,
}
glyphs[156] = { --'ú'--
  num = 156,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  481, tyn =   85, txp =  490, typ =   99,
}
glyphs[157] = { --'ù'--
  num = 157,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =    1, tyn =  106, txp =   10, typ =  120,
}
glyphs[158] = { --'û'--
  num = 158,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =   21, tyn =  106, txp =   30, typ =  120,
}
glyphs[159] = { --'ü'--
  num = 159,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =   41, tyn =  106, txp =   50, typ =  120,
}
glyphs[160] = { --'†'--
  num = 160,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =   61, tyn =  106, txp =   70, typ =  120,
}
glyphs[161] = { --'°'--
  num = 161,
  adv = 5,
  oxn =   -2, oyn =   -5, oxp =    6, oyp =   10,
  txn =   81, tyn =  106, txp =   89, typ =  121,
}
glyphs[162] = { --'¢'--
  num = 162,
  adv = 8,
  oxn =   -2, oyn =   -4, oxp =   10, oyp =   11,
  txn =  101, tyn =  106, txp =  113, typ =  121,
}
glyphs[163] = { --'£'--
  num = 163,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  121, tyn =  106, txp =  133, typ =  122,
}
glyphs[164] = { --'§'--
  num = 164,
  adv = 8,
  oxn =   -2, oyn =   -1, oxp =   10, oyp =   11,
  txn =  141, tyn =  106, txp =  153, typ =  118,
}
glyphs[165] = { --'•'--
  num = 165,
  adv = 8,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   12,
  txn =  161, tyn =  106, txp =  173, typ =  120,
}
glyphs[166] = { --'¶'--
  num = 166,
  adv = 4,
  oxn =   -1, oyn =   -5, oxp =    5, oyp =   13,
  txn =  181, tyn =  106, txp =  187, typ =  124,
}
glyphs[167] = { --'ß'--
  num = 167,
  adv = 8,
  oxn =   -2, oyn =   -5, oxp =   10, oyp =   13,
  txn =  201, tyn =  106, txp =  213, typ =  124,
}
glyphs[168] = { --'®'--
  num = 168,
  adv = 5,
  oxn =   -2, oyn =    6, oxp =    7, oyp =   13,
  txn =  221, tyn =  106, txp =  230, typ =  113,
}
glyphs[169] = { --'©'--
  num = 169,
  adv = 10,
  oxn =   -3, oyn =   -3, oxp =   13, oyp =   13,
  txn =  241, tyn =  106, txp =  257, typ =  122,
}
glyphs[170] = { --'™'--
  num = 170,
  adv = 5,
  oxn =   -2, oyn =    1, oxp =    7, oyp =   13,
  txn =  261, tyn =  106, txp =  270, typ =  118,
}
glyphs[171] = { --'´'--
  num = 171,
  adv = 8,
  oxn =   -1, oyn =   -1, oxp =    9, oyp =    9,
  txn =  281, tyn =  106, txp =  291, typ =  116,
}
glyphs[172] = { --'¨'--
  num = 172,
  adv = 8,
  oxn =   -2, oyn =   -1, oxp =   10, oyp =    8,
  txn =  301, tyn =  106, txp =  313, typ =  115,
}
glyphs[173] = { --'≠'--
  num = 173,
  adv = 6,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   12,
  txn =  321, tyn =  106, txp =  330, typ =  120,
}
glyphs[174] = { --'Æ'--
  num = 174,
  adv = 10,
  oxn =   -3, oyn =   -3, oxp =   13, oyp =   13,
  txn =  341, tyn =  106, txp =  357, typ =  122,
}
glyphs[175] = { --'Ø'--
  num = 175,
  adv = 5,
  oxn =   -2, oyn =    6, oxp =    7, oyp =   13,
  txn =  361, tyn =  106, txp =  370, typ =  113,
}
glyphs[176] = { --'∞'--
  num = 176,
  adv = 8,
  oxn =    0, oyn =    3, oxp =    9, oyp =   12,
  txn =  381, tyn =  106, txp =  390, typ =  115,
}
glyphs[177] = { --'±'--
  num = 177,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   11,
  txn =  401, tyn =  106, txp =  413, typ =  120,
}
glyphs[178] = { --'≤'--
  num = 178,
  adv = 5,
  oxn =   -2, oyn =    1, oxp =    7, oyp =   13,
  txn =  421, tyn =  106, txp =  430, typ =  118,
}
glyphs[179] = { --'≥'--
  num = 179,
  adv = 5,
  oxn =   -2, oyn =    1, oxp =    7, oyp =   13,
  txn =  441, tyn =  106, txp =  450, typ =  118,
}
glyphs[180] = { --'¥'--
  num = 180,
  adv = 5,
  oxn =   -1, oyn =    6, oxp =    7, oyp =   13,
  txn =  461, tyn =  106, txp =  469, typ =  113,
}
glyphs[181] = { --'µ'--
  num = 181,
  adv = 9,
  oxn =   -2, oyn =   -6, oxp =   11, oyp =   10,
  txn =  481, tyn =  106, txp =  494, typ =  122,
}
glyphs[182] = { --'∂'--
  num = 182,
  adv = 8,
  oxn =   -2, oyn =   -5, oxp =   10, oyp =   13,
  txn =    1, tyn =  127, txp =   13, typ =  145,
}
glyphs[183] = { --'∑'--
  num = 183,
  adv = 4,
  oxn =   -2, oyn =    0, oxp =    5, oyp =    7,
  txn =   21, tyn =  127, txp =   28, typ =  134,
}
glyphs[184] = { --'∏'--
  num = 184,
  adv = 5,
  oxn =   -2, oyn =   -6, oxp =    7, oyp =    2,
  txn =   41, tyn =  127, txp =   50, typ =  135,
}
glyphs[185] = { --'π'--
  num = 185,
  adv = 5,
  oxn =   -2, oyn =    1, oxp =    6, oyp =   12,
  txn =   61, tyn =  127, txp =   69, typ =  138,
}
glyphs[186] = { --'∫'--
  num = 186,
  adv = 5,
  oxn =   -2, oyn =    1, oxp =    7, oyp =   13,
  txn =   81, tyn =  127, txp =   90, typ =  139,
}
glyphs[187] = { --'ª'--
  num = 187,
  adv = 8,
  oxn =   -1, oyn =   -1, oxp =    9, oyp =    9,
  txn =  101, tyn =  127, txp =  111, typ =  137,
}
glyphs[188] = { --'º'--
  num = 188,
  adv = 12,
  oxn =   -2, oyn =   -3, oxp =   14, oyp =   13,
  txn =  121, tyn =  127, txp =  137, typ =  143,
}
glyphs[189] = { --'Ω'--
  num = 189,
  adv = 12,
  oxn =   -2, oyn =   -3, oxp =   14, oyp =   13,
  txn =  141, tyn =  127, txp =  157, typ =  143,
}
glyphs[190] = { --'æ'--
  num = 190,
  adv = 12,
  oxn =   -2, oyn =   -3, oxp =   14, oyp =   13,
  txn =  161, tyn =  127, txp =  177, typ =  143,
}
glyphs[191] = { --'ø'--
  num = 191,
  adv = 9,
  oxn =   -2, oyn =   -5, oxp =   10, oyp =   10,
  txn =  181, tyn =  127, txp =  193, typ =  142,
}
glyphs[192] = { --'¿'--
  num = 192,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   16,
  txn =  201, tyn =  127, txp =  215, typ =  145,
}
glyphs[193] = { --'¡'--
  num = 193,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   15,
  txn =  221, tyn =  127, txp =  235, typ =  144,
}
glyphs[194] = { --'¬'--
  num = 194,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   16,
  txn =  241, tyn =  127, txp =  255, typ =  145,
}
glyphs[195] = { --'√'--
  num = 195,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   16,
  txn =  261, tyn =  127, txp =  275, typ =  145,
}
glyphs[196] = { --'ƒ'--
  num = 196,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   16,
  txn =  281, tyn =  127, txp =  295, typ =  145,
}
glyphs[197] = { --'≈'--
  num = 197,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   16,
  txn =  301, tyn =  127, txp =  315, typ =  145,
}
glyphs[198] = { --'∆'--
  num = 198,
  adv = 14,
  oxn =   -2, oyn =   -2, oxp =   16, oyp =   13,
  txn =  321, tyn =  127, txp =  339, typ =  142,
}
glyphs[199] = { --'«'--
  num = 199,
  adv = 10,
  oxn =   -2, oyn =   -6, oxp =   12, oyp =   13,
  txn =  341, tyn =  127, txp =  355, typ =  146,
}
glyphs[200] = { --'»'--
  num = 200,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =   11, oyp =   16,
  txn =  361, tyn =  127, txp =  373, typ =  145,
}
glyphs[201] = { --'…'--
  num = 201,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =   11, oyp =   16,
  txn =  381, tyn =  127, txp =  393, typ =  145,
}
glyphs[202] = { --' '--
  num = 202,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =   11, oyp =   16,
  txn =  401, tyn =  127, txp =  413, typ =  145,
}
glyphs[203] = { --'À'--
  num = 203,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =   11, oyp =   16,
  txn =  421, tyn =  127, txp =  433, typ =  145,
}
glyphs[204] = { --'Ã'--
  num = 204,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    5, oyp =   16,
  txn =  441, tyn =  127, txp =  448, typ =  145,
}
glyphs[205] = { --'Õ'--
  num = 205,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   16,
  txn =  461, tyn =  127, txp =  470, typ =  145,
}
glyphs[206] = { --'Œ'--
  num = 206,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   16,
  txn =  481, tyn =  127, txp =  490, typ =  145,
}
glyphs[207] = { --'œ'--
  num = 207,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   16,
  txn =    1, tyn =  148, txp =   10, typ =  166,
}
glyphs[208] = { --'–'--
  num = 208,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   13,
  txn =   21, tyn =  148, txp =   35, typ =  163,
}
glyphs[209] = { --'—'--
  num = 209,
  adv = 10,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   16,
  txn =   41, tyn =  148, txp =   55, typ =  166,
}
glyphs[210] = { --'“'--
  num = 210,
  adv = 11,
  oxn =   -2, oyn =   -3, oxp =   13, oyp =   16,
  txn =   61, tyn =  148, txp =   76, typ =  167,
}
glyphs[211] = { --'”'--
  num = 211,
  adv = 11,
  oxn =   -2, oyn =   -3, oxp =   13, oyp =   16,
  txn =   81, tyn =  148, txp =   96, typ =  167,
}
glyphs[212] = { --'‘'--
  num = 212,
  adv = 11,
  oxn =   -2, oyn =   -3, oxp =   13, oyp =   16,
  txn =  101, tyn =  148, txp =  116, typ =  167,
}
glyphs[213] = { --'’'--
  num = 213,
  adv = 11,
  oxn =   -2, oyn =   -3, oxp =   13, oyp =   16,
  txn =  121, tyn =  148, txp =  136, typ =  167,
}
glyphs[214] = { --'÷'--
  num = 214,
  adv = 11,
  oxn =   -2, oyn =   -3, oxp =   13, oyp =   16,
  txn =  141, tyn =  148, txp =  156, typ =  167,
}
glyphs[215] = { --'◊'--
  num = 215,
  adv = 8,
  oxn =   -1, oyn =   -2, oxp =   10, oyp =    9,
  txn =  161, tyn =  148, txp =  172, typ =  159,
}
glyphs[216] = { --'ÿ'--
  num = 216,
  adv = 11,
  oxn =   -2, oyn =   -3, oxp =   13, oyp =   13,
  txn =  181, tyn =  148, txp =  196, typ =  164,
}
glyphs[217] = { --'Ÿ'--
  num = 217,
  adv = 10,
  oxn =   -1, oyn =   -3, oxp =   12, oyp =   16,
  txn =  201, tyn =  148, txp =  214, typ =  167,
}
glyphs[218] = { --'⁄'--
  num = 218,
  adv = 10,
  oxn =   -1, oyn =   -3, oxp =   12, oyp =   16,
  txn =  221, tyn =  148, txp =  234, typ =  167,
}
glyphs[219] = { --'€'--
  num = 219,
  adv = 10,
  oxn =   -1, oyn =   -3, oxp =   12, oyp =   16,
  txn =  241, tyn =  148, txp =  254, typ =  167,
}
glyphs[220] = { --'‹'--
  num = 220,
  adv = 10,
  oxn =   -1, oyn =   -3, oxp =   12, oyp =   16,
  txn =  261, tyn =  148, txp =  274, typ =  167,
}
glyphs[221] = { --'›'--
  num = 221,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   12, oyp =   16,
  txn =  281, tyn =  148, txp =  295, typ =  166,
}
glyphs[222] = { --'ﬁ'--
  num = 222,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =   11, oyp =   13,
  txn =  301, tyn =  148, txp =  313, typ =  163,
}
glyphs[223] = { --'ﬂ'--
  num = 223,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   11, oyp =   13,
  txn =  321, tyn =  148, txp =  334, typ =  164,
}
glyphs[224] = { --'‡'--
  num = 224,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  341, tyn =  148, txp =  353, typ =  164,
}
glyphs[225] = { --'·'--
  num = 225,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  361, tyn =  148, txp =  373, typ =  164,
}
glyphs[226] = { --'‚'--
  num = 226,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  381, tyn =  148, txp =  393, typ =  164,
}
glyphs[227] = { --'„'--
  num = 227,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  401, tyn =  148, txp =  413, typ =  164,
}
glyphs[228] = { --'‰'--
  num = 228,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  421, tyn =  148, txp =  433, typ =  164,
}
glyphs[229] = { --'Â'--
  num = 229,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  441, tyn =  148, txp =  453, typ =  164,
}
glyphs[230] = { --'Ê'--
  num = 230,
  adv = 12,
  oxn =   -2, oyn =   -3, oxp =   14, oyp =   10,
  txn =  461, tyn =  148, txp =  477, typ =  161,
}
glyphs[231] = { --'Á'--
  num = 231,
  adv = 8,
  oxn =   -2, oyn =   -6, oxp =   10, oyp =   10,
  txn =  481, tyn =  148, txp =  493, typ =  164,
}
glyphs[232] = { --'Ë'--
  num = 232,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =    1, tyn =  169, txp =   13, typ =  185,
}
glyphs[233] = { --'È'--
  num = 233,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =   21, tyn =  169, txp =   33, typ =  185,
}
glyphs[234] = { --'Í'--
  num = 234,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =   41, tyn =  169, txp =   53, typ =  185,
}
glyphs[235] = { --'Î'--
  num = 235,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =   61, tyn =  169, txp =   73, typ =  185,
}
glyphs[236] = { --'Ï'--
  num = 236,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    5, oyp =   13,
  txn =   81, tyn =  169, txp =   88, typ =  184,
}
glyphs[237] = { --'Ì'--
  num = 237,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   13,
  txn =  101, tyn =  169, txp =  110, typ =  184,
}
glyphs[238] = { --'Ó'--
  num = 238,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   13,
  txn =  121, tyn =  169, txp =  130, typ =  184,
}
glyphs[239] = { --'Ô'--
  num = 239,
  adv = 4,
  oxn =   -2, oyn =   -2, oxp =    7, oyp =   13,
  txn =  141, tyn =  169, txp =  150, typ =  184,
}
glyphs[240] = { --''--
  num = 240,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  161, tyn =  169, txp =  173, typ =  185,
}
glyphs[241] = { --'Ò'--
  num = 241,
  adv = 9,
  oxn =   -2, oyn =   -2, oxp =   10, oyp =   13,
  txn =  181, tyn =  169, txp =  193, typ =  184,
}
glyphs[242] = { --'Ú'--
  num = 242,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  201, tyn =  169, txp =  213, typ =  185,
}
glyphs[243] = { --'Û'--
  num = 243,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  221, tyn =  169, txp =  233, typ =  185,
}
glyphs[244] = { --'Ù'--
  num = 244,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  241, tyn =  169, txp =  253, typ =  185,
}
glyphs[245] = { --'ı'--
  num = 245,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  261, tyn =  169, txp =  273, typ =  185,
}
glyphs[246] = { --'ˆ'--
  num = 246,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  281, tyn =  169, txp =  293, typ =  185,
}
glyphs[247] = { --'˜'--
  num = 247,
  adv = 8,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =    9,
  txn =  301, tyn =  169, txp =  313, typ =  181,
}
glyphs[248] = { --'¯'--
  num = 248,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   11, oyp =   10,
  txn =  321, tyn =  169, txp =  334, typ =  182,
}
glyphs[249] = { --'˘'--
  num = 249,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  341, tyn =  169, txp =  353, typ =  185,
}
glyphs[250] = { --'˙'--
  num = 250,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  361, tyn =  169, txp =  373, typ =  185,
}
glyphs[251] = { --'˚'--
  num = 251,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  381, tyn =  169, txp =  393, typ =  185,
}
glyphs[252] = { --'¸'--
  num = 252,
  adv = 9,
  oxn =   -2, oyn =   -3, oxp =   10, oyp =   13,
  txn =  401, tyn =  169, txp =  413, typ =  185,
}
glyphs[253] = { --'˝'--
  num = 253,
  adv = 8,
  oxn =   -2, oyn =   -6, oxp =   10, oyp =   13,
  txn =  421, tyn =  169, txp =  433, typ =  188,
}
glyphs[254] = { --'˛'--
  num = 254,
  adv = 9,
  oxn =   -2, oyn =   -6, oxp =   11, oyp =   13,
  txn =  441, tyn =  169, txp =  454, typ =  188,
}
glyphs[255] = { --'ˇ'--
  num = 255,
  adv = 8,
  oxn =   -2, oyn =   -6, oxp =   10, oyp =   13,
  txn =  461, tyn =  169, txp =  473, typ =  188,
}

fontSpecs.glyphs = glyphs

return fontSpecs

