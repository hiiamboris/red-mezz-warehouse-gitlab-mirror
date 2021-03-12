Red [
	title:   "#debug macros"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		#debug on/off - to toggle it
		#debug [my code] - to only include `my code` when debug is on
	}
]

#macro [#debug 'on   ] func [s e] [*debug?*: on  []]
#macro [#debug 'off  ] func [s e] [*debug?*: off []]
#macro [#debug block!] func [[manual] s e] [
	e: s/2
	remove/part s 2
	if *debug?* [insert s e]
	s
]
#debug on
