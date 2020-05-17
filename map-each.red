Red [
	title:   "MAP-EACH mezzanine"
	purpose: "Map one series into another, leveraging FOR-EACH power"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		Design deliberations:

		/only with filtering spec does not apply /only to the filtered out items, e.g.:
			>> map-each/only [x [integer!]] [1 a 2 b c 3] [to block! x]
			== [[1] a [2] b c [3]]  -- rather than [[1] [a] [2] [b c] [3]]
			current behavior is mostly meant for /only/self, where we're not touching the filtered out items
			does it make sense to do it the other way?

		/eval saves us from typing `reduce` everytime we want to keep more than one item
			currently it only reduces `block!`s, passing any other value as is
			should we call `reduce` on any other value type?

		/drop is useful in 2 ways:
			- without it, we can't control whether to include what was filtered out or not
			  we would have to use our own filters in the body block that would decide when to return an empty series
			- it's type-agnostic: no need to think whether to return an empty block or empty string
		/drop is implied for ranges (integer/pair) and maps as otherwise it would complicate the algorithm
			i.e. break/continue do not keep skipped items in the range/map

		without /drop, `continue` and `break` keep the skipped items
		Curious, how much code is involved in /drop-less mode support. I'm even starting to doubt it's worth.

		/self may be adapted to transform a map into another map, but this is too much trouble:
			- if key is modified, requires removing the key, adding a new one
			- for-each works internally on a block, so we would have to make a special case for it
			- and then why? if one can just write `make map! map-each ...`
		/self is not faster than normal map, because we can't guarantee that mapped items won't overrun the original position
			although it reuses the original buffer in the end, which is handy when that buffer is shared with other code
			for on-deep-change*, there will be a single `change` action from head to tail with new data,
			  so the series will never be in a partially filled or broken state from an observer's POV
			on-change* won't fire (as we have no access to the word referring to the series)

		Usage of `advance` with filters: `advance` may skip some values and it is up to the user to keep them when needed
		All limitations of FOR-EACH apply.

		See also https://github.com/greggirwin/red-hof/tree/master/code-analysis#map-each
	}
]


; #include %assert.red
#include %error-macro.red
#include %for-each.red

context [
	;; `compose` readability helper
	when: make op! func [value test] [either :test [:value][[]]]

	ranges!:   make typeset! [integer! pair!]			;-- supported non-series types

	;@@ TODO: /reverse? how will it work though? 
	;@@ TODO: /group sep ? to delimit values
	set 'map-each function [
		"Map SERIES into a new one and return it"
		'spec  [word! block!]                "Words & index to set, values/types to match"
		series [series! map! pair! integer!] "Series, map or range"
		code   [block!]                      "Should return the new item"
		/only "Treat block returned by CODE as a single item"
		/eval "Reduce block returned by CODE (else includes it as is)"
		/drop "Discard regions that didn't match SPEC (else includes them unmodified)"
		/case "For get-words only: use strict comparison"
		/same "For get-words only: use sameness comparison"
		/self "Map series into itself (incompatible with ranges and maps)"
		/local r
	][
		if find [map! integer! pair!] type?/word series [
			if self [ERROR "/self is not allowed when iterating on ranges"]
			drop: yes															;-- imply /drop for ranges & maps
		]

		;; /drop-less mode requires an index, so we have to provide it or reuse user's index
		;; both for regions filtered out by spec matching, and for break/continue
		unless drop [
			size: 0																;-- determine the spec "width"
			parse spec: compose [(spec)] [any [
				[word! | get-word! (track?: yes)] (size: size + 1)
			|	block! (track?: yes)
			|	skip
			]]

			unless find [set-word! refinement!] type?/word :spec/1 [			;-- add custom index if none exists
				insert spec [pos:]
			]

			index-word: to get-word! spec/1
			get-pos: compose pick [												;-- different index types require different code
				[(index-word)]
				[at series (index-word)]										;-- works for images as well
			] set-word? spec/1
		]

		call: as path! compose [for-each ('case when case) ('same when same)]	;@@ TODO: use `apply` once it's a native
		keep: pick [ [append/only tgt] [append tgt] ] only						;@@ TODO: use `apply` once it's a native
		do-code: compose pick [													;-- /eval mode requires an extra reduce call
			[ either block? set/any 'r (as paren! code) [r: reduce r][:r] ]
			[ (as paren! code) ]												;-- can't just `do code` or will not be bound to `advance`
		] eval

		tgt: make block! system/words/case [									;-- where to collect into
			integer? series [series]
			pair? series    [series/x * series/y]
			'else           [length? series]
		]

		do compose/deep pick [													;-- prepare the loop body & evaluate
			;; /drop-less mode requires a lot of bookkeeping
			;@@ maybe `for-each` should expose some intrinsic hooks to avoid mess such as this?
			[
				old-advance: none												;-- default `advance` won't keep track of the mapped regions
				new-advance: does [new: any [r: old-advance  tail series]]		;-- so it should be replaced
				do-once: func [b [block!]] [do b clear b]
				(call) [(spec)] old: series [
					do-once [old-advance: :advance  advance: :new-advance]		;-- inject our own `advance`
					new: (get-pos)
					; unless old =? new [append/part tgt old new]		doesn't work because of #4336
					unless old =? new [append tgt copy/part old new]			;-- workaround
					old: new													;-- remember current position in case `code` does `break`/`continue`
					(keep) (do-code)
					old: skip new (size)										;-- if code returns, consider this piece processed
				]
				unless empty? old [append tgt copy old]							;-- copy to make new series independent of the old one
			]
			;; /drop is quite straightforward
			[
				(call) [(spec)] old: series [(keep) (do-code)]
			]
		] not drop

		either self [head change/part series tgt tail series] [tgt]				;-- return the modified original with /self
	]
]


;; spec unfolding tests
#assert [empty?    b: map-each  x  [     ] [x] 'b]
#assert [[1    ] = b: map-each  x  [1    ] [x] 'b]
#assert [[1 2  ] = b: map-each  x  [1 2  ] [x] 'b]
#assert [[1 2 3] = b: map-each  x  [1 2 3] [x] 'b]
#assert [[1    ] = b: map-each [x] [1    ] [x] 'b]
#assert [[1 2  ] = b: map-each [x] [1 2  ] [x] 'b]
#assert [[1 2 3] = b: map-each [x] [1 2 3] [x] 'b]
#assert [[[1 2] [3 #[none]]      ] = b: map-each/only [x y] [1 2 3    ] [reduce [x y]] 'b]
#assert [[[1 2] [3 4]            ] = b: map-each/only [x y] [1 2 3 4  ] [reduce [x y]] 'b]
#assert [[[1 2] [3 4] [5 #[none]]] = b: map-each/only [x y] [1 2 3 4 5] [reduce [x y]] 'b]

;; decomposition of strings
#assert [[#"a" #"b" #"c"]    = b: map-each  x    "abc"   [x] 'b]
#assert [[#"a" #"c" #"e"]    = b: map-each [x y] "abcde" [x] 'b]
#assert [[#"b" #"d" #[none]] = b: map-each [x y] "abcde" [y] 'b]
#assert [[#"b" #"d"]         = b: map-each [x y] "abcd"  [y] 'b]
#assert [[#"a" #"b" #"c"]    = b: map-each  x     <abc>  [x] 'b]
#assert [[#"a" #"b" #"c"]    = b: map-each  x     %abc   [x] 'b]
#assert [[#"a" #"@" #"b"]    = b: map-each  x     a@b    [x] 'b]
#assert [[#"a" #":" #"b"]    = b: map-each  x     a:b    [x] 'b]

;; indexes
#assert [[1 2 3] = b: map-each [/i x]   [x y z]     [i       ] 'b]
#assert [[1 2 3] = b: map-each [p: x]   [x y z]     [index? p] 'b]
#assert [[1 3 5] = b: map-each [/i x y] [a b c d e] [i       ] 'b]
#assert [[1 3 5] = b: map-each [p: x y] [a b c d e] [index? p] 'b]

;; image support
#assert [im: make image! [2x2 #{111111 222222 333333 444444}]]
; #assert [[17.17.17.0 34.34.34.0 51.51.51.0 78.78.78.0] = b: map-each c i [c] 'b]		;@@ uncomment me when #4421 gets fixed
#assert [[1x1 2x1 1x2 2x2] = b: map-each [/i c] im  [i] 'b]				;-- special index for images - pair
#assert [[1 2 3 4        ] = b: map-each [p: c] im  [index? p] 'b]

;; 1D/2D ranges support
#assert [error? e: try [map-each [/i x] 2x2 []] 'e]						;-- indexes with ranges forbidden
#assert [error? e: try [map-each [p: x] 2x2 []] 'e]
#assert [[1x1 2x1 1x2 2x2] = b: map-each  i    2x2 [i] 'b]				;-- unfold size into pixel coordinates
#assert [[1x1 1x2        ] = b: map-each [i j] 2x2 [i] 'b]
#assert [[1 2 3 4        ] = b: map-each  i    4   [i] 'b]
#assert [[1 3 5 7 9      ] = b: map-each [i j] 10  [i] 'b]				;-- unfold length into integers
#assert [[               ] = b: map-each  i    0   [i] 'b]				;-- zero length
#assert [[               ] = b: map-each  i    -10 [i] 'b]				;-- negative length
#assert [[               ] = b: map-each  i    0x0 [i] 'b]				;-- zero length
#assert [[               ] = b: map-each  i    0x5 [i] 'b]				;-- zero length
#assert [[               ] = b: map-each  i    5x0 [i] 'b]				;-- zero length
#assert [[               ] = b: map-each  i  -5x-5 [i] 'b]				;-- negative length

;; maps support
#assert [error? e: try [map-each [p: x] #(1 2 3 4) []] 'e]								;-- no indexes for maps allowed
#assert [error? e: try [map-each [/i x] #(1 2 3 4) []] 'e]
#assert [[1 2 3 4        ] = b: map-each [k v]       #(1 2 3 4) [reduce [k v]] 'b]		;-- map iteration is very relaxed
#assert [[1 2 3 4        ] = b: map-each x           #(1 2 3 4) [x]        'b]
#assert [[1 2 3 4 #[none]] = b: map-each [a b c d e] #(1 2 3 4) [reduce [a b c d e]] 'b]

;; vectors support
#assert [v: make vector! [1 2 3 4 5]]
#assert [[1 2 3 4 5              ] = b: map-each       x    v [x]            'b]
#assert [[[1 2] [3 4] [5 #[none]]] = b: map-each/only [x y] v [reduce [x y]] 'b]

;; any-block support
#assert [[[1 2] [3 4] [5 #[none]]] = b: map-each/only [x y] make hash!   [1 2 3 4 5] [reduce [x y]] 'b]
#assert [[[1 2] [3 4] [5 #[none]]] = b: map-each/only [x y] as paren!    [1 2 3 4 5] [reduce [x y]] 'b]
; #assert [[[1 2] [3 4] [5 #[none]]] = b: map-each/only [x y] as path!     [1 2 3 4 5] [reduce [x y]] 'b]		;@@ uncomment me when #4421 gets fixed
; #assert [[[1 2] [3 4] [5 #[none]]] = b: map-each/only [x y] as lit-path! [1 2 3 4 5] [reduce [x y]] 'b]		;@@ uncomment me when #4421 gets fixed
; #assert [[[1 2] [3 4] [5 #[none]]] = b: map-each/only [x y] as set-path! [1 2 3 4 5] [reduce [x y]] 'b]		;@@ uncomment me when #4421 gets fixed
; #assert [[[1 2] [3 4] [5 #[none]]] = b: map-each/only [x y] as get-path! [1 2 3 4 5] [reduce [x y]] 'b]		;@@ uncomment me when #4421 gets fixed

;; `continue` & `break` support
#assert [[1 2 3] = b: map-each       x [1 2 3] [continue x] 'b]
#assert [[     ] = b: map-each/drop  x [1 2 3] [continue x] 'b]
#assert [[1 2 3] = b: map-each       x [1 2 3] [if x > 1 [break] x] 'b]
#assert [[1    ] = b: map-each/drop  x [1 2 3] [if x > 1 [break] x] 'b]
#assert [[1 2 3] = b: map-each       x [1 2 3] [break] 'b]
#assert [[     ] = b: map-each/drop  x [1 2 3] [break] 'b]

;; /eval
#assert [[1 2 3 4]           = b: map-each/eval      x [1 2 3 4] [x] 'b]
#assert [[1 2 3 4]           = b: map-each/eval      x [1 2 3 4] [[x]] 'b]
#assert [[[1] [2] [3] [4]]   = b: map-each/eval/only x [1 2 3 4] [[x]] 'b]
#assert [[(1) (2) (3) (4)]   = b: map-each/eval/only x [1 2 3 4] [to paren! x] 'b]
#assert [[1 [x y] 2 [x y]]   = b: map-each/eval      x [1 2    ] [[ x map-each x [x y] [x] ]] 'b]
#assert [[1 [x y] 2 [x y]]   = b: map-each           x [1 2    ] [reduce [ x map-each      x [x y]  [x] ]] 'b]
#assert [[1 [x y] 2 [x y]]   = b: map-each           x [1 2    ] [reduce [ x map-each/eval x [x y] [[x]] ]] 'b]

;; filtering (pattern matching)
#assert [[1 2 3 4 5 6]             = b: map-each            x             [1 "2" "3" 4 5 "6"] [to integer! x] 'b]
#assert [["1" "2" "3" "4" "5" "6"] = b: map-each           [x [integer!]] [1 "2" "3" 4 5 "6"] [form x]        'b]
#assert [[1 2 3 4 5 6]             = b: map-each           [x [string!]]  [1 "2" "3" 4 5 "6"] [to integer! x] 'b]
#assert [[1 [2] [3] 4 5 [6]]       = b: map-each/only/eval [x [string!]]  [1 "2" "3" 4 5 "6"] [[to integer! x]] 'b]
#assert [[[1] "2" "3" [4] [5] "6"] = b: map-each/only/eval [x [integer!]] [1 "2" "3" 4 5 "6"] [[x]] 'b]

;; /same & /case value filters
#assert [[2 2          ] = (v: 2 b: map-each/case/drop [p: :v] [2 2.0 #"^B" 2] [p/1]) 'b]
#assert [[2 2          ] = (v: 2 b: map-each/same/drop [p: :v] [2 2.0 #"^B" 2] [p/1]) 'b]
#assert [[2 2.0 #"^B" 2] = (v: 2 b: map-each/case      [p: :v] [2 2.0 #"^B" 2] [p/1]) 'b]
#assert [[2 2.0 #"^B" 2] = (v: 2 b: map-each/same      [p: :v] [2 2.0 #"^B" 2] [p/1]) 'b]
#assert [r: reduce [v: "v" w: "v" w uppercase copy v]]
#assert [["v" "v" "v" "V"] == b: map-each           [p: :v] r [p/1] 'b]
#assert [["v" "v" "v"    ] == b: map-each/case/drop [p: :v] r [p/1] 'b]
#assert [["v" "v"        ] == b: map-each/same/drop [p: :w] r [p/1] 'b]
#assert [["v"            ] == b: map-each/same/drop [p: :v] r [p/1] 'b]
#assert [["V" "V" "V" "V"] == b: map-each/case      [p: :v] r [uppercase copy p/1] 'b]
#assert [["v" "V" "V" "V"] == b: map-each/same      [p: :w] r [uppercase copy p/1] 'b]
#assert [["V" "v" "v" "V"] == b: map-each/same      [p: :v] r [uppercase copy p/1] 'b]

;; /self
#assert [error? try  [b: map-each/self x 4             [x]]                 'b]		;-- incompatible with ranges & maps
#assert [error? try  [b: map-each/self x 2x2           [x]]                 'b]
#assert [error? try  [b: map-each/self x #(a b)        [x]]                 'b]
#assert [[1 2 3 4]  = b: map-each/self x [11 22 33 44] [x / 11]             'b]
#assert ["1234"     = s: map-each/self x "abcd"        [x - #"a" + #"1"]    's]		;-- string in, string out
#assert ["a1b2c3d4" = s: map-each/self/eval x "abcd"  [[x x - #"a" + #"1"]] 's]

;; `advance` support (NOTE: without /drop - advance makes little sense and hard to think about)
#assert [[[2 3] #[none]] = b: map-each/drop/only  x    [1 2 3    ] [        advance] 'b]
#assert [[[2 3 4] [4]  ] = b: map-each/drop/only  x    [1 2 3 4  ] [        advance] 'b]
#assert [[[3 4] #[none]] = b: map-each/drop/only  x    [1 2 3 4  ] [advance advance] 'b]
#assert [[[3 4]        ] = b: map-each/drop/only [x y] [1 2 3 4  ] [        advance] 'b]
#assert [[[5]          ] = b: map-each/drop/only [x y] [1 2 3 4 5] [advance advance] 'b]
#assert [[4 #[none]    ] = b: map-each/drop [x [integer!]] [1 2.0 #"3" 4 'e 6] [set [x] advance x] 'b]	;-- jumps to next match
#assert [[2.0 6        ] = b: map-each/drop [x [number!] ] [1 2.0 #"3" 4 'e 6] [set [x] advance x] 'b]
#assert [[1 6          ] = b: map-each/drop [x [integer!]] [1 2.0 #"3" 4 'e 6] [advance x] 'b]			;-- does not affect the `x`
#assert [[4 'e #[none] ] = b: map-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [set [x] advance x] 'b]		;-- without /drop includes skipped items
#assert [[2.0 #"3" 6   ] = b: map-each [x [number!] ] [1 2.0 #"3" 4 'e 6] [set [x] advance x] 'b]
#assert [[1 'e 6       ] = b: map-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [advance x] 'b]

