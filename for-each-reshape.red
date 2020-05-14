Red [
	title:   "FOR-EACH loop (RESHAPE variant)"
	purpose: "Experimental design of an extended FOREACH"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		This is a version based on RESHAPE instead of COMPOSE.
		It's for tests and experiments mainly, as it has ~12 times slower loop build time!
		(though the loop itself will be the same)

		See FOR-EACH.red for design info.
	}
]

; #include %assert.red
#include %error-macro.red
#include %bind-only.red
#include %reshape.red

context [
	;;@@ TODO: use `find` for better speed when using masks?
	;;   unfortunately `find` is limited to types, not working with typesets
	;;   no big loss for types? find with types is not gonna be fast anyway as it can't leverage hashmap
	;;   for values masks it'll be great though
	;; quirk of `find` that makes it still very complicated:
	;; >> find reduce [integer!] integer!
	;; == [integer!]
	;; when looking up by value - if this value is a datatype, it should be wrapped into a block: [integer!]


	;; pattern matching support funcs:
	;;@@ TODO: fastest(?) way to check values' types - call a function - do that once `apply` is a native
	;;         otherwise will have to compose the call each time (insert `quote` at least, so that's not faster yet)
	types-match?: func [series types /local i] [
		repeat i length? types [
			unless find types/:i type? :series/:i [return no]
		]
		yes
	]
	values-match?: func [series values values-mask op /local i] [
		repeat i length? values [
			all [
				:values-mask/:i
				not :series/:i op :values/:i
				return no
			]
		]
		yes
	]
	#assert [r: values-match? [1 2 3] [3 3 3] [#[none] #[none] 3] := 'r]

	set-able!: make typeset! [block! paren! hash!]		;-- `set` vs `foreach` - see below
	ranges!:   make typeset! [integer! pair!]			;-- supported non-series types
	is-range?: func [x] [find ranges! type? :x]

	;; helpers for non-series types (ranges) iteration:
	int2pair: func [i [integer!] w [integer!]] [as-pair  i - 1 % w + 1  i - 1 / w + 1]
	fill-int-range: func [range [block!] from [integer!] dim [integer!]] [
		repeat i length? range [
			range/:i: all [from <= dim  from]			;-- none after the 'tail'
			from: from + 1
		]
		from
	]
	fill-pair-range: func [range [block!] from [integer!] dim [pair!]] [
		repeat i length? range [
			xy: int2pair from dim/x
			range/:i: all [xy/y <= dim/y  xy]			;-- none after the 'tail'
			from: from + 1
		]
		from
	]

	set 'for-each function [
		"Evaluate CODE for each match of the SPEC on SERIES"
		'spec  [word! block!]                "Words & index to set, values/types to match"
		series [series! map! pair! integer!] "Series, map or range"
		code   [block!]                      "Code to evaluate"
		/reverse "Traverse in the opposite direction"
		/stride  "Lock step at 1 (or -1 for reverse), while setting all SPEC words"
		/case    "For get-words only: use strict comparison"
		/same    "For get-words only: use sameness comparison"
		/local _ x r index-word
	][
		val-cmp-op: get pick pick [[=? =?] [== =]] same case
		case: :system/words/case
		if case [
			integer? series [series <= 0]
			pair?    series [any [series/x <= 0 series/y <= 0]]
			'else [empty? series]
		] [exit]										;-- optimization; also works for /reverse, as we don't go before the current index

		;; spec preprocessing
		spec: compose [(spec)]											;-- `to block! spec` doesn't copy it, but it'll be modified!
		types: copy														;-- types for typed pattern matching
			values: copy												;-- values for matching by value
				values-mask: copy []									;-- what values should be checked
		parse spec [
			remove set index-word opt [refinement! | set-word!]			;-- none / refinement / setword
			some [
				[	set word word!										;-- word
					remove set type opt [block! (use-types?: yes)]		;-- [types]
					(get-word: none)
				|	change set get-word get-word! ('_)					;-- :word
					(word: type: none  use-values?: yes)
				|	spec: (ERROR "Unexpected spec format (mold spec)")
				](
					append types either type [make typeset! type][any-type!]
					append values-mask get-word
				)
			]
			end | (ERROR "Spec must contain words or get-words!")
		]																;-- spec is now native-foreach-compatible
		filtered?: yes = any [use-types? use-values?]
		values: reduce values-mask
		size: length? spec												;-- number of values to set/check each time
		#assert [size = length? values-mask]
		#assert [size = length? values]
		#assert [size = length? types]
		range?: is-range? series
		case [
			range? [if index-word [ERROR "Can't use indexes with integer/pair ranges"]]
			map? series [
				if index-word [ERROR "Can't use indexes when iterating over map"]
				series: to block! series
			]
		]

		;; step length & direction, end condition
		step: either stride [1][size]									;-- number of items to skip every time
		ahead: size - step + 1											;-- number of items should be guaranteed ahead
		either reverse [
			length: case [
				not range?   [length? series]
				pair? series [series/x * series/y]
				'else        [series]
			]
			index: length - either stride [size - 1][length - 1 % step]	;-- align to starting offset rather than the tail
			end-cond: [index <= 0]										;-- this works even if series is not at head initially
			step: 0 - step
		][
			index: 1
			end-cond: reshape [
				index + !(ahead - 1) >
					!(length)		/if range? /do length: either integer? series [series][series/x * series/y]
					length? series	/else								;-- length must be dynamically checked in case series grows
			]
		]
		all [stride  do end-cond  exit]									;-- optimization for /stride: full spec never fits the series

		;; optimization: trim masks from unnecessary checks
		;;@@ (trim/tail/with is buggy, see #4210) -- use it when it's fixed
		case/all [
			use-types?  [while [any-type! = last types] [take/last types]]
			use-values? [while [none? last values-mask] [take/last values take/last values-mask]]
		]

		;; build user-provided index assignment code
		upd-idx: reshape [							/if index-word		;-- empty if no index requested
			/do upd-idx: case [
				set-word? index-word ['where]							;-- series index
				not image? series    ['index]							;-- integer index
				'image [ compose [int2pair index (series/size/x)] ]		;-- images receive special pair! index instead of integer!
			]
			!(to set-word! index-word) @(upd-idx)
		]

		;; set up the series pointer & decide what code is needed to fill fake series for ranges
		either range? [
			where: append/dup copy [] 0 size							;-- generate a fake series to fill the items with
			refill: reshape [											;-- spec filling code for ranges
				fill-int-range  where index !(length)	/if integer? series
				fill-pair-range where index !(series)	/else
			]
		][
			where: at series index
		]

		;; build code that sets the spec on each iteration
		prefix: reshape [ old: /if filtered? ]							;-- `old:` is required for checks as they come after index advancement
		spec-fill: reshape [
			/if find set-able! type? series
				set !(spec) @(prefix) where								;-- only block!, paren!, hash! are working with set-syntax
			/else
				@(refill)								/if range?		;-- ranges require to populate the spec every time
				foreach !(spec) @(prefix) where [break]					;-- everything other series type requires this hack
		]

		;; build type/value checking code
		test: reshape [											/if filtered?
			/do test: reshape [
				types-match?  old types								/if use-types?
				values-match? old values values-mask :val-cmp-op	/if use-values?
			]
			unless
				all !(test)											/if all [use-types? use-values?]
				@(test)												/else
			[continue]
		]

		;; build & expose `advance`
		move-idxs: reshape [
			where: at series		/if not range?						;-- if `range?` then `where = spec` constantly
			index: !(step) + index
		]
		advance: does reshape [
			while [not @(end-cond)] [
				old: where												;-- save current (already moved) position for returning it
				@(move-idxs)											;-- advance further
				@(test)				/if filtered?						;-- `continue`s if no match
				return old
			]
			none														;-- return none when at the end
		]
		bind-only code 'advance											;-- should be okay to bind it in place

		unset 'r														;-- return unset if never entered
		do reshape [
			set/any 'r forever [										;-- can't use `while` because it does not return value (needed for break/return)
				if @(end-cond) [break/return :r]
				;; set user index and fill the spec before advancing!
				@(upd-idx) @(spec-fill)
				;; advance before do-ing the code - otherwise it will stall on `continue`!
				@(move-idxs)											;-- inlined `advance` for more juice
				;; tests may call `continue` so they follow `move-idxs`
				@(test)

				set/any 'r do code										;-- using `do` to assign the *last* value to `r`
			]
		]
		:r
	]
]


;; return value tests
#assert [error? try [for-each [] [1] [1]]]
#assert [unset? set/any 'r for-each x [] [1] 'r]
#assert [unset? set/any 'r for-each x [1 2 3] [continue] 'r]
#assert [unset? set/any 'r for-each x [1 2 3] [break] 'r]
#assert [123 =  set/any 'r for-each x [1 2 3] [break/return 123] 'r]
#assert [3 =    set/any 'r for-each x [1 2 3] [x] 'r]

;; spec unfolding tests
#assert [empty?    b: collect [for-each  x  [     ] [keep x]] 'b]
#assert [[1    ] = b: collect [for-each  x  [1    ] [keep x]] 'b]
#assert [[1 2  ] = b: collect [for-each  x  [1 2  ] [keep x]] 'b]
#assert [[1 2 3] = b: collect [for-each  x  [1 2 3] [keep x]] 'b]
#assert [[1    ] = b: collect [for-each [x] [1    ] [keep x]] 'b]
#assert [[1 2  ] = b: collect [for-each [x] [1 2  ] [keep x]] 'b]
#assert [[1 2 3] = b: collect [for-each [x] [1 2 3] [keep x]] 'b]
#assert [[[1 2] [3 #[none]]      ] = b: collect [for-each [x y] [1 2 3    ] [keep/only reduce [x y]]] 'b]
#assert [[[1 2] [3 4]            ] = b: collect [for-each [x y] [1 2 3 4  ] [keep/only reduce [x y]]] 'b]
#assert [[[1 2] [3 4] [5 #[none]]] = b: collect [for-each [x y] [1 2 3 4 5] [keep/only reduce [x y]]] 'b]

;; `continue` & `break` support
#assert [[1 2 3] = b: collect [for-each  x [1 2 3] [keep x continue]] 'b]
#assert [[     ] = b: collect [for-each  x [1 2 3] [continue keep x]] 'b]
#assert [[1    ] = b: collect [for-each  x [1 2 3] [keep x break]   ] 'b]

;; indexes & /reverse
#assert [[1 2 3] = b: collect [for-each [/i x]   [x y z]     [keep i       ]] 'b]
#assert [[1 2 3] = b: collect [for-each [p: x]   [x y z]     [keep index? p]] 'b]
#assert [[1 3 5] = b: collect [for-each [/i x y] [a b c d e] [keep i       ]] 'b]
#assert [[1 3 5] = b: collect [for-each [p: x y] [a b c d e] [keep index? p]] 'b]
#assert [[3 2 1] = b: collect [for-each/reverse [/i x]   [x y z]     [keep i       ]] 'b]
#assert [[3 2 1] = b: collect [for-each/reverse [p: x]   [x y z]     [keep index? p]] 'b]
#assert [[5 3 1] = b: collect [for-each/reverse [/i x y] [a b c d e] [keep i       ]] 'b]
#assert [[5 3 1] = b: collect [for-each/reverse [p: x y] [a b c d e] [keep index? p]] 'b]

;; /stride
#assert [[1 2 3] = b: collect [for-each/stride [x]           [1 2 3] [keep x]] 'b]
#assert [[1 2 3] = b: collect [for-each/stride [/i x]        [x y z] [keep i]] 'b]
#assert [[x y z] = b: collect [for-each/stride [/i x]        [x y z] [keep x]] 'b]
#assert [[1 2 3] = b: collect [for-each/stride [p: x]        [x y z] [keep index? p]] 'b]
#assert [[x y z] = b: collect [for-each/stride [p: x]        [x y z] [keep x]] 'b]
#assert [[[x y] [y z]] = b: collect [for-each/stride [x y]   [x y z] [keep/only reduce [x y]]] 'b]
#assert [[[x y z]    ] = b: collect [for-each/stride [x y z] [x y z] [keep/only reduce [x y z]]] 'b]
#assert [empty?          b: collect [for-each/stride [x y z] [x y]   [keep/only reduce [x y z]]] 'b]		;-- too short to fit in
#assert [[3 2 1] = b: collect [for-each/stride/reverse [x]           [1 2 3] [keep x]] 'b]
#assert [[3 2 1] = b: collect [for-each/stride/reverse [/i x]        [x y z] [keep i]] 'b]
#assert [[z y x] = b: collect [for-each/stride/reverse [/i x]        [x y z] [keep x]] 'b]
#assert [[3 2 1] = b: collect [for-each/stride/reverse [p: x]        [x y z] [keep index? p]] 'b]
#assert [[z y x] = b: collect [for-each/stride/reverse [p: x]        [x y z] [keep x]] 'b]
#assert [[[y z] [x y]] = b: collect [for-each/stride/reverse [x y]   [x y z] [keep/only reduce [x y]]] 'b]
#assert [[[x y z]    ] = b: collect [for-each/stride/reverse [x y z] [x y z] [keep/only reduce [x y z]]] 'b]
#assert [empty?          b: collect [for-each/stride/reverse [x y z] [x y]   [keep/only reduce [x y z]]] 'b]		;-- too short to fit in

;; any-string support
#assert [[#"a" #"b" #"c"] = b: collect [for-each c "abc" [keep c]] 'b]
#assert [[#"a" #"b" #"c"] = b: collect [for-each c <abc> [keep c]] 'b]
#assert [[#"a" #"b" #"c"] = b: collect [for-each c %abc  [keep c]] 'b]
#assert [[#"a" #"@" #"b"] = b: collect [for-each c a@b   [keep c]] 'b]
#assert [[#"a" #":" #"b"] = b: collect [for-each c a:b   [keep c]] 'b]

;; image support
#assert [im: make image! [2x2 #{111111 222222 333333 444444}]]
; #assert [[17.17.17.0 34.34.34.0 51.51.51.0 78.78.78.0] = b: collect [for-each c i [keep c]] 'b]		;@@ uncomment me when #4421 gets fixed
#assert [[1x1 2x1 1x2 2x2] = b: collect [for-each [/i c] im  [keep i]] 'b]				;-- special index for images - pair
#assert [[1 2 3 4        ] = b: collect [for-each [p: c] im  [keep index? p]] 'b]

;; 1D/2D ranges support
#assert [error? e: try [for-each [/i x] 2x2 []] 'e]										;-- indexes with ranges forbidden
#assert [error? e: try [for-each [p: x] 2x2 []] 'e]
#assert [[1x1 2x1 1x2 2x2] = b: collect [for-each i     2x2 [keep i]] 'b]				;-- unfold size into pixel coordinates
#assert [[1x1 1x2        ] = b: collect [for-each [i j] 2x2 [keep i]] 'b]
#assert [[1 3 5 7 9      ] = b: collect [for-each [i j] 10  [keep i]] 'b]				;-- unfold length into integers

;; maps support
#assert [error? e: try [for-each [p: x] #(1 2 3 4) []] 'e]								;-- no indexes for maps allowed
#assert [error? e: try [for-each [/i x] #(1 2 3 4) []] 'e]
#assert [[1 2 3 4        ] = b: collect [for-each [k v]       #(1 2 3 4) [keep k keep v]] 'b]		;-- map iteration is very relaxed
#assert [[1 2 3 4        ] = b: collect [for-each x           #(1 2 3 4) [keep x]]        'b]
#assert [[1 2 3 4 #[none]] = b: collect [for-each [a b c d e] #(1 2 3 4) [keep reduce [a b c d e]]] 'b]

;; vectors support
#assert [v: make vector! [1 2 3 4 5]]
#assert [[1 2 3 4 5              ] = b: collect [for-each  x    v [keep x]]                 'b]
#assert [[[1 2] [3 4] [5 #[none]]] = b: collect [for-each [x y] v [keep/only reduce [x y]]] 'b]

;; any-block support
#assert [[[1 2] [3 4] [5 #[none]]] = b: collect [for-each [x y] make hash!   [1 2 3 4 5] [keep/only reduce [x y]]] 'b]
#assert [[[1 2] [3 4] [5 #[none]]] = b: collect [for-each [x y] as paren!    [1 2 3 4 5] [keep/only reduce [x y]]] 'b]
; #assert [[[1 2] [3 4] [5 #[none]]] = b: collect [for-each [x y] as path!     [1 2 3 4 5] [keep/only reduce [x y]]] 'b]		;@@ uncomment me when #4421 gets fixed
; #assert [[[1 2] [3 4] [5 #[none]]] = b: collect [for-each [x y] as lit-path! [1 2 3 4 5] [keep/only reduce [x y]]] 'b]		;@@ uncomment me when #4421 gets fixed
; #assert [[[1 2] [3 4] [5 #[none]]] = b: collect [for-each [x y] as set-path! [1 2 3 4 5] [keep/only reduce [x y]]] 'b]		;@@ uncomment me when #4421 gets fixed
; #assert [[[1 2] [3 4] [5 #[none]]] = b: collect [for-each [x y] as get-path! [1 2 3 4 5] [keep/only reduce [x y]]] 'b]		;@@ uncomment me when #4421 gets fixed

;; pattern matching support
#assert [[#"3" 4       ] = b: collect [v: 4         for-each [x  :v                    ] [1 2.0 #"3" 4 'e] [keep reduce [x :v] ]] 'b]
#assert [[#"3" 4       ] = b: collect [v: #"3" w: 4 for-each [:v :w                    ] [1 2.0 #"3" 4 'e] [keep reduce [:v :w]]] 'b]
#assert [[1 2.0        ] = b: collect [             for-each [x [integer!]  y          ] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]] 'b]
#assert [[1 2.0 #"3" 4 ] = b: collect [             for-each [x             y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]] 'b]
#assert [[1 2.0 #"3" 4 ] = b: collect [             for-each [x [any-type!] y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]] 'b]
#assert [[#"3" 4       ] = b: collect [             for-each [x [char!]     y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]] 'b]
#assert [[#"3" 4       ] = b: collect [v: #"3"      for-each [:v            y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [:v y] ]] 'b]
#assert [[2 2 2 2      ] = b: collect [v: 2         for-each [:v   ]                     [2 2.0 #"^B" 2]   [keep :v] ] 'b]
#assert [[2 2.0 #"^B" 2] = b: collect [v: 2         for-each [p: :v]                     [2 2.0 #"^B" 2]   [keep p/1]] 'b]

;; /same & /case value filters
#assert [[2 2            ] =  b: collect [v: 2 for-each/case [p: :v] [2 2.0 #"^B" 2] [keep p/1]] 'b]
#assert [[2 2            ] =  b: collect [v: 2 for-each/same [p: :v] [2 2.0 #"^B" 2] [keep p/1]] 'b]
#assert [r: reduce [v: "v" w: "v" w uppercase copy v]]
#assert [["v" "v" "v" "V"] == b: collect [for-each           [p: :v] r [keep p/1]] 'b]
#assert [["v" "v" "v"    ] == b: collect [for-each/case      [p: :v] r [keep p/1]] 'b]
#assert [["v" "v"        ] == b: collect [for-each/same      [p: :w] r [keep p/1]] 'b]
#assert [["v"            ] == b: collect [for-each/same      [p: :v] r [keep p/1]] 'b]

;; `advance` support
#assert [[[2 3] #[none]] = b: collect [for-each  x    [1 2 3    ] [        keep/only advance]] 'b]
#assert [[[2 3 4] [4]  ] = b: collect [for-each  x    [1 2 3 4  ] [        keep/only advance]] 'b]
#assert [[[3 4] #[none]] = b: collect [for-each  x    [1 2 3 4  ] [advance keep/only advance]] 'b]
#assert [[[3 4]        ] = b: collect [for-each [x y] [1 2 3 4  ] [        keep/only advance]] 'b]
#assert [[[5]          ] = b: collect [for-each [x y] [1 2 3 4 5] [advance keep/only advance]] 'b]
#assert [[4 #[none]    ] = b: collect [for-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [set [x] advance keep x]] 'b]	;-- jumps to next match
#assert [[2.0 6        ] = b: collect [for-each [x [number!] ] [1 2.0 #"3" 4 'e 6] [set [x] advance keep x]] 'b]
#assert [[1 6          ] = b: collect [for-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [advance keep x]] 'b]			;-- does not affect the `x`

