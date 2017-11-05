
local fontSpecs = {
  srcFile  = [[Skrawl.ttf]],
  family   = [[Skrawl]],
  style    = [[Regular]],
  yStep    = 45,
  height   = 40,
  xTexSize = 512,
  yTexSize = 1024,
  outlineRadius = 1,
  outlineWeight = 100,
}

local glyphs = {}

glyphs[32] = { --' '--
  num = 32,
  adv = 14,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =    1, tyn =    1, txp =    4, typ =    4,
}
glyphs[33] = { --'!'--
  num = 33,
  adv = 13,
  oxn =   -1, oyn =   -1, oxp =   10, oyp =   41,
  txn =   41, tyn =    1, txp =   52, typ =   43,
}
glyphs[34] = { --'"'--
  num = 34,
  adv = 12,
  oxn =    0, oyn =   24, oxp =   11, oyp =   40,
  txn =   81, tyn =    1, txp =   92, typ =   17,
}
glyphs[35] = { --'#'--
  num = 35,
  adv = 26,
  oxn =   -1, oyn =   -1, oxp =   23, oyp =   35,
  txn =  121, tyn =    1, txp =  145, typ =   37,
}
glyphs[36] = { --'$'--
  num = 36,
  adv = 21,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   39,
  txn =  161, tyn =    1, txp =  183, typ =   41,
}
glyphs[37] = { --'%'--
  num = 37,
  adv = 31,
  oxn =   -1, oyn =   -1, oxp =   34, oyp =   34,
  txn =  201, tyn =    1, txp =  236, typ =   36,
}
glyphs[38] = { --'&'--
  num = 38,
  adv = 33,
  oxn =   -1, oyn =   -1, oxp =   25, oyp =   38,
  txn =  241, tyn =    1, txp =  267, typ =   40,
}
glyphs[39] = { --'''--
  num = 39,
  adv = 6,
  oxn =   -1, oyn =   26, oxp =    7, oyp =   37,
  txn =  281, tyn =    1, txp =  289, typ =   12,
}
glyphs[40] = { --'('--
  num = 40,
  adv = 15,
  oxn =   -1, oyn =   -5, oxp =   12, oyp =   35,
  txn =  321, tyn =    1, txp =  334, typ =   41,
}
glyphs[41] = { --')'--
  num = 41,
  adv = 15,
  oxn =    0, oyn =   -3, oxp =   13, oyp =   36,
  txn =  361, tyn =    1, txp =  374, typ =   40,
}
glyphs[42] = { --'*'--
  num = 42,
  adv = 20,
  oxn =    1, oyn =   18, oxp =   20, oyp =   37,
  txn =  401, tyn =    1, txp =  420, typ =   20,
}
glyphs[43] = { --'+'--
  num = 43,
  adv = 20,
  oxn =    1, oyn =    4, oxp =   19, oyp =   23,
  txn =  441, tyn =    1, txp =  459, typ =   20,
}
glyphs[44] = { --','--
  num = 44,
  adv = 11,
  oxn =    0, oyn =   -6, oxp =   10, oyp =    9,
  txn =    1, tyn =   45, txp =   11, typ =   60,
}
glyphs[45] = { --'-'--
  num = 45,
  adv = 13,
  oxn =   -1, oyn =    9, oxp =   13, oyp =   16,
  txn =   41, tyn =   45, txp =   55, typ =   52,
}
glyphs[46] = { --'.'--
  num = 46,
  adv = 9,
  oxn =   -1, oyn =   -2, oxp =    9, oyp =    8,
  txn =   81, tyn =   45, txp =   91, typ =   55,
}
glyphs[47] = { --'/'--
  num = 47,
  adv = 11,
  oxn =   -2, oyn =   -2, oxp =   15, oyp =   34,
  txn =  121, tyn =   45, txp =  138, typ =   81,
}
glyphs[48] = { --'0'--
  num = 48,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   31,
  txn =  161, tyn =   45, txp =  182, typ =   77,
}
glyphs[49] = { --'1'--
  num = 49,
  adv = 8,
  oxn =   -1, oyn =   -1, oxp =    8, oyp =   35,
  txn =  201, tyn =   45, txp =  210, typ =   81,
}
glyphs[50] = { --'2'--
  num = 50,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   32,
  txn =  241, tyn =   45, txp =  262, typ =   78,
}
glyphs[51] = { --'3'--
  num = 51,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   32,
  txn =  281, tyn =   45, txp =  302, typ =   78,
}
glyphs[52] = { --'4'--
  num = 52,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   32,
  txn =  321, tyn =   45, txp =  343, typ =   78,
}
glyphs[53] = { --'5'--
  num = 53,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   31,
  txn =  361, tyn =   45, txp =  383, typ =   77,
}
glyphs[54] = { --'6'--
  num = 54,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   35,
  txn =  401, tyn =   45, txp =  423, typ =   81,
}
glyphs[55] = { --'7'--
  num = 55,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   32,
  txn =  441, tyn =   45, txp =  462, typ =   78,
}
glyphs[56] = { --'8'--
  num = 56,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   33,
  txn =    1, tyn =   89, txp =   22, typ =  123,
}
glyphs[57] = { --'9'--
  num = 57,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   19, oyp =   31,
  txn =   41, tyn =   89, txp =   61, typ =  121,
}
glyphs[58] = { --':'--
  num = 58,
  adv = 11,
  oxn =   -1, oyn =   -1, oxp =   10, oyp =   27,
  txn =   81, tyn =   89, txp =   92, typ =  117,
}
glyphs[59] = { --';'--
  num = 59,
  adv = 11,
  oxn =    0, oyn =   -8, oxp =   12, oyp =   26,
  txn =  121, tyn =   89, txp =  133, typ =  123,
}
glyphs[60] = { --'<'--
  num = 60,
  adv = 20,
  oxn =   -1, oyn =    4, oxp =   21, oyp =   27,
  txn =  161, tyn =   89, txp =  183, typ =  112,
}
glyphs[61] = { --'='--
  num = 61,
  adv = 20,
  oxn =    0, oyn =    6, oxp =   20, oyp =   18,
  txn =  201, tyn =   89, txp =  221, typ =  101,
}
glyphs[62] = { --'>'--
  num = 62,
  adv = 20,
  oxn =   -1, oyn =    4, oxp =   20, oyp =   27,
  txn =  241, tyn =   89, txp =  262, typ =  112,
}
glyphs[63] = { --'?'--
  num = 63,
  adv = 15,
  oxn =   -1, oyn =   -2, oxp =   17, oyp =   38,
  txn =  281, tyn =   89, txp =  299, typ =  129,
}
glyphs[64] = { --'@'--
  num = 64,
  adv = 39,
  oxn =    0, oyn =   -1, oxp =   38, oyp =   34,
  txn =  321, tyn =   89, txp =  359, typ =  124,
}
glyphs[65] = { --'A'--
  num = 65,
  adv = 22,
  oxn =   -5, oyn =   -1, oxp =   22, oyp =   38,
  txn =  361, tyn =   89, txp =  388, typ =  128,
}
glyphs[66] = { --'B'--
  num = 66,
  adv = 25,
  oxn =   -2, oyn =   -1, oxp =   27, oyp =   37,
  txn =  401, tyn =   89, txp =  430, typ =  127,
}
glyphs[67] = { --'C'--
  num = 67,
  adv = 25,
  oxn =    0, oyn =   -1, oxp =   26, oyp =   35,
  txn =  441, tyn =   89, txp =  467, typ =  125,
}
glyphs[68] = { --'D'--
  num = 68,
  adv = 23,
  oxn =   -1, oyn =   -1, oxp =   24, oyp =   36,
  txn =    1, tyn =  133, txp =   26, typ =  170,
}
glyphs[69] = { --'E'--
  num = 69,
  adv = 26,
  oxn =   -1, oyn =   -2, oxp =   26, oyp =   37,
  txn =   41, tyn =  133, txp =   68, typ =  172,
}
glyphs[70] = { --'F'--
  num = 70,
  adv = 24,
  oxn =   -1, oyn =   -1, oxp =   23, oyp =   38,
  txn =   81, tyn =  133, txp =  105, typ =  172,
}
glyphs[71] = { --'G'--
  num = 71,
  adv = 26,
  oxn =    0, oyn =   -1, oxp =   25, oyp =   38,
  txn =  121, tyn =  133, txp =  146, typ =  172,
}
glyphs[72] = { --'H'--
  num = 72,
  adv = 24,
  oxn =   -4, oyn =   -1, oxp =   23, oyp =   38,
  txn =  161, tyn =  133, txp =  188, typ =  172,
}
glyphs[73] = { --'I'--
  num = 73,
  adv = 23,
  oxn =   -1, oyn =   -1, oxp =   24, oyp =   38,
  txn =  201, tyn =  133, txp =  226, typ =  172,
}
glyphs[74] = { --'J'--
  num = 74,
  adv = 22,
  oxn =   -1, oyn =   -1, oxp =   22, oyp =   38,
  txn =  241, tyn =  133, txp =  264, typ =  172,
}
glyphs[75] = { --'K'--
  num = 75,
  adv = 21,
  oxn =   -1, oyn =   -1, oxp =   22, oyp =   38,
  txn =  281, tyn =  133, txp =  304, typ =  172,
}
glyphs[76] = { --'L'--
  num = 76,
  adv = 25,
  oxn =   -1, oyn =   -1, oxp =   25, oyp =   38,
  txn =  321, tyn =  133, txp =  347, typ =  172,
}
glyphs[77] = { --'M'--
  num = 77,
  adv = 22,
  oxn =   -1, oyn =   -1, oxp =   22, oyp =   38,
  txn =  361, tyn =  133, txp =  384, typ =  172,
}
glyphs[78] = { --'N'--
  num = 78,
  adv = 22,
  oxn =    0, oyn =   -1, oxp =   23, oyp =   38,
  txn =  401, tyn =  133, txp =  424, typ =  172,
}
glyphs[79] = { --'O'--
  num = 79,
  adv = 24,
  oxn =   -1, oyn =   -1, oxp =   23, oyp =   35,
  txn =  441, tyn =  133, txp =  465, typ =  169,
}
glyphs[80] = { --'P'--
  num = 80,
  adv = 24,
  oxn =   -1, oyn =   -1, oxp =   24, oyp =   38,
  txn =    1, tyn =  177, txp =   26, typ =  216,
}
glyphs[81] = { --'Q'--
  num = 81,
  adv = 25,
  oxn =   -1, oyn =   -1, oxp =   25, oyp =   38,
  txn =   41, tyn =  177, txp =   67, typ =  216,
}
glyphs[82] = { --'R'--
  num = 82,
  adv = 23,
  oxn =   -1, oyn =   -1, oxp =   23, oyp =   38,
  txn =   81, tyn =  177, txp =  105, typ =  216,
}
glyphs[83] = { --'S'--
  num = 83,
  adv = 23,
  oxn =   -1, oyn =   -1, oxp =   25, oyp =   39,
  txn =  121, tyn =  177, txp =  147, typ =  217,
}
glyphs[84] = { --'T'--
  num = 84,
  adv = 22,
  oxn =   -1, oyn =   -1, oxp =   23, oyp =   38,
  txn =  161, tyn =  177, txp =  185, typ =  216,
}
glyphs[85] = { --'U'--
  num = 85,
  adv = 22,
  oxn =   -1, oyn =   -1, oxp =   22, oyp =   39,
  txn =  201, tyn =  177, txp =  224, typ =  217,
}
glyphs[86] = { --'V'--
  num = 86,
  adv = 22,
  oxn =   -1, oyn =   -1, oxp =   22, oyp =   37,
  txn =  241, tyn =  177, txp =  264, typ =  215,
}
glyphs[87] = { --'W'--
  num = 87,
  adv = 24,
  oxn =   -1, oyn =   -1, oxp =   24, oyp =   37,
  txn =  281, tyn =  177, txp =  306, typ =  215,
}
glyphs[88] = { --'X'--
  num = 88,
  adv = 23,
  oxn =   -1, oyn =   -1, oxp =   24, oyp =   39,
  txn =  321, tyn =  177, txp =  346, typ =  217,
}
glyphs[89] = { --'Y'--
  num = 89,
  adv = 22,
  oxn =   -1, oyn =   -1, oxp =   23, oyp =   38,
  txn =  361, tyn =  177, txp =  385, typ =  216,
}
glyphs[90] = { --'Z'--
  num = 90,
  adv = 21,
  oxn =   -1, oyn =   -1, oxp =   24, oyp =   38,
  txn =  401, tyn =  177, txp =  426, typ =  216,
}
glyphs[91] = { --'['--
  num = 91,
  adv = 15,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  441, tyn =  177, txp =  444, typ =  180,
}
glyphs[92] = { --'\'--
  num = 92,
  adv = 11,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =    1, tyn =  221, txp =    4, typ =  224,
}
glyphs[93] = { --']'--
  num = 93,
  adv = 15,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   41, tyn =  221, txp =   44, typ =  224,
}
glyphs[94] = { --'^'--
  num = 94,
  adv = 20,
  oxn =   -1, oyn =   16, oxp =   20, oyp =   36,
  txn =   81, tyn =  221, txp =  102, typ =  241,
}
glyphs[95] = { --'_'--
  num = 95,
  adv = 20,
  oxn =   -2, oyn =   -2, oxp =   24, oyp =    3,
  txn =  121, tyn =  221, txp =  147, typ =  226,
}
glyphs[96] = { --'`'--
  num = 96,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  161, tyn =  221, txp =  181, typ =  252,
}
glyphs[97] = { --'a'--
  num = 97,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   26,
  txn =  201, tyn =  221, txp =  222, typ =  248,
}
glyphs[98] = { --'b'--
  num = 98,
  adv = 19,
  oxn =   -2, oyn =   -1, oxp =   20, oyp =   34,
  txn =  241, tyn =  221, txp =  263, typ =  256,
}
glyphs[99] = { --'c'--
  num = 99,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   27,
  txn =  281, tyn =  221, txp =  303, typ =  249,
}
glyphs[100] = { --'d'--
  num = 100,
  adv = 20,
  oxn =   -1, oyn =    0, oxp =   21, oyp =   36,
  txn =  321, tyn =  221, txp =  343, typ =  257,
}
glyphs[101] = { --'e'--
  num = 101,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   27,
  txn =  361, tyn =  221, txp =  383, typ =  249,
}
glyphs[102] = { --'f'--
  num = 102,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   36,
  txn =  401, tyn =  221, txp =  423, typ =  258,
}
glyphs[103] = { --'g'--
  num = 103,
  adv = 20,
  oxn =   -1, oyn =   -5, oxp =   21, oyp =   27,
  txn =  441, tyn =  221, txp =  463, typ =  253,
}
glyphs[104] = { --'h'--
  num = 104,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   36,
  txn =    1, tyn =  265, txp =   22, typ =  302,
}
glyphs[105] = { --'i'--
  num = 105,
  adv = 11,
  oxn =   -1, oyn =   -1, oxp =   11, oyp =   32,
  txn =   41, tyn =  265, txp =   53, typ =  298,
}
glyphs[106] = { --'j'--
  num = 106,
  adv = 13,
  oxn =   -1, oyn =   -5, oxp =   14, oyp =   30,
  txn =   81, tyn =  265, txp =   96, typ =  300,
}
glyphs[107] = { --'k'--
  num = 107,
  adv = 18,
  oxn =   -1, oyn =   -1, oxp =   18, oyp =   31,
  txn =  121, tyn =  265, txp =  140, typ =  297,
}
glyphs[108] = { --'l'--
  num = 108,
  adv = 10,
  oxn =   -1, oyn =   -1, oxp =    8, oyp =   37,
  txn =  161, tyn =  265, txp =  170, typ =  303,
}
glyphs[109] = { --'m'--
  num = 109,
  adv = 21,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   27,
  txn =  201, tyn =  265, txp =  223, typ =  293,
}
glyphs[110] = { --'n'--
  num = 110,
  adv = 22,
  oxn =   -1, oyn =   -1, oxp =   22, oyp =   26,
  txn =  241, tyn =  265, txp =  264, typ =  292,
}
glyphs[111] = { --'o'--
  num = 111,
  adv = 22,
  oxn =   -1, oyn =   -1, oxp =   22, oyp =   26,
  txn =  281, tyn =  265, txp =  304, typ =  292,
}
glyphs[112] = { --'p'--
  num = 112,
  adv = 20,
  oxn =   -1, oyn =   -7, oxp =   21, oyp =   23,
  txn =  321, tyn =  265, txp =  343, typ =  295,
}
glyphs[113] = { --'q'--
  num = 113,
  adv = 20,
  oxn =   -1, oyn =   -5, oxp =   21, oyp =   23,
  txn =  361, tyn =  265, txp =  383, typ =  293,
}
glyphs[114] = { --'r'--
  num = 114,
  adv = 16,
  oxn =   -1, oyn =   -1, oxp =   16, oyp =   26,
  txn =  401, tyn =  265, txp =  418, typ =  292,
}
glyphs[115] = { --'s'--
  num = 115,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   27,
  txn =  441, tyn =  265, txp =  462, typ =  293,
}
glyphs[116] = { --'t'--
  num = 116,
  adv = 19,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   33,
  txn =    1, tyn =  309, txp =   22, typ =  343,
}
glyphs[117] = { --'u'--
  num = 117,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   26,
  txn =   41, tyn =  309, txp =   62, typ =  336,
}
glyphs[118] = { --'v'--
  num = 118,
  adv = 19,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   26,
  txn =   81, tyn =  309, txp =  102, typ =  336,
}
glyphs[119] = { --'w'--
  num = 119,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   27,
  txn =  121, tyn =  309, txp =  143, typ =  337,
}
glyphs[120] = { --'x'--
  num = 120,
  adv = 20,
  oxn =   -1, oyn =   -1, oxp =   20, oyp =   27,
  txn =  161, tyn =  309, txp =  182, typ =  337,
}
glyphs[121] = { --'y'--
  num = 121,
  adv = 20,
  oxn =   -1, oyn =   -7, oxp =   20, oyp =   26,
  txn =  201, tyn =  309, txp =  222, typ =  342,
}
glyphs[122] = { --'z'--
  num = 122,
  adv = 21,
  oxn =   -1, oyn =   -1, oxp =   21, oyp =   22,
  txn =  241, tyn =  309, txp =  263, typ =  332,
}
glyphs[123] = { --'{'--
  num = 123,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  281, tyn =  309, txp =  284, typ =  312,
}
glyphs[124] = { --'|'--
  num = 124,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  321, tyn =  309, txp =  324, typ =  312,
}
glyphs[125] = { --'}'--
  num = 125,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  361, tyn =  309, txp =  364, typ =  312,
}
glyphs[126] = { --'~'--
  num = 126,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  401, tyn =  309, txp =  404, typ =  312,
}
glyphs[127] = { --''--
  num = 127,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  441, tyn =  309, txp =  461, typ =  340,
}
glyphs[128] = { --'Ä'--
  num = 128,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =    1, tyn =  353, txp =   21, typ =  384,
}
glyphs[129] = { --'Å'--
  num = 129,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =   41, tyn =  353, txp =   61, typ =  384,
}
glyphs[130] = { --'Ç'--
  num = 130,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =   81, tyn =  353, txp =  101, typ =  384,
}
glyphs[131] = { --'É'--
  num = 131,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  121, tyn =  353, txp =  141, typ =  384,
}
glyphs[132] = { --'Ñ'--
  num = 132,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  161, tyn =  353, txp =  181, typ =  384,
}
glyphs[133] = { --'Ö'--
  num = 133,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  201, tyn =  353, txp =  221, typ =  384,
}
glyphs[134] = { --'Ü'--
  num = 134,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  241, tyn =  353, txp =  261, typ =  384,
}
glyphs[135] = { --'á'--
  num = 135,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  281, tyn =  353, txp =  301, typ =  384,
}
glyphs[136] = { --'à'--
  num = 136,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  321, tyn =  353, txp =  341, typ =  384,
}
glyphs[137] = { --'â'--
  num = 137,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  361, tyn =  353, txp =  381, typ =  384,
}
glyphs[138] = { --'ä'--
  num = 138,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  401, tyn =  353, txp =  421, typ =  384,
}
glyphs[139] = { --'ã'--
  num = 139,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  441, tyn =  353, txp =  461, typ =  384,
}
glyphs[140] = { --'å'--
  num = 140,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =    1, tyn =  397, txp =   21, typ =  428,
}
glyphs[141] = { --'ç'--
  num = 141,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =   41, tyn =  397, txp =   61, typ =  428,
}
glyphs[142] = { --'é'--
  num = 142,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =   81, tyn =  397, txp =  101, typ =  428,
}
glyphs[143] = { --'è'--
  num = 143,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  121, tyn =  397, txp =  141, typ =  428,
}
glyphs[144] = { --'ê'--
  num = 144,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  161, tyn =  397, txp =  181, typ =  428,
}
glyphs[145] = { --'ë'--
  num = 145,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  201, tyn =  397, txp =  221, typ =  428,
}
glyphs[146] = { --'í'--
  num = 146,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  241, tyn =  397, txp =  261, typ =  428,
}
glyphs[147] = { --'ì'--
  num = 147,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  281, tyn =  397, txp =  301, typ =  428,
}
glyphs[148] = { --'î'--
  num = 148,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  321, tyn =  397, txp =  341, typ =  428,
}
glyphs[149] = { --'ï'--
  num = 149,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  361, tyn =  397, txp =  381, typ =  428,
}
glyphs[150] = { --'ñ'--
  num = 150,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  401, tyn =  397, txp =  421, typ =  428,
}
glyphs[151] = { --'ó'--
  num = 151,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  441, tyn =  397, txp =  461, typ =  428,
}
glyphs[152] = { --'ò'--
  num = 152,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =    1, tyn =  441, txp =   21, typ =  472,
}
glyphs[153] = { --'ô'--
  num = 153,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =   41, tyn =  441, txp =   61, typ =  472,
}
glyphs[154] = { --'ö'--
  num = 154,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =   81, tyn =  441, txp =  101, typ =  472,
}
glyphs[155] = { --'õ'--
  num = 155,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  121, tyn =  441, txp =  141, typ =  472,
}
glyphs[156] = { --'ú'--
  num = 156,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  161, tyn =  441, txp =  181, typ =  472,
}
glyphs[157] = { --'ù'--
  num = 157,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  201, tyn =  441, txp =  221, typ =  472,
}
glyphs[158] = { --'û'--
  num = 158,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  241, tyn =  441, txp =  261, typ =  472,
}
glyphs[159] = { --'ü'--
  num = 159,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  281, tyn =  441, txp =  301, typ =  472,
}
glyphs[160] = { --'†'--
  num = 160,
  adv = 14,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  321, tyn =  441, txp =  324, typ =  444,
}
glyphs[161] = { --'°'--
  num = 161,
  adv = 13,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  361, tyn =  441, txp =  364, typ =  444,
}
glyphs[162] = { --'¢'--
  num = 162,
  adv = 22,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  401, tyn =  441, txp =  404, typ =  444,
}
glyphs[163] = { --'£'--
  num = 163,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  441, tyn =  441, txp =  461, typ =  472,
}
glyphs[164] = { --'§'--
  num = 164,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =    1, tyn =  485, txp =   21, typ =  516,
}
glyphs[165] = { --'•'--
  num = 165,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =   41, tyn =  485, txp =   61, typ =  516,
}
glyphs[166] = { --'¶'--
  num = 166,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =   81, tyn =  485, txp =  101, typ =  516,
}
glyphs[167] = { --'ß'--
  num = 167,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  121, tyn =  485, txp =  141, typ =  516,
}
glyphs[168] = { --'®'--
  num = 168,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  161, tyn =  485, txp =  181, typ =  516,
}
glyphs[169] = { --'©'--
  num = 169,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  201, tyn =  485, txp =  221, typ =  516,
}
glyphs[170] = { --'™'--
  num = 170,
  adv = 13,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  241, tyn =  485, txp =  244, typ =  488,
}
glyphs[171] = { --'´'--
  num = 171,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  281, tyn =  485, txp =  301, typ =  516,
}
glyphs[172] = { --'¨'--
  num = 172,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  321, tyn =  485, txp =  341, typ =  516,
}
glyphs[173] = { --'≠'--
  num = 173,
  adv = 13,
  oxn =   -1, oyn =    9, oxp =   13, oyp =   16,
  txn =  361, tyn =  485, txp =  375, typ =  492,
}
glyphs[174] = { --'Æ'--
  num = 174,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  401, tyn =  485, txp =  421, typ =  516,
}
glyphs[175] = { --'Ø'--
  num = 175,
  adv = 13,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  441, tyn =  485, txp =  444, typ =  488,
}
glyphs[176] = { --'∞'--
  num = 176,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =    1, tyn =  529, txp =   21, typ =  560,
}
glyphs[177] = { --'±'--
  num = 177,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   41, tyn =  529, txp =   44, typ =  532,
}
glyphs[178] = { --'≤'--
  num = 178,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   81, tyn =  529, txp =   84, typ =  532,
}
glyphs[179] = { --'≥'--
  num = 179,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  121, tyn =  529, txp =  124, typ =  532,
}
glyphs[180] = { --'¥'--
  num = 180,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  161, tyn =  529, txp =  181, typ =  560,
}
glyphs[181] = { --'µ'--
  num = 181,
  adv = 23,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  201, tyn =  529, txp =  204, typ =  532,
}
glyphs[182] = { --'∂'--
  num = 182,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  241, tyn =  529, txp =  261, typ =  560,
}
glyphs[183] = { --'∑'--
  num = 183,
  adv = 10,
  oxn =    1, oyn =   10, oxp =    9, oyp =   18,
  txn =  281, tyn =  529, txp =  289, typ =  537,
}
glyphs[184] = { --'∏'--
  num = 184,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  321, tyn =  529, txp =  341, typ =  560,
}
glyphs[185] = { --'π'--
  num = 185,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  361, tyn =  529, txp =  364, typ =  532,
}
glyphs[186] = { --'∫'--
  num = 186,
  adv = 14,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  401, tyn =  529, txp =  404, typ =  532,
}
glyphs[187] = { --'ª'--
  num = 187,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  441, tyn =  529, txp =  461, typ =  560,
}
glyphs[188] = { --'º'--
  num = 188,
  adv = 33,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =    1, tyn =  573, txp =    4, typ =  576,
}
glyphs[189] = { --'Ω'--
  num = 189,
  adv = 38,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   41, tyn =  573, txp =   44, typ =  576,
}
glyphs[190] = { --'æ'--
  num = 190,
  adv = 33,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   81, tyn =  573, txp =   84, typ =  576,
}
glyphs[191] = { --'ø'--
  num = 191,
  adv = 15,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  121, tyn =  573, txp =  124, typ =  576,
}
glyphs[192] = { --'¿'--
  num = 192,
  adv = 30,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  161, tyn =  573, txp =  164, typ =  576,
}
glyphs[193] = { --'¡'--
  num = 193,
  adv = 30,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  201, tyn =  573, txp =  204, typ =  576,
}
glyphs[194] = { --'¬'--
  num = 194,
  adv = 30,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  241, tyn =  573, txp =  244, typ =  576,
}
glyphs[195] = { --'√'--
  num = 195,
  adv = 30,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  281, tyn =  573, txp =  284, typ =  576,
}
glyphs[196] = { --'ƒ'--
  num = 196,
  adv = 30,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  321, tyn =  573, txp =  324, typ =  576,
}
glyphs[197] = { --'≈'--
  num = 197,
  adv = 30,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  361, tyn =  573, txp =  364, typ =  576,
}
glyphs[198] = { --'∆'--
  num = 198,
  adv = 41,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  401, tyn =  573, txp =  404, typ =  576,
}
glyphs[199] = { --'«'--
  num = 199,
  adv = 27,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  441, tyn =  573, txp =  444, typ =  576,
}
glyphs[200] = { --'»'--
  num = 200,
  adv = 22,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =    1, tyn =  617, txp =    4, typ =  620,
}
glyphs[201] = { --'…'--
  num = 201,
  adv = 22,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   41, tyn =  617, txp =   44, typ =  620,
}
glyphs[202] = { --' '--
  num = 202,
  adv = 22,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   81, tyn =  617, txp =   84, typ =  620,
}
glyphs[203] = { --'À'--
  num = 203,
  adv = 22,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  121, tyn =  617, txp =  124, typ =  620,
}
glyphs[204] = { --'Ã'--
  num = 204,
  adv = 13,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  161, tyn =  617, txp =  164, typ =  620,
}
glyphs[205] = { --'Õ'--
  num = 205,
  adv = 13,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  201, tyn =  617, txp =  204, typ =  620,
}
glyphs[206] = { --'Œ'--
  num = 206,
  adv = 13,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  241, tyn =  617, txp =  244, typ =  620,
}
glyphs[207] = { --'œ'--
  num = 207,
  adv = 13,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  281, tyn =  617, txp =  284, typ =  620,
}
glyphs[208] = { --'–'--
  num = 208,
  adv = 30,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  321, tyn =  617, txp =  324, typ =  620,
}
glyphs[209] = { --'—'--
  num = 209,
  adv = 30,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  361, tyn =  617, txp =  364, typ =  620,
}
glyphs[210] = { --'“'--
  num = 210,
  adv = 32,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  401, tyn =  617, txp =  404, typ =  620,
}
glyphs[211] = { --'”'--
  num = 211,
  adv = 32,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  441, tyn =  617, txp =  444, typ =  620,
}
glyphs[212] = { --'‘'--
  num = 212,
  adv = 32,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =    1, tyn =  661, txp =    4, typ =  664,
}
glyphs[213] = { --'’'--
  num = 213,
  adv = 32,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   41, tyn =  661, txp =   44, typ =  664,
}
glyphs[214] = { --'÷'--
  num = 214,
  adv = 32,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   81, tyn =  661, txp =   84, typ =  664,
}
glyphs[215] = { --'◊'--
  num = 215,
  adv = 20,
  oxn =    2, oyn =    6, oxp =   18, oyp =   22,
  txn =  121, tyn =  661, txp =  137, typ =  677,
}
glyphs[216] = { --'ÿ'--
  num = 216,
  adv = 32,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  161, tyn =  661, txp =  164, typ =  664,
}
glyphs[217] = { --'Ÿ'--
  num = 217,
  adv = 29,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  201, tyn =  661, txp =  204, typ =  664,
}
glyphs[218] = { --'⁄'--
  num = 218,
  adv = 29,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  241, tyn =  661, txp =  244, typ =  664,
}
glyphs[219] = { --'€'--
  num = 219,
  adv = 29,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  281, tyn =  661, txp =  284, typ =  664,
}
glyphs[220] = { --'‹'--
  num = 220,
  adv = 29,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  321, tyn =  661, txp =  324, typ =  664,
}
glyphs[221] = { --'›'--
  num = 221,
  adv = 24,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  361, tyn =  661, txp =  364, typ =  664,
}
glyphs[222] = { --'ﬁ'--
  num = 222,
  adv = 22,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  401, tyn =  661, txp =  404, typ =  664,
}
glyphs[223] = { --'ﬂ'--
  num = 223,
  adv = 24,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  441, tyn =  661, txp =  444, typ =  664,
}
glyphs[224] = { --'‡'--
  num = 224,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =    1, tyn =  705, txp =    4, typ =  708,
}
glyphs[225] = { --'·'--
  num = 225,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   41, tyn =  705, txp =   44, typ =  708,
}
glyphs[226] = { --'‚'--
  num = 226,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   81, tyn =  705, txp =   84, typ =  708,
}
glyphs[227] = { --'„'--
  num = 227,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  121, tyn =  705, txp =  124, typ =  708,
}
glyphs[228] = { --'‰'--
  num = 228,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  161, tyn =  705, txp =  164, typ =  708,
}
glyphs[229] = { --'Â'--
  num = 229,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  201, tyn =  705, txp =  204, typ =  708,
}
glyphs[230] = { --'Ê'--
  num = 230,
  adv = 28,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  241, tyn =  705, txp =  244, typ =  708,
}
glyphs[231] = { --'Á'--
  num = 231,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  281, tyn =  705, txp =  284, typ =  708,
}
glyphs[232] = { --'Ë'--
  num = 232,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  321, tyn =  705, txp =  324, typ =  708,
}
glyphs[233] = { --'È'--
  num = 233,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  361, tyn =  705, txp =  364, typ =  708,
}
glyphs[234] = { --'Í'--
  num = 234,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  401, tyn =  705, txp =  404, typ =  708,
}
glyphs[235] = { --'Î'--
  num = 235,
  adv = 18,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  441, tyn =  705, txp =  444, typ =  708,
}
glyphs[236] = { --'Ï'--
  num = 236,
  adv = 10,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =    1, tyn =  749, txp =    4, typ =  752,
}
glyphs[237] = { --'Ì'--
  num = 237,
  adv = 10,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   41, tyn =  749, txp =   44, typ =  752,
}
glyphs[238] = { --'Ó'--
  num = 238,
  adv = 10,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   81, tyn =  749, txp =   84, typ =  752,
}
glyphs[239] = { --'Ô'--
  num = 239,
  adv = 10,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  121, tyn =  749, txp =  124, typ =  752,
}
glyphs[240] = { --''--
  num = 240,
  adv = 22,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  161, tyn =  749, txp =  164, typ =  752,
}
glyphs[241] = { --'Ò'--
  num = 241,
  adv = 22,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  201, tyn =  749, txp =  204, typ =  752,
}
glyphs[242] = { --'Ú'--
  num = 242,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  241, tyn =  749, txp =  244, typ =  752,
}
glyphs[243] = { --'Û'--
  num = 243,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  281, tyn =  749, txp =  284, typ =  752,
}
glyphs[244] = { --'Ù'--
  num = 244,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  321, tyn =  749, txp =  324, typ =  752,
}
glyphs[245] = { --'ı'--
  num = 245,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  361, tyn =  749, txp =  364, typ =  752,
}
glyphs[246] = { --'ˆ'--
  num = 246,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  401, tyn =  749, txp =  404, typ =  752,
}
glyphs[247] = { --'˜'--
  num = 247,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  441, tyn =  749, txp =  461, typ =  780,
}
glyphs[248] = { --'¯'--
  num = 248,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =    1, tyn =  793, txp =    4, typ =  796,
}
glyphs[249] = { --'˘'--
  num = 249,
  adv = 21,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   41, tyn =  793, txp =   44, typ =  796,
}
glyphs[250] = { --'˙'--
  num = 250,
  adv = 21,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =   81, tyn =  793, txp =   84, typ =  796,
}
glyphs[251] = { --'˚'--
  num = 251,
  adv = 20,
  oxn =    0, oyn =   -1, oxp =   20, oyp =   30,
  txn =  121, tyn =  793, txp =  141, typ =  824,
}
glyphs[252] = { --'¸'--
  num = 252,
  adv = 21,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  161, tyn =  793, txp =  164, typ =  796,
}
glyphs[253] = { --'˝'--
  num = 253,
  adv = 17,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  201, tyn =  793, txp =  204, typ =  796,
}
glyphs[254] = { --'˛'--
  num = 254,
  adv = 20,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  241, tyn =  793, txp =  244, typ =  796,
}
glyphs[255] = { --'ˇ'--
  num = 255,
  adv = 17,
  oxn =   -1, oyn =   -2, oxp =    2, oyp =    1,
  txn =  281, tyn =  793, txp =  284, typ =  796,
}

fontSpecs.glyphs = glyphs

return fontSpecs

