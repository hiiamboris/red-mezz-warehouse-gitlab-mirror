Red [
	title:   "BMATCH mezzanine"
	purpose: "Detect possibly mismatched brackets positions from indentation"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		Ever had an error about unclosed bracket in a 1000+ line file?
		This script turns the challenge of finding it into a triviality.

		This is a mezz version, for use with the Smarter Load experiment.
	}
]


#include %tabs.red
#include %composite.red

; #include https://gitlab.com/hiiamboris/red-mezz-warehouse/-/raw/master/tabs.red
; #include https://gitlab.com/hiiamboris/red-mezz-warehouse/-/raw/master/composite.red

context [
	non-space: charset [not " "]
	tag-1st:   charset [not " ^-=><[](){};^""]

	match-data!: object [
		script: none
		tab: 4
		tol: 0
		line: indent: 0x0
		pos: []
		report: :print

		extract-brackets: function [text [block!] /extern pos] [
			repeat iline length? text [							;-- build a map of brackets: [line-number indent-size brackets.. ...]
				line: detab/size text/:iline tab

				indent1: offset? line any [find line non-space  tail line]
				replace line "|" " "							;-- special case for parse's `| [...` pattern: ignore `|`
				indent2: offset? line any [find line non-space  tail line]
				indent: as-pair indent1 indent2					;-- allow 2 indent variants

				if indent = length? line [continue]				;-- empty line
				pos: insert insert pos iline indent

				stack: clear []									;-- deep strings (for curly braces which count opened/closing markers)
				parse line [collect after pos any [
					if (empty? stack) [							;-- inside a block
						keep copy _ ["}" | "[" | "]" | "(" | ")"]
					|	s: any "%" e: keep copy _ "{"
						(append stack level: offset? s e)
					|	";" to end
					|	{"} any [{^^^^} | {^^"} | not {"} skip]
						[{"} | (report #composite "(script): Open string literal at line (iline)")]
					|	{<} tag-1st
						[thru {>} | (report #composite "(script): Open tag at line (iline)")]
					]

				|	[											;-- inside a string
						if (level = 0) [						;-- inside normal curly
							"^^^^" | "^^}" | "^^{"				;-- allow escape chars
						|	keep copy _ "{" (append stack 0)	;-- allow reentry
						]
					|	copy _ "}" level "%" keep (_) (level: take/last stack)
					]

				|	skip
				]]
			]
			pos: head pos
		]

		read-until: function [end-marker [string! block!] /extern pos] [
			indent1: indent  line1: line						;-- remember coordinates of the opening bracket
			parse pos [
				while [
					set line integer! set indent pair!
				|	"[" pos: (read-until "]") :pos
				|	"(" pos: (read-until ")") :pos
				|	"{" pos: (read-until "}") :pos
				|	end-marker pos:
					(
						found?: yes								;@@ workaround for #4202 - can't `exit`
						dist: min absolute indent/1 - indent1
						          absolute indent/2 - indent1
						if tol < min dist/1 dist/2 [			;-- compare both opening idents to both closing to find the best match
							report #composite "(script): Unbalanced (end-marker) indentation between lines (line1) and (line)"
						]
					)
					break
				|	pos: skip (report #composite "(script): Unexpected occurrence of (pos/1) on line (line)")
				]
				(unless found? [report #composite "(script): No ending (end-marker) after line (line1)"])
			]
		]
	]

	set 'bmatch func [
		"Detect unmatched brackets based on indentation"
		source [string! binary!]
		/origin    script [file! url! string!] "Filename where the data comes from"
		/tabsize   tab [integer!] "Override tab size (default: 4)"
		/tolerance tol [integer!] "Min. indentation mismatch to report (default: 0)"
		/into      tgt [string!]  "Buffer to output messages into (otherwise prints)"
	][
		if binary? source [source: to string! source]
		data: make match-data! []
		data/tol: max 0 any [tol 0]
		data/tab: max 0 any [tab 4]
		data/script: any [script "(unknown)"]
		data/report: either into [ func [s][repend tgt [s #"^/"]] ][ :print ]

		data/extract-brackets split source #"^/"
		data/read-until [end]
		tgt
	]
]