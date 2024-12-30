Red [
	title:   "PARSE-DUMP dumper and PARSEE tool wrapper"
	purpose: "Visualize parsing progress using PARSEE command-line tool"
	author:  @hiiamboris
	license: 'BSD-3
	provides: parsee
	depends:  [advanced-function composite following timestamp reactor92 tree-hopping data-store]
	usage: {
		See https://codeberg.org/hiiamboris/red-spaces/src/branch/master/programs/README.md#parsee-parsing-flow-visual-analysis-tool-parsee-tool-red
	}
]

; #include %assert.red
; #include %setters.red									;-- `anonymize`
; #include %advanced-function.red							;-- `function` (defaults)
; #include %composite.red									;-- interpolation in print/call
; #include %catchers.red									;-- `following`
; #include %timestamp.red									;-- for dump file name
; #include %reactor92.red									;-- for changes tracking
; #include %tree-hopping.red								;-- for cloning data
; #include %data-store.red								;-- for config load/save

parsee: inspect-dump: parse-dump: none
context expand-directives [
	skip?: func [s [series!]] [-1 + index? s]
	
	;; what Redbin can't save
	unsupported!: make typeset! [native! action! routine! handle! op!]
	if datatype? :event! [unsupported!: union unsupported! make typeset! [event!]]	;-- only exists in View module
	
	complex!: make typeset! [function! object! error! map! vector! image!]
	
	;; this relies on the property of Redbin: it ignores values from system/words
	;@@ refinement! support and double conversion is a workaround for #5437
	unbind: function [word [any-word! refinement!]] [
		to word bind to word! word system/words
	]
	; unbind: function [word [any-word!]] [anonymize word none]
	
	unbind-block: function [block [block!]] compose/deep [
		forall block [
			switch type?/word :block/1 [
				(to [] any-word!)  [block/1: unbind block/1]
				(to [] any-block!) [block/1: unbind-block block/1]
			]
		]
		block
	]
	
	abbreviate: function [
		"Convert value of a complex datatype into a short readable form"
		value [complex! unsupported!]
	][
		rest: switch type: type?/word :value [
			op! native! action! routine! function!
					[copy/deep spec-of :value]
			object!	[
				either :value =? system/words
					[type: 'system 'words]
					[words-of value]
			]
			map!	[words-of value]
			error!	[form value]
			event!	[value/type]
			vector!	[length? value]
			image!	[value/size]
			handle!	[return unbind type]
		]
		as path! unbind-block reduce [type rest]
	]
	
	word-walker: make series-walker! [							;-- visits words of all unique blocks
		types: make typeset! [any-block! any-word!]
		branch: function [:node [any-block!]] [					;-- paren requires get-arg
			while [node: find/tail node types] [				;@@ use for-each
				either any-block? value: node/-1 [
					if filter value [repend/only plan ['branch value]]
				][
					repend/only plan ['visit head node value]
				]
			]
		]
	]

	collect-rule-names: function [rules [hash!]] [
		result: make map! 32
		foreach-node rules word-walker func [:block :word] [
			all [
				any-block? attempt [value: get word]
				find/only/same rules value
				result/:word: value 
			]
		]
		result
	]
	
	replicating-walker: make-series-walker/unordered any-block!	;-- copies the blocks before branching, visits every item

	store: function [
		"Get stored unique copy of original series"
		dict   [hash!]   "Where to store the original->copy mapping"
		series [series!] "If one of copies is given, passed through"
	][
		any [
			new: select/same/only/skip dict old: head series 2	;-- original -> already have copy
			find/same/only/skip next dict new: old 2			;-- copy -> itself
			repend dict [old new: copy old]
		]
		at new index? series
	]
	
	sanitize: function [
		"Prepare series for Redbin compression (for Parsee uses only)"
		series [series!]
		dict   [hash!]
	] compose/deep [
		unless any-block? series [return series]
		series: store dict series
		foreach-node series replicating-walker func [:block i] [
			switch type?/word :block/:i [
				(to [] any-block!) [							;-- blocks must be copied so they can be modified
					return block/:i: store dict block/:i		;-- will branch into this new block
				]
				(to [] any-word!) refinement! [					;-- any-words must be unbound from their contexts
					block/:i: unbind block/:i
				]
				function! map! object! error! vector! image!	;-- complex types are abbreviated to avoid scanning them
				(to [] unsupported!) [							;-- unsupported types are abbreviated as it's the only way to save them
					block/:i: abbreviate :block/:i
				]
			]
		]
		series
	]
	
	check: function [											;-- the only way to debug this codec :(
		"Deeply check if all values can be compressed by Redbin"
		series [series!]
	][
		walker: make-series-walker [any-block!]
		foreach-node series walker [
			saved: attempt [system/codecs/redbin/encode reduce [:node/:key] none]
			either saved [
				[]												;-- do not descend into it if it can be encoded
			][
				print ["Cannot save" mold/flat/part :node/:key 100]
				:node/:key
			]
		]
	]
	
	
	make-dump-name: function [] [
		if exists? filename: rejoin [%"" timestamp %.pdump] [
			append filename enbase/base to #{} random 7FFFFFFFh 16	;-- ensure uniqueness
		]
		filename
	]
	
	set 'parsee function [
		"Process a series using dialected grammar rules, visualizing progress afterwards"
		; input [binary! any-block! any-string!] 
		input [any-block! any-string!]
		rules [block!] 
		/case "Uses case-sensitive comparison" 
		/part "Limit to a length or position" 
			length [number! series!]
		/timeout "Force failure after certain parsing time is exceeded"
			maxtime [time! integer! float!] "Time or number of seconds (defaults to 1 second)"
		/keep "Do not remove the temporary dump file"
		/auto "Only visualize failed parse runs"
		; return: [logic! block!]
	][
		path: to-red-file to-file any [get-env 'TEMP get-env 'TMP %.]
		file: make-dump-name
		parse-result: apply 'parse-dump [
			input rules
			/case    case
			/part    part    length
			/timeout timeout maxtime
			/into    on      path/:file 
		]
		unless all [auto parse-result] [inspect-dump path/:file]
		unless keep [delete path/:file]
		parse-result
	]
	
	config: none
	default-config: #[tool: "parsee"]
	
	set 'inspect-dump function [
		"Inspect a parse dump file with PARSEE tool"
		filename [file!] 
	][
		filename: to-local-file filename
		cwd: what-dir									;@@ workaround for #5427
		unless config [
			self/config: data-store/load-config/name/defaults %parsee.cfg default-config
		]
		call-result: call/shell/wait/output command: `{(config/tool) "(filename)"}` output: make {} 64
		; #debug [print `"Tool call output:^/(output)"`]
		if call-result <> 0 [
			print `"Call to '(command)' failed with code (call-result)."`
			if object? :system/view [
				if tool: request-file/title "Locate PARSEE tool..." [
					config/tool: `{"(to-local-file tool)"}`
					call-result: call/shell/wait command: `{(config/tool) "(filename)"}`
					either call-result = 0 [
						change-dir cwd
						data-store/save-config/name config %parsee.cfg
					][
						print `"Call to '(command)' failed with code (call-result)."`
					]
				]
			]
			if call-result <> 0 [
				print `"Ensure 'parsee' command is available on PATH, or manually open the saved dump with it."`
				print `"Parsing dump was saved as '(filename)'.^/"`
			]
		]
		exit
	]
	
	set 'parse-dump function [
		"Process a series using dialected grammar rules, dumping the progress into a file"
		input [any-block! any-string!] 
		rules [block!] 
		/case "Uses case-sensitive comparison" 
		/part "Limit to a length or position" 
			length [number! series!]
		;@@ maybe timeout PER char, per 1k chars? or measure and compare end proximity?
		;@@ also 1 second dump generates whole hell of data, with 5-10 secs processing it
		/timeout "Specify deadlock detection timeout"
			maxtime: 0:0:1 [time! integer! float!] "Time or number of seconds (defaults to 1 second)"
		/into filename: (make-dump-name) [file!] "Override automatic filename generation"
		; return: [logic! block!]
	][
		dict:          make hash! 128
		cloned:        sanitize input dict						;-- preserve the original input before it's modified
		changes:       make [] 64
		events:        make [] 512
		limit:         now/utc/precise + to time! maxtime
		age:           0										;-- required to sync changes to events
		visited-rules: make hash! 64							;-- unique, at head; collected for name extraction
		reactor: make deep-reactor-92! [						;-- track all input edits
			tracked: input
			on-deep-change-92*: :logger
		]
		following [parse/:case/:part/trace input rules length :tracer] [
			events:  new-line/all/skip events  on 6
			changes: new-line/all/skip changes on 5
			names: to hash! collect-rule-names visited-rules
			data: reduce [cloned]
			append data sanitize reduce [events changes names] dict
			; check data
			save/as filename data 'redbin
		]
	]
	
	tracer: function [event [word!] match? [logic!] rule [block!] input [series!] stack [block!] /extern age] with :parse-dump [
		any [find/only/same visited-rules head rule  append/only visited-rules head rule] 
		reduce/into [age: age + 1 input event match? rule last stack] tail events
		not all [age % 20 = 0  now/utc/precise > limit]			;-- % to reduce load from querying time
	]
	
	;@@ into rule may swap the series - won't be logged, how to deal? save all visited series? redbin will, but not cloned before modification
	logger: function [
		word        [word!]    "name of the field value of which is being changed"
		target      [series!]  "series at removal or insertion point"
		part        [integer!] "length of removal or insertion"
		insert?     [logic!]   "true = just inserted, false = about to remove"
		reordering? [logic!]   "removed items won't leave the series, inserted items came from the same series"
	] with :parse-dump [
		if zero? part [exit]
		; #assert [same? word in reactor 'tracked]				;-- only able to track the input series, nothing deeper
		; #assert [same? head target head reactor/tracked]
		action: pick [insert remove] insert?
		repend changes [
			age
			head target
			pick [insert remove] insert?
			skip? target
			copy/part target part
		]
	]
]

