Red [
	title:   "DETAB & ENTAB mezzanines"
	purpose: "Tabs to spaces conversion and back"
	author:  @hiiamboris
	license: 'BSD-3
	notes:   {Supports multi-line text}
]

; #include %clock.red
; #include %assert.red


context [
	spaces: insert/dup "" #"^(20)" 32					;-- 32 spaces max are supported per tab
	set 'detab function [
		"Expand tabs in string STR"
		str       [string! binary!]
		/into buf [string! binary!]  "Speficy an out buffer (allocated otherwise)"
		/size tab [integer!]         "Specify Tab size (default: 8)"
	][
		buf: any [buf  make str length? str]
		tab: any [tab 8]
		#assert [tab > 0]
		#assert [tail? spaces]
		ok: parse/case s1: str [
			collect into buf [
				any [
					keep any [#"^/" s1: | not #"^-" skip]
					any [
						s2: #"^-" 
						keep (skip spaces (offset? s1 s2) % tab - tab)
						s1:
					]
				]
			]
		]
		#assert [ok]
		buf
	]

	nonspace: charset [not #"^(20)"]
	set 'entab function [
		"Convert leading spaces in STR into tabs"
		str       [string! binary!]
		/into buf [string! binary!]  "Speficy an out buffer (allocated otherwise)"
		/size tab [integer!]         "Specify Tab size (default: 8)"
	][
		buf: any [buf  make str length? str]
		tab: any [tab 8]  tab-1: tab - 1
		#assert [tab > 0]
		#assert [tail? spaces]
		ok: parse/case str [
			collect into buf [
				any [
					s1: #" " [
						s2: tab-1 [#" " s2:] keep (#"^-")
					|	:s1 keep :s2
					]
				|	keep #"^-"
				|	keep thru [#"^/" | end]
				]
			]
		]
		#assert [ok]
		buf
	]
]

comment [
	; slower versions:

	detab2: func [s [string!] /into buf [string!] /size tab /local s1 s2] [
		spaces: tail "                                "	;-- 32 spaces
		append buf: any [buf  copy ""] s
		parse/case buf [any [
			p: change #"^-" (
				i: index? p
				skip spaces -1 + i - round/to/ceiling i tab
			)
		|	skip
		]]
		buf
	]

	detab1: func [s [string!] /into buf [string!] /size tab /local s1 s2] [
		spaces: tail "                                "	;-- 32 spaces
		buf: any [buf  copy ""]
		parse/case s [
			any [
				s1: to #"^-" s2: skip
				(append/part buf s1 s2
				 append/dup buf #"^(20)" (tab - ((length? buf) % tab)) )
			]
			(append buf s1)
		]
		buf
	]


	detab3: func [s [string!] /into buf [string!] /size tab /local s2] [
		buf: any [buf  copy ""]
		while [not tail? s] [
			either s2: find/case s #"^-" [
				append/part buf s s2
				append/dup buf #"^(20)" (tab - ((length? buf) % tab))
			][ append buf s  break ]
			s: next s2
		]
		buf
	]
]

; tests
; s: "^-1 2 3  4^-1^-2 3 4 5^-|abcdefgh^-abcdefgh"

; buf: ""
; recycle/off
; probe "|-------|-------|-------|-------|-------|-------|-------|-------|"
; probe detab s
; probe entab detab s
; ; probe detab1 s clear buf
; ; probe detab2 s clear buf
	
; clock/times [detab/into  s clear buf] 10000
; s: detab s
; clock/times [entab/into  s clear buf] 10000

; clock/times [entab1/into s clear buf] 10000
; clock/times [entab2/into s clear buf] 10000
; clock/times [entab3/into s clear buf] 10000

#assert [""                 = r: detab ""            'r]
#assert ["        "         = r: detab "^-"          'r]
#assert ["                " = r: detab "^-^-"        'r]
#assert ["1               " = r: detab "1^-^-"       'r]
#assert ["1       1       " = r: detab "1^-1^-"      'r]
#assert ["        1       " = r: detab "^-1^-"       'r]
#assert ["1234567         " = r: detab "1234567^-^-" 'r]
#assert ["12345678        " = r: detab "12345678^-"  'r]
#assert ["123456789       " = r: detab "123456789^-" 'r]
#assert ["123456789012345 " = r: detab "123456789012345^-" 'r]
#assert ["        1234567 " = r: detab "^-1234567^-" 'r]
#assert ["1   ^/    2   ^/    ^/" = r: detab/size "1^-^/^-2^-^/^-^/" 4 'r]

#assert [""                 = r: entab ""                 'r]
#assert ["1"                = r: entab "1"                'r]
#assert ["^-"               = r: entab "        "         'r]
#assert ["^-^-"             = r: entab "                " 'r]
#assert ["       1"         = r: entab "       1"         'r]
#assert ["       1        " = r: entab "       1        " 'r]
#assert ["^-1       "       = r: entab "        1       " 'r]
#assert ["1               " = r: entab "1               " 'r]
#assert ["^-       1"       = r: entab "               1" 'r]
#assert ["^-      12"       = r: entab "              12" 'r]
#assert ["^- 1234567"       = r: entab "         1234567" 'r]
#assert ["^-12345678"       = r: entab "        12345678" 'r]
#assert ["       123456789" = r: entab "       123456789" 'r]
#assert ["1234567890123456" = r: entab "1234567890123456" 'r]
#assert ["^-^-  1^/^-2"     = r: entab/size "^-      1^/    2" 4 'r]			;-- allows mixing tabs and spaces; resets at newlines


#assert [""                 = r: to "" detab to #{} ""            'r]
#assert ["        "         = r: to "" detab to #{} "^-"          'r]
#assert ["                " = r: to "" detab to #{} "^-^-"        'r]
#assert ["1               " = r: to "" detab to #{} "1^-^-"       'r]
#assert ["1       1       " = r: to "" detab to #{} "1^-1^-"      'r]
#assert ["        1       " = r: to "" detab to #{} "^-1^-"       'r]
#assert ["1234567         " = r: to "" detab to #{} "1234567^-^-" 'r]
#assert ["12345678        " = r: to "" detab to #{} "12345678^-"  'r]
#assert ["123456789       " = r: to "" detab to #{} "123456789^-" 'r]
#assert ["123456789012345 " = r: to "" detab to #{} "123456789012345^-" 'r]
#assert ["        1234567 " = r: to "" detab to #{} "^-1234567^-" 'r]
#assert ["1   ^/    2   ^/    ^/" = r: to "" detab/size to #{} "1^-^/^-2^-^/^-^/" 4 'r]

#assert [""                 = r: to "" entab to #{} ""                 'r]
#assert ["1"                = r: to "" entab to #{} "1"                'r]
#assert ["^-"               = r: to "" entab to #{} "        "         'r]
#assert ["^-^-"             = r: to "" entab to #{} "                " 'r]
#assert ["       1"         = r: to "" entab to #{} "       1"         'r]
#assert ["       1        " = r: to "" entab to #{} "       1        " 'r]
#assert ["^-1       "       = r: to "" entab to #{} "        1       " 'r]
#assert ["1               " = r: to "" entab to #{} "1               " 'r]
#assert ["^-       1"       = r: to "" entab to #{} "               1" 'r]
#assert ["^-      12"       = r: to "" entab to #{} "              12" 'r]
#assert ["^- 1234567"       = r: to "" entab to #{} "         1234567" 'r]
#assert ["^-12345678"       = r: to "" entab to #{} "        12345678" 'r]
#assert ["       123456789" = r: to "" entab to #{} "       123456789" 'r]
#assert ["1234567890123456" = r: to "" entab to #{} "1234567890123456" 'r]
#assert ["^-^-  1^/^-2"     = r: to "" entab/size to #{} "^-      1^/    2" 4 'r]			;-- allows mixing tabs and spaces; resets at newlines
