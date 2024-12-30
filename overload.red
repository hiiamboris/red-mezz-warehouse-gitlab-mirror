Red [
	title:    "Function argument overloading"
	purpose:  "Experiment with an alternative way of defining functions"
	author:   @hiiamboris
	license:  BSD-3
	provides: overload
]


overload: context [	
	all-types: to block! any-type!
	spec-arg!: make typeset! [word! lit-word! get-word!]
	
	return function [
		"Extend function with new CODE when its arguments match given SPEC"
		fun     [function!] "Must include all possible overloads in the typesets"
		spec    [block!]    "Only the 1st argument can be overloaded"
		code    [block!]
		return: [function!]
		/local word
	][
		#assert [parse spec [spec-arg! block! opt [[/local | /extern] any skip]]]
		get-arg: to get-word! arg-name: first find spec-of :fun spec-arg!
		either parse body: body-of :fun [						;-- is the func already overloaded?
			ahead path! into [
				set table 'table ahead paren! into [
					'type?/word set word get-word! if (word == get-arg) end
				] end
			] end
		][
			table: get table
			#assert [word = arg-name]
			#assert [map? table]
		][														;-- prep it for overloading
			table: make map! length? all-types
			sub-fun: func [] body-of :fun						;-- words are already local and bound; 'func' copies the body
			foreach type all-types [table/:type: :sub-fun]
			append/only clear body-of :fun as path! reduce [
				anonymize 'table table as paren! reduce [
					'type?/word bind get-arg :fun
				]
			]
		]		
		parse spec [set word spec-arg! set types block!]
		types: to block! make typeset! types					;-- list all datatypes individually
		sub-fun: function [] code								;-- localize all set-words in the code
		bind body-of :sub-fun :fun								;-- prioritize words from the original fun's spec
 		foreach type types [table/:type: :sub-fun] 
		:fun
	]
]

