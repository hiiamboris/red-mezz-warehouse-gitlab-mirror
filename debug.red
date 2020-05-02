Red [
	title:   "#debug macros"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		#debug on/off - to toggle it
		#debug [my code] - to only include `my code` when debug is on
	}
]

#macro [#debug 'on   ] func [s e] [debug: on  []]
#macro [#debug 'off  ] func [s e] [debug: off []]
#macro [#debug block!] func [s e] [either debug [ s/2 ][ [] ]]
#debug on
