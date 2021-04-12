Red [
	title:   "#debug macros"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		#debug off          - ignore all debug statements
		#debug on           - include unnamed debug statements only
		#debug set id       - include unnamed debug statements and those named 'id' (word!)
		#debug [my code]    - `my code` is included when debug is not off
		#debug id [my code] - `my code` is included when debug is set to `id`

		EXAMPLE:
			#debug set my-module
			#debug my-module [...]		;) will be included
			#debug other-module [...]	;) will NOT be included
			#debug [...]				;) will be included
	}
]

#macro [#debug 'on       ] func [s e] [*debug?*: on  []]
#macro [#debug 'off      ] func [s e] [*debug?*: off []]
#macro [#debug 'set word!] func [s e] [*debug?*: s/3 []]
#macro [#debug not ['on | 'off | 'set] opt word! block!] func [[manual] s e /local code] [
	if any [
		*debug?* == s/2
		all [*debug?*  block? s/2]
	][
		code: e/-1
	]
	remove/part s e
	if code [insert s code]
	s
]
; #debug on		;@@ this prevents setting it to a word value because of double-inclusion #4422
