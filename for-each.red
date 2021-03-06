Red [
	title:   "FOR-EACH loop"
	purpose: "Experimental design of an extended FOREACH"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		Unification of loops into a single declarative powerful construct!
		Same as we didn't invent a special loop for maps, we could reuse `foreach` for more use-cases:
			FOR-EACH [pos: color] image [...]	;) FORALL+FOREACH: color = pos/1 (tuple)
			FOR-EACH [/i x] other-series [...]	;) REPEAT+FOREACH: i is an integer, x = pick other-series i
			FOR-EACH [/xy color] image [...]	;) XYLOOP+FOREACH: xy is a pair, color = pick image xy (tuple)
			FOR-EACH xy size [...]				;) same as XYLOOP xy size
			FOR-EACH i n [...]					;) same as REPEAT i n
			FOR-EACH [i j] n [...]				;) generalized REPEAT - can dispatch multiple indexes at once
				we could generate a range of integers [1 2 .. n] and feed it to the loop:
					FOREACH i GEN-RANGE n [...]
				but what for?

		SPEC format:
			`x` (normal word) will be set to the next item, akin to native `foreach`
			`x [type!]` and `x [typeset!]` work the same, but check that the type of item matches
			   if type check fails for at least one of the items, `continue` is executed right away
			   Q: allow multiple types or not?
			   it's not very fast, to create typeset every time loop is initiated
			   OTOH sometimes this is nothing compared to convenience
			`:value` does not set any word, but checks that the item `x = get/any 'value`
			   if value check fails for at least one of the items, `continue` is executed right away
TODO: (expr) form instead of less general :value (latter can still be supported)
			`/i` will hold an index (not a counter!) of first item fetched
			   this index is relative to given series index, not to it's head:
			   `x = pick series i` rather than `x = pick head series i`
			`pos:` will hold series at index of first item (akin to `forall`):
			   `x = first pos`

		/reverse refinement
			Does NOT go from the tail to the head!
			instead, think of it as time reversal:
				>> for-each [x y z] [1 2 3 4 5] [print [x y z]]
				1 2 3
				4 5 none
				>> for-each/reverse [x y z] [1 2 3 4 5] [print [x y z]]
				4 5 none
				1 2 3
			If we started from the tail, this would have yielded `3 4 5`, then `none 2 3`
			with this design, you don't have to worry about whether items in the spec actually correspond to the data or not.
			Another reason for that is we can't `set [spec ...] at series -1` or other index before the head:
				series: [1 2 3 4 5]
				set [x y z] at series 3    ;) = [3 4 5] -- ok
				set [x y z] at series -1   ;) = [1 2 3] -- impossible to get [none 1 2] !
			so that would mean setting each single item in a loop rather than all at once, which is bad,
			and also would make `[pos: x y z]` return wrong `pos`, because `pos` will not refer to `none` but to series' head.
			See https://github.com/red/red/wiki/%5BPROP%5D-Series-evolution#free-unconstrained-index for a possible solution

		/stride refinement
			is meant for the cases where use 2-3 values to calculate a single derived value (e.g. centers of segments)
				>> for-each/stride [x y z] [1 2 3 4 5] [print [x y z]]
				1 2 3
				2 3 4
				3 4 5
			Also, /stride guarantees all items set:
				>> for-each/stride [x y z] [1 2] [print [x y z]]
				(never enters the body)
			Remaining question is - should /stride accept an integer step override? (ugly, goes after the loop body)
			Otherwise one can just call `advance` an extra time to increase step.
		/stride/reverse
			/stride aligns to segments of size=1, so again think of /reverse as time reversal:
				>> for-each/stride/reverse [x y z] [1 2 3 4 5] [print [x y z]]
				3 4 5
				2 3 4
				1 2 3

		See more at https://github.com/greggirwin/red-hof/tree/master/code-analysis#foreach

		Limitations & design notes:
		- diverts RETURN & EXIT
		- obviously it's somewhat slow, being a mezz
		- not leveraging hashtable's fast lookups capability yet
		- can't base it on PARSE or native FOREACH, because both can't go in /reverse direction
		- `:value` warrants /case and /same refinements - not implemented yet
		- `pos:` is incompatible with maps, on `/i` I haven't decided: should it be like 1,2,3... or like 1,3,5 (as we advance by pairs)?
		  convert it `to block!` explicitly to get indexes!
		- `pos:` syntax is not allowed on integer/pair ranges, otherwise we would have to generate the block for that range
		  `/i` syntax is also forbidden for ranges, because - what's the point of it?
		- when iterating forward and the series grows/shrinks, follows native foreach behavior, i.e. adapts to the new length
		- spec length is unrestricted for maps: [x] [x y] [x y z] [x y z w] - everything will work, though might not make much sense
		- typed patterns may never match when used on vectors of other type, but there isn't any dedicated prediction code (should there be?)
		- not gonna work with images/paths until #4421 gets fixed
		- ADVANCE is provided to the code block, see https://github.com/greggirwin/red-hof/tree/master/code-analysis#on-demand-advancement
		  keep in mind: when using filters, advance will jump to the next *match*!
		  also, when iterating on ranges, the spec returned by it is fake - it will be changed in place with each new `advance` call
		- words in the spec are now contained to the body, so no /local ado required
	}
]

#include %new-each.red

; #include %localize-macro.red
; #include %assert.red
; #include %error-macro.red
; #include %bind-only.red

; context [
	; ;;@@ TODO: use `find` for better speed when using masks?
	; ;;   unfortunately `find` is limited to types, not working with typesets
	; ;;   no big loss for types? find with types is not gonna be fast anyway as it can't leverage hashmap
	; ;;   for values masks it'll be great though
	; ;; quirk of `find` that makes it still very complicated:
	; ;; >> find reduce [integer!] integer!
	; ;; == [integer!]
	; ;; when looking up by value - if this value is a datatype, it should be wrapped into a block: [integer!]


	; ;; pattern matching support funcs:
	; ;;@@ TODO: fastest(?) way to check values' types - call a function - do that once `apply` is a native
	; ;;         otherwise will have to compose the call each time (insert `quote` at least, so that's not faster yet)
	; types-match?: func [series types /local i] [
		; repeat i length? types [
			; unless find types/:i type? :series/:i [return no]
		; ]
		; yes
	; ]
	; values-match?: func [series values values-mask op /local i] [
		; repeat i length? values [
			; all [
				; :values-mask/:i
				; not :series/:i op :values/:i
				; return no
			; ]
		; ]
		; yes
	; ]
	; #assert [values-match? [1 2 3] [3 3 3] [#[none] #[none] 3] :=]

	; set-able!: make typeset! [block! paren! hash!]		;-- `set` vs `foreach` - see below
	; ranges!:   make typeset! [integer! pair!]			;-- supported non-series types
	; is-range?: func [x] [find ranges! type? :x]

	; ;; helpers for non-series types (ranges) iteration:
	; int2pair: func [i [integer!] w [integer!]] [as-pair  i - 1 % w + 1  i - 1 / w + 1]
	; fill-int-range: func [range [block!] from [integer!] dim [integer!]] [
		; repeat i length? range [
			; range/:i: all [from <= dim  from]			;-- none after the 'tail'
			; from: from + 1
		; ]
		; from
	; ]
	; fill-pair-range: func [range [block!] from [integer!] dim [pair!]] [
		; repeat i length? range [
			; xy: int2pair from dim/x
			; range/:i: all [xy/y <= dim/y  xy]			;-- none after the 'tail'
			; from: from + 1
		; ]
		; from
	; ]

	; ;; `compose` readability helper
	; when: make op! func [value test] [either :test [:value][[]]]

	; set 'for-each function [
		; "Evaluate CODE for each match of the SPEC on SERIES"
		; 'spec  [word! block!]                "Words & index to set, values/types to match"
		; series [series! map! pair! integer!] "Series, map or range"
		; code   [block!]                      "Code to evaluate"
		; /reverse "Traverse in the opposite direction"
		; /stride  "Lock step at 1 (or -1 for reverse), while setting all SPEC words"
		; /case    "For get-words only: use strict comparison"
		; /same    "For get-words only: use sameness comparison"
		; /local _ w x r index-word
	; ][
		; val-cmp-op: get pick pick [[=? =?] [== =]] same case
		; case: :system/words/case
		; if case [
			; integer? series [series <= 0]
			; pair?    series [any [series/x <= 0 series/y <= 0]]
			; 'else [empty? series]
		; ] [exit]										;-- optimization; also works for /reverse, as we don't go before the current index

		; ;; spec preprocessing
		; spec: compose [(spec)]											;-- `to block! spec` doesn't copy it, but it'll be modified!
		; types: copy														;-- types for typed pattern matching
			; values: copy												;-- values for matching by value
				; values-mask: copy []									;-- what values should be checked
		; parse spec [
			; remove set index-word opt [refinement! | set-word!]			;-- none / refinement / setword
			; some [
				; [	set word word!										;-- word
					; remove set type opt [block! (use-types?: yes)]		;-- [types]
					; (get-word: none)
				; |	change set get-word get-word! ('_)					;-- :word
					; (word: type: none  use-values?: yes)
				; |	spec: (ERROR "Unexpected spec format (mold spec)")
				; ](
					; append types either type [make typeset! type][any-type!]
					; append values-mask get-word
				; )
			; ]
			; end | (ERROR "Spec must contain words or get-words!")
		; ]																;-- spec is now native-foreach-compatible
		; filtered?: yes = any [use-types? use-values?]
		; values: reduce values-mask
		; size: length? spec												;-- number of values to set/check each time
		; #assert [
			; size = length? values-mask
			; size = length? values
			; size = length? types
		; ]
		; range?: is-range? series
		; case [
			; range? [if index-word [ERROR "Can't use indexes with integer/pair ranges"]]
			; map? series [
				; if index-word [ERROR "Can't use indexes when iterating over map"]
				; series: to block! series
			; ]
		; ]

		; ;; step length & direction, end condition
		; step: either stride [1][size]									;-- number of items to skip every time
		; ahead: size - step + 1											;-- number of items should be guaranteed ahead
		; either reverse [
			; length: case [
				; not range?   [length? series]
				; pair? series [series/x * series/y]
				; 'else        [series]
			; ]
			; index: length - either stride [size - 1][length - 1 % step]	;-- align to starting offset rather than the tail
			; end-cond: [index <= 0]										;-- this works even if series is not at head initially
			; step: 0 - step
		; ][
			; index: 1
			; end-cond: compose either range? [
				; length: either integer? series [series][series/x * series/y]
				; [index + (ahead - 1) > (length)]
			; ][
				; [index + (ahead - 1) > length? series]					;-- length must be dynamically checked in case series grows
			; ]
		; ]
		; all [stride  do end-cond  exit]									;-- optimization for /stride: full spec never fits the series

		; ;; optimization: trim masks from unnecessary checks
		; ;;@@ (trim/tail/with is buggy, see #4210) -- use it when it's fixed
		; case/all [
			; use-types?  [while [any-type! = last types] [take/last types]]
			; use-values? [while [none? last values-mask] [take/last values take/last values-mask]]
		; ]

		; ;; before we're gonna use spec & index, stop spec words from leaking out and contain them within for-each's body
		; bind spec ctx: context parse spec [collect [
			; some [set w word! keep (to set-word! w)]
			; opt [if (index-word) keep (to set-word! index-word)]
			; keep ('none)
		; ]]
		; if index-word [index-word-bound: bind to word! index-word ctx]

		; ;; build user-provided index assignment code
		; upd-idx: []														;-- empty if no index requested
		; if index-word [
			; upd-idx: case [
				; set-word? index-word ['where]							;-- series index
				; not image? series    ['index]							;-- integer index
				; 'image [ compose [int2pair index (series/size/x)] ]		;-- images receive special pair! index instead of integer!
			; ]
			; upd-idx: compose [(to set-word! index-word-bound) (upd-idx)]
		; ]

		; ;; set up the series pointer & decide what code is needed to fill fake series for ranges
		; either range? [
			; where: append/dup copy [] 0 size							;-- generate a fake series to fill the items with
			; refill: compose pick [										;-- spec filling code for ranges
				; [fill-int-range  where index (length)]
				; [fill-pair-range where index (series)]
			; ] integer? series
		; ][
			; where: at series index
		; ]

		; ;; build code that sets the spec on each iteration
		; prefix: pick [ [old:] [] ] filtered?							;-- `old:` is required for checks as they come after index advancement
		; spec-fill: compose/deep pick [
			; [set [(spec)] (prefix) where]								;-- only block!, paren!, hash! are working with set-syntax
			; [	(refill when range?)									;-- ranges require to populate the spec every time
				; foreach [(spec)] (prefix) where [break]					;-- everything other series type requires this hack
			; ]
		; ] yes = find set-able! type? series

		; ;; build type/value checking code
		; test: []
		; if filtered? [
			; type-check:   [types-match?  old types]
			; values-check: [values-match? old values values-mask :val-cmp-op]
			; test: compose [												;-- combine both checks
				; (type-check   when use-types?)
				; (values-check when use-values?)
			; ]
			; if all [use-types? use-values?] [							;-- wrap them in `all` block if needed
				; test: compose/deep [all [(test)]]
			; ]
			; test: compose [unless (test) [continue]]
		; ]

		; ;; build & expose `advance`
		; move-idxs: compose [
			; ([where: at series] when not range?)						;-- if `range?` then `where = spec` constantly
			; index: (step) + index
		; ]
		; advance: does compose/deep [
			; while [not (end-cond)] [
				; old: where												;-- save current (already moved) position for returning it
				; (move-idxs)												;-- advance further
				; (test when filtered?)									;-- `continue` if no match
				; return old
			; ]
			; none														;-- return none when at the end
		; ]
		
		; ;; expose 'advance' and contain the spec words
		; bind-only code compose [										;-- should be okay to bind it in place
			; advance (spec) (index-word-bound when index-word)
		; ]

		; unset 'r														;-- return unset if never entered
		; do compose/deep [
			; set/any 'r forever [										;-- can't use `while` because it does not return value (needed for break/return)
				; if (end-cond) [break/return :r]
				; ;; set user index and fill the spec before advancing!
				; (upd-idx) (spec-fill)
				; ;; advance before do-ing the code - otherwise it will stall on `continue`!
				; (move-idxs)												;-- inlined `advance` for more juice
				; ;; tests may call `continue` so they follow `move-idxs`
				; (test)

				; set/any 'r do code										;-- using `do` to assign the *last* value to `r`
			; ]
		; ]
		; :r
	; ]
; ]


; ;; return value tests
; #localize [#assert [
	; error? try [for-each [] [1] [1]]
	; unset? for-each x [] [1]
	; unset? for-each x [1 2 3] [continue]
	; unset? for-each x [1 2 3] [break]
	; 123 =  for-each x [1 2 3] [break/return 123]
	; 3 =    for-each x [1 2 3] [x]

	; ;; spec unfolding tests
	; empty?    collect [for-each  x  [     ] [keep x]]
	; [1    ] = collect [for-each  x  [1    ] [keep x]]
	; [1 2  ] = collect [for-each  x  [1 2  ] [keep x]]
	; [1 2 3] = collect [for-each  x  [1 2 3] [keep x]]
	; [1    ] = collect [for-each [x] [1    ] [keep x]]
	; [1 2  ] = collect [for-each [x] [1 2  ] [keep x]]
	; [1 2 3] = collect [for-each [x] [1 2 3] [keep x]]
	; [[1 2] [3 #[none]]      ] = collect [for-each [x y] [1 2 3    ] [keep/only reduce [x y]]]
	; [[1 2] [3 4]            ] = collect [for-each [x y] [1 2 3 4  ] [keep/only reduce [x y]]]
	; [[1 2] [3 4] [5 #[none]]] = collect [for-each [x y] [1 2 3 4 5] [keep/only reduce [x y]]]

	; ;; `continue` & `break` support
	; [1 2 3] = collect [for-each  x [1 2 3] [keep x continue]]
	; [     ] = collect [for-each  x [1 2 3] [continue keep x]]
	; [1    ] = collect [for-each  x [1 2 3] [keep x break]   ]

	; ;; indexes & /reverse
	; [1 2 3] = collect [for-each [/i x]   [x y z]     [keep i       ]]
	; [1 2 3] = collect [for-each [p: x]   [x y z]     [keep index? p]]
	; [1 3 5] = collect [for-each [/i x y] [a b c d e] [keep i       ]]
	; [1 3 5] = collect [for-each [p: x y] [a b c d e] [keep index? p]]
	; [3 2 1] = collect [for-each/reverse [/i x]   [x y z]     [keep i       ]]
	; [3 2 1] = collect [for-each/reverse [p: x]   [x y z]     [keep index? p]]
	; [5 3 1] = collect [for-each/reverse [/i x y] [a b c d e] [keep i       ]]
	; [5 3 1] = collect [for-each/reverse [p: x y] [a b c d e] [keep index? p]]

	; ;; /stride
	; [1 2 3] = collect [for-each/stride [x]           [1 2 3] [keep x]]
	; [1 2 3] = collect [for-each/stride [/i x]        [x y z] [keep i]]
	; [x y z] = collect [for-each/stride [/i x]        [x y z] [keep x]]
	; [1 2 3] = collect [for-each/stride [p: x]        [x y z] [keep index? p]]
	; [x y z] = collect [for-each/stride [p: x]        [x y z] [keep x]]
	; [[x y] [y z]] = collect [for-each/stride [x y]   [x y z] [keep/only reduce [x y]]]
	; [[x y z]    ] = collect [for-each/stride [x y z] [x y z] [keep/only reduce [x y z]]]
	; empty?          collect [for-each/stride [x y z] [x y]   [keep/only reduce [x y z]]]		;-- too short to fit in
	; [3 2 1] = collect [for-each/stride/reverse [x]           [1 2 3] [keep x]]
	; [3 2 1] = collect [for-each/stride/reverse [/i x]        [x y z] [keep i]]
	; [z y x] = collect [for-each/stride/reverse [/i x]        [x y z] [keep x]]
	; [3 2 1] = collect [for-each/stride/reverse [p: x]        [x y z] [keep index? p]]
	; [z y x] = collect [for-each/stride/reverse [p: x]        [x y z] [keep x]]
	; [[y z] [x y]] = collect [for-each/stride/reverse [x y]   [x y z] [keep/only reduce [x y]]]
	; [[x y z]    ] = collect [for-each/stride/reverse [x y z] [x y z] [keep/only reduce [x y z]]]
	; empty?          collect [for-each/stride/reverse [x y z] [x y]   [keep/only reduce [x y z]]]		;-- too short to fit in

	; ;; any-string support
	; [#"a" #"b" #"c"] = collect [for-each c "abc" [keep c]]
	; [#"a" #"b" #"c"] = collect [for-each c <abc> [keep c]]
	; [#"a" #"b" #"c"] = collect [for-each c %abc  [keep c]]
	; [#"a" #"@" #"b"] = collect [for-each c a@b   [keep c]]
	; [#"a" #":" #"b"] = collect [for-each c a:b   [keep c]]

	; ;; image support
	; im: make image! [2x2 #{111111 222222 333333 444444}]
	; [17.17.17.0 34.34.34.0 51.51.51.0 78.78.78.0] = collect [for-each c i [keep c]]		;@@ uncomment me when #4421 gets fixed
	; [1x1 2x1 1x2 2x2] = collect [for-each [/i c] im  [keep i]]				;-- special index for images - pair
	; [1 2 3 4        ] = collect [for-each [p: c] im  [keep index? p]]

	; ;; 1D/2D ranges support
	; error? try [for-each [/i x] 2x2 []]										;-- indexes with ranges forbidden
	; error? try [for-each [p: x] 2x2 []]
	; [1x1 2x1 1x2 2x2] = collect [for-each i     2x2 [keep i]]				;-- unfold size into pixel coordinates
	; [1x1 1x2        ] = collect [for-each [i j] 2x2 [keep i]]
	; [1 3 5 7 9      ] = collect [for-each [i j] 10  [keep i]]				;-- unfold length into integers

	; ;; maps support
	; error? try [for-each [p: x] #(1 2 3 4) []]								;-- no indexes for maps allowed
	; error? try [for-each [/i x] #(1 2 3 4) []]
	; [1 2 3 4        ] = collect [for-each [k v]       #(1 2 3 4) [keep k keep v]]		;-- map iteration is very relaxed
	; [1 2 3 4        ] = collect [for-each x           #(1 2 3 4) [keep x]]       
	; [1 2 3 4 #[none]] = collect [for-each [a b c d e] #(1 2 3 4) [keep reduce [a b c d e]]]

	; ;; vectors support
	; v: make vector! [1 2 3 4 5]
	; [1 2 3 4 5              ] = collect [for-each  x    v [keep x]]                
	; [[1 2] [3 4] [5 #[none]]] = collect [for-each [x y] v [keep/only reduce [x y]]]

	; ;; any-block support
	; [[1 2] [3 4] [5 #[none]]] = collect [for-each [x y] make hash!   [1 2 3 4 5] [keep/only reduce [x y]]]
	; [[1 2] [3 4] [5 #[none]]] = collect [for-each [x y] as paren!    [1 2 3 4 5] [keep/only reduce [x y]]]
	; [[1 2] [3 4] [5 #[none]]] = collect [for-each [x y] as path!     [1 2 3 4 5] [keep/only reduce [x y]]]		;@@ uncomment me when #4421 gets fixed
	; [[1 2] [3 4] [5 #[none]]] = collect [for-each [x y] as lit-path! [1 2 3 4 5] [keep/only reduce [x y]]]		;@@ uncomment me when #4421 gets fixed
	; [[1 2] [3 4] [5 #[none]]] = collect [for-each [x y] as set-path! [1 2 3 4 5] [keep/only reduce [x y]]]		;@@ uncomment me when #4421 gets fixed
	; [[1 2] [3 4] [5 #[none]]] = collect [for-each [x y] as get-path! [1 2 3 4 5] [keep/only reduce [x y]]]		;@@ uncomment me when #4421 gets fixed

	; ;; pattern matching support
	; [#"3" 4       ] = collect [v: 4         for-each [x  :v                    ] [1 2.0 #"3" 4 'e] [keep reduce [x :v] ]]
	; [#"3" 4       ] = collect [v: #"3" w: 4 for-each [:v :w                    ] [1 2.0 #"3" 4 'e] [keep reduce [:v :w]]]
	; [1 2.0        ] = collect [             for-each [x [integer!]  y          ] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]]
	; [1 2.0 #"3" 4 ] = collect [             for-each [x             y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]]
	; [1 2.0 #"3" 4 ] = collect [             for-each [x [any-type!] y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]]
	; [#"3" 4       ] = collect [             for-each [x [char!]     y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]]
	; [#"3" 4       ] = collect [v: #"3"      for-each [:v            y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [:v y] ]]
	; [2 2 2 2      ] = collect [v: 2         for-each [:v   ]                     [2 2.0 #"^B" 2]   [keep :v] ]
	; [2 2.0 #"^B" 2] = collect [v: 2         for-each [p: :v]                     [2 2.0 #"^B" 2]   [keep p/1]]

	; ;; /same & /case value filters
	; [2 2            ] =  collect [v: 2 for-each/case [p: :v] [2 2.0 #"^B" 2] [keep p/1]]
	; [2 2            ] =  collect [v: 2 for-each/same [p: :v] [2 2.0 #"^B" 2] [keep p/1]]
	; r: reduce [v: "v" w: "v" w uppercase copy v]
	; ["v" "v" "v" "V"] == collect [for-each           [p: :v] r [keep p/1]]
	; ["v" "v" "v"    ] == collect [for-each/case      [p: :v] r [keep p/1]]
	; ["v" "v"        ] == collect [for-each/same      [p: :w] r [keep p/1]]
	; ["v"            ] == collect [for-each/same      [p: :v] r [keep p/1]]

	; ;; `advance` support
	; [[2 3] #[none]] = collect [for-each  x    [1 2 3    ] [        keep/only advance]]
	; [[2 3 4] [4]  ] = collect [for-each  x    [1 2 3 4  ] [        keep/only advance]]
	; [[3 4] #[none]] = collect [for-each  x    [1 2 3 4  ] [advance keep/only advance]]
	; [[3 4]        ] = collect [for-each [x y] [1 2 3 4  ] [        keep/only advance]]
	; [[5]          ] = collect [for-each [x y] [1 2 3 4 5] [advance keep/only advance]]
	; [4 #[none]    ] = collect [for-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [set [x] advance keep x]]	;-- jumps to next match
	; [2.0 6        ] = collect [for-each [x [number!] ] [1 2.0 #"3" 4 'e 6] [set [x] advance keep x]]
	; [1 6          ] = collect [for-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [advance keep x]]			;-- does not affect the `x`

	; ;; confirm that there's no leakage
	; (x: 1     for-each x     [2 3 4] [x: x * x]  x = 1)
	; (x: y: 1  for-each [x y] [2 3 4] [x: y: 0]   all [x = 1 y = 1])
; ]]

; b: make hash! reduce [[1] make hash! [2] o: object [x: 3] o o o [4]]
; for-each [x [block! hash!]] b [probe x]
