Red [
	title:   "#LOCALIZE macro"							;-- #local is already used by the preprocessor
	purpose: "Collect and hide set-words and loop counters"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		This is most useful when working in the global context, esp. for unit tests.
		Use WITH when you want minimum overhead. #LOCALIZE is slower, but fully automated collector.

		Usage:
			a: 321
			#localize [print [a: 123]]					;-- prints 123
			?? a										;-- still 321

		Limitations:
			traps return, exit

		'localize' may misleadingly hint at l10n. But what name fits this macro better?
	}
]

#macro [#localize block!] func [[manual] s e] [			;-- allow macros within local block!
	remove/part insert s compose/deep/only [do reduce [function [] (s/2)]] 2
	s													;-- reprocess
]

