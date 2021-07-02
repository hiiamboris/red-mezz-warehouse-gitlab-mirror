Red [
	title:   "*EACH loops"
	purpose: "Experimental new design of extended FOREACH, MAP-EACH, REMOVE-EACH"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		See foreach-design.md for info
	}
]

; recycle/off
#include %assert.red
#include %error-macro.red
; #include %bind-only.red
#include %setters.red
#include %selective-catch.red
#include %reshape.red

; #include %show-trace.red

context [
	;-- this should be straightforward and fast in R/S
	;-- one particular side effect of type checking is we can avoid/accept `none` we get when outside series limits
	types-match?: function [
		"Check if items in SERIES match TFILTER"
		ii [object!]
	][
		s: skip ii/series ii/offset
		foreach i ii/tfilter-idx [
			unless find ii/tfilter/:i type? :s/:i [return no]
		]
		yes
	]

	;-- this should also be a piece of cake
	;-- again, value can be used to filter in/out `none` values outside series limits
	values-match?: function [
		"Check if items in SERIES match VFILTER for all chosen VFILTER-IDX"
		ii [object!]
	][
		op: :ii/cmp
		s: skip ii/series ii/offset
		foreach i ii/vfilter-idx [
			unless :s/:i op :ii/vfilter/:i [return no]
			if tail? at s i [return no]					;-- special case: after-the-tail `none` should not count as sought value=none
		]												;@@ TODO: raise this design question in docs
		yes
	]
	; #assert [r: values-match? [1 2 3] [   ] [3 2 3] := 'r]
	; #assert [r: values-match? [1 2 3] [3  ] [3 2 3] := 'r]
	; #assert [r: values-match? [1 2 3] [2 3] [3 2 3] := 'r]

	ranges!:   make typeset! [integer! pair!]			;-- supported non-series types
	is-range?: func [x] [find ranges! type? :x]

	;; helpers for non-series types (ranges) iteration:
	int2pair: func [i [integer!] w [integer!]] [1x1 + as-pair  i - 1 % w  i - 1 / w]
	fill-with-ints: function [spec [block!] from [integer!] dim [integer!]] [
		foreach w spec [
			set w all [from <= dim  from]				;-- none after the 'tail'
			from: from + 1
		]
	]
	fill-with-pairs: function [spec [block!] from [integer!] dim [pair!]] [
		foreach w spec [
			xy: int2pair from dim/x
			set w all [xy/y <= dim/y  xy]				;-- none after the 'tail'
			from: from + 1
		]
	]
	append-ints: function [tgt [block!] from [integer!] count [integer!]] [
		loop count [
			append tgt from
			from: from + 1
		]
	]
	append-pairs: function [tgt [block!] from [integer!] count [integer!] dim [pair!]] [
		loop count [
			append tgt int2pair from dim/x
			from: from + 1
		]
	]

	;; `compose` readability helper - won't be needed in RS
	when: make op! func [value test] [either :test [:value][[]]]


	;-- this structure is required to share data between functions
	;-- (although it's one step away from a proper iterator type)
	;-- in R/S it will be set by foreach and used by foreach-next
	iteration-info!: object [
		matched?:    no
		offset:      0				;-- zero-based; cannot (easily) be series, as need to be able to point past the end or before the head
		iter:        0

		spec:        none
		series:      none
		code:        none
		cmp:         none
		fill:        none			;-- how many words to fill in the spec at every iteration - if series is shorter, fails
		width:       0				;-- how many words are in the spec (to fill)
		step:        none			;-- none value is used to detect duplicate pipes; <0 if iterating backward
		vfilter:     none			;-- none when filter is not used
		vfilter-idx: none
		tfilter:     none			;-- none when filter is not used
		tfilter-idx: none
		pos-word:    none
		idx-word:    none
	]

	fill-info: function [
		spec [word! block!]
		series [series! map! pair! integer!]
		code [block!]
		back-flag [logic!]
		case-flag [logic!]
		same-flag [logic!]
	][
		if case [
			integer? series [series <= 0]
			pair?    series [any [series/x <= 0 series/y <= 0]]
			'else [empty? series]
		] [return none]			;-- optimization; also works for /reverse, as we don't go before the current index

		on-series?: series? series
		if map? series [
			series: to hash! series
			forall series [								;@@ temporary adjustment - won't be needed in RS
				if set-word? :series/1 [series/1: to word! series/1]
			]
		]

		ii: copy iteration-info!
		ii/spec:   spec: compose [(spec)]
		ii/series: series
		ii/code:   code
		ii/cmp: get pick pick [[=? =?] [== =]] same-flag case-flag
		if all [same-flag case-flag] [
			ERROR "/case and /same refinements are mutually exclusive"
		]

		switch type?/word spec/1 [						;@@ TODO: consider supporting both iteration and position?
			set-word! [
				ii/pos-word: to word! spec/1
				unless on-series? [						;-- fail on ranges and maps (latter cannot be modified as series)
					ERROR "Series index can only be used when iterating over series"
				]
				remove spec
			]
			refinement! [
				ii/idx-word: to word! spec/1
				remove spec
			]
		]

		ii/vfilter:     copy []
		ii/tfilter:     copy []
		ii/vfilter-idx: copy []
		ii/tfilter-idx: copy []
		while [not tail? spec] [
			value: types: none
			switch/default type?/word spec/1 [
				paren! [
					if is-range? series [				;-- complicates filter and makes little sense
						ERROR "Cannot use value filters on ranges"
					]
					set/any 'value do spec/1
					append ii/vfilter-idx index? spec
					change spec anonymize '_ none		;-- at R/S side it will be just dumb loop rather than single `set`
				]
				word! [
					case [
						spec/1 = '| [
							if ii/step [ERROR "Duplicate pipe in spec"]
							ii/fill: yes
							ii/step: -1 + index? spec
							; if ii/step = 0 [ERROR ""]	;@@ error or not? one can use such loop to advance manually
							remove spec
							continue					;-- don't add this entry
						]
						block? spec/2 [
							if is-range? series [		;-- pointless: we always know the item type in ranges
								ERROR "Cannot use type filters on ranges"
							]
							;@@ TODO: use single typesets and types as is, without allocating a new typeset
							types: make typeset! spec/2
							append ii/tfilter-idx index? spec
							remove next spec
						]
					]
				]
			][
				ERROR "Unexpected occurrence of (mold spec/1) in spec"
			]
			append/only ii/vfilter :value
			append/only ii/tfilter :types
			spec: next spec
		]												;-- spec is now native-foreach-compatible
		spec: head spec
		if empty? spec [ERROR "Spec must contain at least one mandatory word"]

		#assert [(length? spec) = length? ii/vfilter]
		#assert [(length? spec) = length? ii/tfilter]

		if empty? ii/tfilter-idx [ii/tfilter: ii/tfilter-idx: none]		;-- disable empty filters
		if empty? ii/vfilter-idx [ii/vfilter: ii/vfilter-idx: none]

		ii/width: length? spec
		ii/step: any [ii/step ii/width]
		ii/fill: either ii/fill [ii/width][1]
		if all [0 = ii/step  not ii/pos-word] [
			ERROR "Zero step is only allowed with series index"			;-- otherwise deadlocks
		]

		ii/offset: 0
		if back-flag [									;-- requires step known
			n: case [
				integer? series [series]
				pair? series [series/x * series/y]
				'else [length? series]
			]
			n: n - ii/fill								;-- ensure needed number of words is filled
			; n: round/floor/to n max 1 ii/step			;-- align to step
			n: n - (n % max 1 ii/step)					;-- align to step
			if pair? p: series [n: as-pair  n % p/x  n / p/x]
			ii/offset: n
		]

		if back-flag [ii/step: 0 - ii/step]

		;@@ in R/S we won't need this, as `function` supports `foreach`:
		anon-ctx: construct collect [
			foreach w spec [keep to set-word! w]
			if ii/pos-word [keep to set-word! ii/pos-word]
			if ii/idx-word [keep to set-word! ii/idx-word]
		]
		bind ii/spec anon-ctx
		if ii/pos-word [ii/pos-word: bind ii/pos-word anon-ctx]
		if ii/idx-word [ii/idx-word: bind ii/idx-word anon-ctx]
		bind ii/code anon-ctx

		ii					;-- fill OK
	]


	more-of?: function [ii [object!] size [integer!]] [
		either ii/step < 0 [
			ii/offset >= 0
		][
			case [
				pair? ii/series [
					ii/series/x * ii/series/y - ii/offset >= size
				]
				integer? ii/series [
					ii/series - ii/offset >= size
				]
				'else [
					(length? ii/series) - ii/offset >= size	;-- supports series length change during iteration
				]
			]
		]
	]

	more-items?: function [ii [object!]] [more-of? ii 1]
	more-iterations?: function [ii [object!]] [more-of? ii ii/fill]

	copy-to: function [
		"Append a part of II/series into TGT"
		tgt  [series!]
		ii   [object!] "iterator info"
		ofs  [integer! series!] "from where to start a copy"
		part [integer! series! none!] "number of items or offset; none for unbound copy"
	][
		case [
			series? ii/series [
				src: skip ii/series ofs
				part: either part [
					copy/part src part					;@@ append/part doesn't work - #4336
				][	copy      src						;-- still need a copy so series is not shared (in case appending a string to block)
				]
				if vector? part [part: to [] part]		;@@ workaround: append block vector enforces /only
				append tgt part
			]
			integer? ii/series [
				unless part [part: ii/series - ofs - 1]
				append-ints  tgt 1 + ofs part
			]
			'pair [
				unless part [part: ii/series/x * ii/series/y - ofs - 1]
				append-pairs tgt 1 + ofs part ii/series
			]
		]
	]


	;@@ should maps iteration be restricted to [k v] or not?
	;@@ I don't like arbitrary restrictions, but here it's a question of how easy it will be
	;@@ to support unrestricted iteration in possible future implementations of maps
	;@@ leave this question in docs!

	{
		for-each allows loop body to modify `pos:` and then possibly call `continue`
		in R/S we'll be able to catch `continue` directly
		in Red it's tricky: need to not let `continue` mess index logic, and yet allow `break` somehow
		the only solution I've found is to save the pos-word, then check it for changes before each iteration
	}

	for-each-core: function [
		ii [object!] "iteration info"
		on-iteration [block!] "evaluated when spec matches"
		after-iteration [block!] "evaluated after on-iteration succeeds and offsets are updated"
		/local new-pos
	][
		upd-pos-word?: [								;-- code that reads user modifications of series position
			if ii/pos-word [
				set/any 'new-pos get/any ii/pos-word
				unless series? :new-pos [
					ERROR "(ii/pos-word) does not refer to series"
				]
				unless same? head new-pos head ii/series [	;-- most likely it's a bug, so we report it
					ERROR "(ii/pos-word) was changed to another series"
				]
				ii/offset: -1 + index? new-pos
			]
		]

		to-next-possible-match: [						;-- by default tries to match series at every step
			if more-iterations? ii [ii/iter: ii/iter + 1]
		]
		if all [										;-- however when vfilter is defined...
			ii/vfilter									;-- we can use find to faster locate matches, esp. on hash & map
			ii/step <> 0								;-- but step=0 means find direction is undefined and can't benefit from this optimization
		][
			val-ofs: ii/vfilter-idx/1
			val: ii/vfilter/:val-ofs
			if typeset? :val [							;@@ #4911 - typeset is too smart - this is a workaround
				val: compose [(val)]					;@@ however this still disables hash advantages
				no-only?: yes							;@@ to be removed once #4911 is fixed
			]
			|skip|: absolute ii/step

			if all [
				ii/step < 0									;-- when going backwards
				tail? at skip ii/series ii/offset val-ofs	;-- and sought value is after the tail
			][
				ii/offset: ii/offset - |skip|				;-- then we can skip this iteration already
				ii/iter: ii/iter + 1						;-- as after-the-tail `none` does not count as value `none`
			]
			;-- this special case may be disabled
			;-- but then `from` may be misaligned with `/skip` as Red doesn't allow after-the-tail positioning
			;-- so if disabled, it will require special index adjustment during first two iterations (should be easier in RS)

			find-call: as path! compose [				;-- construct a relevant `find` call
				find
				skip
				('reverse when (ii/step < 0))
				('only when not no-only?)				;@@ /only disables "type!" smarts, but not "typeset!" - #4911
				('case when (:ii/cmp =? :strict-equal))
				('same when (:ii/cmp =? :same?))
			]

			to-next-possible-match: reshape [
				all [
					pos: !(find-call) from: at skip ii/series ii/offset val-ofs :val |skip|
					ii/offset: (index? pos) - val-ofs
					more-iterations? ii
					ii/iter: add  ii/iter  (offset? from pos) / ii/step
				]
			]
		]

		catch-a-break [									;@@ destroys break/return value
			while to-next-possible-match [
				;-- do all updates before calls to `continue` are possible
				case [
					ii/pos-word [set ii/pos-word skip ii/series ii/offset]
					ii/idx-word [set ii/idx-word ii/iter]	;-- unfortunately with this design, image does not get a pair index
				]

				;-- do filtering
				if ii/matched?: all [
					any [not ii/tfilter  types-match? ii]
					any [not ii/vfilter  values-match? ii]
				][
					;-- fill the spec - only if matched
					case [
						series?  ii/series [foreach (ii/spec) skip ii/series ii/offset [break]]
						integer? ii/series [fill-with-ints  ii/spec 1 + ii/offset ii/series]
						'pair              [fill-with-pairs ii/spec 1 + ii/offset ii/series]
					]
					catch-continue [
						continued?: yes
						do on-iteration
						continued?: no
					]
				]

				do upd-pos-word?
				ii/offset: ii/offset + ii/step
				if all [ii/matched? not continued?] after-iteration
			]
		]
	]

	;-- the frontend
	set 'for-each function [
		"Evaluate CODE for each match of the SPEC on SERIES"
		'spec  [word! block!]                "Words & index to set, values/types to match"
		series [series! map! pair! integer!] "Series, map or limit"
		code   [block!]                      "Code to evaluate"
		/reverse "Traverse in the opposite direction"
		/case    "Values are matched using strict comparison"
		/same    "Values are matched using sameness comparison"
		/local r
	][
		unset 'r										;-- returns unset by default (empty series, fill-info failed)
		if ii: fill-info spec series code reverse case same [
			for-each-core ii [
				if ii/matched? [						;-- not matched iterations do not affect the result
					unset 'r							;-- in case of `continue`, result will be unset
					set/any 'r do ii/code
				]
			] []
		]
		:r
	]

	set 'map-each function [
		"Map SERIES into a new one and return it"
		'spec  [word! block!]                "Words & index to set, values/types to match"
		series [series! map! pair! integer!] "Series, map or range"
		code   [block!]                      "Should return the new item(s)"
		/only "Treat block returned by CODE as a single item"
		/eval "Reduce block returned by CODE (else includes it as is)"
		/drop "Discard regions that didn't match SPEC (else includes them unmodified)"
		/case "Values are matched using strict comparison"
		/same "Values are matched using sameness comparison"
		/self "Map series into itself (incompatible with ranges)"
		/local part
	][
		all [
			self
			scalar? series								;-- change/part below relies on this error
			ERROR "/self is only allowed when iterating over series or map"
		]

		;-- where to collect into: always a block, regardless of the series given
		;-- because we don't know what type the result should be and block can be converted into anything later
		buf: make [] system/words/case [				;-- try to guess the length
			integer? series [series]
			pair? series [series/x * series/y]
			'else [length? series]
		]
		if all [eval not only] [red-buf: copy []]		;-- buffer for reduce/into
		;@@ TODO: trap & rethrow errors (out of memory, I/O, etc), ensuring buffers are freed on exit

		;-- in map-each ii/step is never negative as it does not support backwards iteration
		add-skipped-items: [skip-bgn: skip-end]
		add-rest: []
		unless drop [
			add-skipped-items: [
				if skip-end > skip-bgn [				;-- can be <= in case of step=0 or user intervention - in this case don't add anything
					copy-to buf ii skip-bgn skip-end - skip-bgn
				]
				skip-bgn: skip-end
			]
			add-rest: [
				ii/offset: skip-bgn						;-- offset used by `more-items?`
				if more-items? ii [copy-to buf ii skip-bgn none]
			]
		]

		if ii: fill-info spec series code no case same [	;-- non-empty series/range?
			skip-bgn: ii/offset
			for-each-core ii [
				skip-end: ii/offset						;-- remember skipped region before ii/offset changes in iteration code
				set/any 'part do ii/code
				if all [eval block? :part] [			;-- /eval only affects block results by design (for more strictness)
					part: either only [					;-- has to be reduced here, in case it calls continue or break, or errors
						reduce      part				;-- /only has to allocate a new block every time
					][	reduce/into part clear red-buf	;-- else this can be optimized, but buf has to be cleared every time in case it gets partially reduced and then `continue` fires
					]
				]
			][
				do add-skipped-items					;-- by putting it here, we can group multiple `continue` calls into a single append
				either only [append/only buf :part][append buf :part]
				;-- `max` is used to never add the same region twice, in case user rolls back the position:
				skip-bgn: skip-end: max skip-end ii/offset
			]
			do add-rest									;-- after break or last continue, add the rest of the series

			;-- to avoid O(n^2) time complexity of in-place item changes (e.g. inserted item length <> removed),
			;-- original series is changed only once, after iteration is finished
			;-- this produces a single on-deep-change event on owned series
			;-- during iteration, intermediate changes will not be detected by user code
			if self [
				either map? series [
					extend clear series buf
				][
					change/part series buf tail series
				]
			]
		]												;-- otherwise, empty series: buf is already empty

		;@@ TODO: in R/S free the `red-buf` here (not possible in Red)
		either self [ 									;-- even if never iterated, a block or series is returned
			;@@ TODO: in R/S free the `buf` here (not possible in Red)
			series
		][
			buf											;-- no need to free it
		]
	]

	;@@ TODO: maps require a special fill function so keys don't appear as set-words, also to avoid a copy
	;@@ at RS level it's a hash so it'll be easier there
	;@@ so, map at least should be converted into a hash, not block
	set 'remove-each function [
		"Remove parts of SERIES that match SPEC and return a truthy value"
		'spec  [word! block!]                "Words & index to set, values/types to match"
		series [series! map! pair! integer!] "Series, map or range"
		code   [block!]                      "Should return the new item(s)"
		/drop "Discard regions that didn't match SPEC (else includes them unmodified)"
		/case "Values are matched using strict comparison"
		/same "Values are matched using sameness comparison"
		/local part
	][
		unless ii: fill-info spec series code no case same [	;-- early exit - series is empty
			return either any [series? series map? series] [series] [copy []]
		]

		;-- where to collect into: always a block, regardless of the series given
		;-- because we don't know what type the result should be and block can be converted into anything later
		buf: make [] system/words/case [				;-- try to guess the length
			integer? series [series]
			pair? series [series/x * series/y]
			'else [length? series]
		]
		;@@ TODO: trap & rethrow errors (out of memory, I/O, etc), ensuring `buf` is freed on exit

		skip-bgn: ii/offset
		for-each-core ii [
			skip-end: ii/offset							;-- remember skipped region before ii/offset changes in iteration code
			set/any 'drop-this? do ii/code
		][
			unless drop [copy-to buf ii skip-bgn skip-end - skip-bgn]
			unless :drop-this? [copy-to buf ii skip-end ii/step]
			skip-bgn: skip-end: ii/offset
		]
		unless drop [copy-to buf ii skip-bgn none]

		;-- to avoid O(n^2) time complexity of in-place item removal,
		;-- original series is changed only once, after iteration is finished
		;-- this produces a single on-deep-change event on owned series
		;-- during iteration, intermediate changes will not be detected by user code
		system/words/case [
			series? series [
				either any-string? series [
					change/part series rejoin buf tail series		;@@ just a workaround for #4913 crash
				][
					change/part series        buf tail series
				]
			]
			map? series [
				extend clear series buf
			]
			'ranges [
				return buf								;-- no need to free it
			]
		]
		;@@ TODO: in R/S free the buffer (not possible in Red)
		series
	]

]



;---------------------------- FOR-EACH -----------------------------

;; return value tests
#assert [error? try [for-each [] [1] [1]]]
#assert [unset? for-each x [] [1]]
#assert [unset? for-each x [1 2 3] [continue]]
#assert [unset? for-each x [1 2 3] [break]]
; #assert [123 =  for-each x [1 2 3] [break/return 123]]	;@@ broken in Red
#assert [3 =    r: for-each x [1 2 3] [x] 'r]

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
#assert [[1 2 3  ] = b: collect [for-each [/i x]   [x y z]     [keep i       ]] 'b]
#assert [[1 2 3  ] = b: collect [for-each [p: x]   [x y z]     [keep index? p]] 'b]
#assert [[1 2 3  ] = b: collect [for-each [/i x y] [a b c d e] [keep i       ]] 'b]
#assert [[1 3 5  ] = b: collect [for-each [p: x y] [a b c d e] [keep index? p]] 'b]
#assert [[1 3 4 5] = b: collect [for-each [p: x y] [a b c d e] [keep index? p p: back p]] 'b]	;-- 1st `back` fails
#assert [[1 4    ] = b: collect [for-each [p: x y] [a b c d e] [keep index? p p: next p]] 'b]
#assert [error? set/any 'e try  [for-each [p: x] [a b c] [p: 1]]  'e]
#assert [error? set/any 'e try  [for-each [p: x] [a b c] [p: ""]] 'e]
#assert [[1 2 3  ] = b: collect [for-each/reverse [/i x]   [x y z]     [keep i       ]] 'b]
#assert [[3 2 1  ] = b: collect [for-each/reverse [p: x]   [x y z]     [keep index? p]] 'b]
#assert [[1 2 3  ] = b: collect [for-each/reverse [/i x y] [a b c d e] [keep i       ]] 'b]
#assert [[5 3 1  ] = b: collect [for-each/reverse [p: x y] [a b c d e] [keep index? p]] 'b]
#assert [[3 2 1  ] = b: collect [for-each/reverse x 3                  [keep x ]] 'b]
#assert [[3 4 1 2] = b: collect [for-each/reverse [x y] 4              [keep reduce [x y]]] 'b]
#assert [[3 #[none] 1 2] = b: collect [for-each/reverse [x y] 3        [keep reduce [x y]]] 'b]
#assert [empty?      b: collect [for-each/reverse x            0       [keep x]] 'b]
#assert [empty?      b: collect [for-each/reverse x           -1       [keep x]] 'b]
#assert [[3 2    ] = b: collect [for-each/reverse x next      [1 2 3]  [keep x]] 'b]		;-- should stop at initial index
#assert [[2 3    ] = b: collect [for-each/reverse [x y]  next [1 2 3]  [keep reduce [x y]]] 'b]
#assert [[3      ] = b: collect [for-each/reverse x next next [1 2 3]  [keep x]] 'b]
#assert [empty?      b: collect [for-each/reverse x next next [1 2]    [keep x]] 'b]
#assert [[1 4    ] = b: collect [for-each         [/i x [word!]  ] [a 2 3 b 5] [keep i]] 'b]	;-- iteration number counts even if not matched
#assert [[2 5    ] = b: collect [for-each/reverse [/i x [word!]  ] [a 2 3 b 5] [keep i]] 'b]	;-- /reverse reorders iteration number
#assert [[2      ] = b: collect [for-each/reverse [/i x y [word!]] [a 2 3 b 5] [keep i]] 'b]	;-- iteration number accounts for step size
#assert [[1      ] = b: collect [for-each/reverse [/i x y [word!]] [a 2 3 b  ] [keep i]] 'b]

;; pipe
#assert [[1 2 3] = b: collect [for-each [x |]           [1 2 3] [keep x]] 'b]
#assert [[1 2 3] = b: collect [for-each [/i x |]        [x y z] [keep i]] 'b]
#assert [[x y z] = b: collect [for-each [/i x |]        [x y z] [keep x]] 'b]
#assert [[1 2 3] = b: collect [for-each [p: x |]        [x y z] [keep index? p]] 'b]
#assert [[x y z] = b: collect [for-each [p: x |]        [x y z] [keep x]] 'b]
#assert [[x y z] = b: collect [for-each [p: | x]        [x y z] [keep x p: next p]] 'b]			;-- zero step, manual advance
#assert [error? set/any 'r try [for-each [p: |] [x y z] [p: next p]] 'e]						;-- no mandatory words
#assert [[[x y] [y z]] = b: collect [for-each [x | y]   [x y z] [keep/only reduce [x y]]] 'b]
#assert [[[x y z]    ] = b: collect [for-each [x | y z] [x y z] [keep/only reduce [x y z]]] 'b]
#assert [empty?          b: collect [for-each [x | y z] [x y]   [keep/only reduce [x y z]]] 'b]		;-- too short to fit in
#assert [[1 2 3]       = b: collect [for-each [x y | z] [1 2 3]       [keep reduce [x y z]]] 'b]
#assert [[1 2 3]       = b: collect [for-each [x y | z] [1 2 3 4]     [keep reduce [x y z]]] 'b]
#assert [[1 2 3 3 4 5] = b: collect [for-each [x y | z] [1 2 3 4 5]   [keep reduce [x y z]]] 'b]
#assert [[1 2 3 3 4 5] = b: collect [for-each [x y | z] [1 2 3 4 5 6] [keep reduce [x y z]]] 'b]
#assert [[3 2 1] = b: collect [for-each/reverse [x |]           [1 2 3] [keep x]] 'b]
#assert [[1 2 3] = b: collect [for-each/reverse [/i x |]        [x y z] [keep i]] 'b]
#assert [[z y x] = b: collect [for-each/reverse [/i x |]        [x y z] [keep x]] 'b]
#assert [[3 2 1] = b: collect [for-each/reverse [p: x |]        [x y z] [keep index? p]] 'b]
#assert [[z y x] = b: collect [for-each/reverse [p: x |]        [x y z] [keep x]] 'b]
#assert [[[y z] [x y]] = b: collect [for-each/reverse [x | y]   [x y z] [keep/only reduce [x y]]] 'b]
#assert [[[x y z]    ] = b: collect [for-each/reverse [x | y z] [x y z] [keep/only reduce [x y z]]] 'b]
#assert [empty?          b: collect [for-each/reverse [x | y z] [x y]   [keep/only reduce [x y z]]] 'b]		;-- too short to fit in

;; any-string support
#assert [[#"a" #"b" #"c"] = b: collect [for-each c "abc" [keep c]] 'b]
#assert [[#"a" #"b" #"c"] = b: collect [for-each c <abc> [keep c]] 'b]
#assert [[#"a" #"b" #"c"] = b: collect [for-each c %abc  [keep c]] 'b]
#assert [[#"a" #"@" #"b"] = b: collect [for-each c a@b   [keep c]] 'b]
#assert [[#"a" #":" #"b"] = b: collect [for-each c a:b   [keep c]] 'b]

;; image support
#assert [im: make image! [2x2 #{111111 222222 333333 444444}]]
; #assert [[17.17.17.0 34.34.34.0 51.51.51.0 78.78.78.0] = b: collect [for-each c i [keep c]] 'b]		;@@ uncomment me when #4421 gets fixed
; #assert [[1x1 2x1 1x2 2x2] = b: collect [for-each [/i c] im  [keep i]] 'b]				;-- special index for images - pair
#assert [[1 2 3 4        ] = b: collect [for-each [p: c] im  [keep index? p]] 'b]

;; 1D/2D ranges support
#assert [not error? set/any 'e try [for-each [/i x] 2x2 []] 'e]
#assert [error? set/any 'e try [for-each [p: x] 2x2 []] 'e]								;-- series indexes with ranges forbidden
#assert [[1x1 2x1 1x2 2x2] = b: collect [for-each i     2x2 [keep i]] 'b]				;-- unfold size into pixel coordinates
#assert [[1x1 1x2        ] = b: collect [for-each [i j] 2x2 [keep i]] 'b]
#assert [[1 3 5 7 9      ] = b: collect [for-each [i j] 10  [keep i]] 'b]				;-- unfold length into integers

;; maps support
#assert [error? set/any 'e try [for-each [p: x] #(1 2 3 4) []] 'e]						;-- no series index for maps allowed
#assert [not error? set/any 'e try [for-each [/i x] #(1 2 3 4) []] 'e]
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
#assert [[#"3" 4       ] = b: collect [v: 4         for-each [x   (v)                  ] [1 2.0 #"3" 4 'e] [keep reduce [x v] ]] 'b]
#assert [[#"3" 4       ] = b: collect [v: #"3" w: 4 for-each [(v) (w)                  ] [1 2.0 #"3" 4 'e] [keep reduce [v w]]] 'b]
#assert [[1 2.0        ] = b: collect [             for-each [x [integer!]  y          ] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]] 'b]
#assert [[1 2.0 #"3" 4 ] = b: collect [             for-each [x             y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]] 'b]
#assert [[1 2.0 #"3" 4 ] = b: collect [             for-each [x [any-type!] y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]] 'b]
#assert [[#"3" 4       ] = b: collect [             for-each [x [char!]     y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [x y]  ]] 'b]
#assert [[#"3" 4       ] = b: collect [v: #"3"      for-each [(v)           y [number!]] [1 2.0 #"3" 4 'e] [keep reduce [v y] ]] 'b]
; #assert [[2 2 2 2      ] = b: collect [v: 2         for-each [(v)  ]                     [2 2.0 #"^B" 2]   [keep v] ] 'b]	;@@ FIXME: affected by #4327
; #assert [[2 2.0 #"^B" 2] = b: collect [v: 2         for-each [p: (v)]                    [2 2.0 #"^B" 2]   [keep p/1]] 'b]	;@@ FIXME: affected by #4327

;; /same & /case value filters
#assert [[2 2            ] =  b: collect [v: 2 for-each/case [p: (v)] [2 2.0 #"^B" 2] [keep p/1]] 'b]
#assert [[2 2            ] =  b: collect [v: 2 for-each/same [p: (v)] [2 2.0 #"^B" 2] [keep p/1]] 'b]
#assert [r: reduce [v: "v" w: "v" w uppercase copy v]]
#assert [["v" "v" "v" "V"] == b: collect [for-each           [p: (v)] r [keep p/1]] 'b]
#assert [["v" "v" "v"    ] == b: collect [for-each/case      [p: (v)] r [keep p/1]] 'b]
#assert [["v" "v"        ] == b: collect [for-each/same      [p: (w)] r [keep p/1]] 'b]
#assert [["v"            ] == b: collect [for-each/same      [p: (v)] r [keep p/1]] 'b]

;; `advance` support
; #assert [[[2 3] #[none]] = b: collect [for-each  x    [1 2 3    ] [        keep/only advance]] 'b]
; #assert [[[2 3 4] [4]  ] = b: collect [for-each  x    [1 2 3 4  ] [        keep/only advance]] 'b]
; #assert [[[3 4] #[none]] = b: collect [for-each  x    [1 2 3 4  ] [advance keep/only advance]] 'b]
; #assert [[[3 4]        ] = b: collect [for-each [x y] [1 2 3 4  ] [        keep/only advance]] 'b]
; #assert [[[5]          ] = b: collect [for-each [x y] [1 2 3 4 5] [advance keep/only advance]] 'b]
; #assert [[4 #[none]    ] = b: collect [for-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [set [x] advance keep x]] 'b]	;-- jumps to next match
; #assert [[2.0 6        ] = b: collect [for-each [x [number!] ] [1 2.0 #"3" 4 'e 6] [set [x] advance keep x]] 'b]
; #assert [[1 6          ] = b: collect [for-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [advance keep x]] 'b]			;-- does not affect the `x`

;; confirm that there's no leakage
#assert [(x: 1     for-each x     [2 3 4] [x: x * x]  x = 1) 'x]
#assert [(x: y: 1  for-each [x y] [2 3 4] [x: y: 0]   all [x = 1 y = 1]) 'x]





;---------------------------- MAP-EACH -----------------------------

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
#assert [[1 2 3    ] = b: map-each      [/i x]         [x y z]     [i       ] 'b]
#assert [[1 2 3    ] = b: map-each      [p: x]         [x y z]     [index? p] 'b]
#assert [[1 2 3    ] = b: map-each      [/i x y]       [a b c d e] [i       ] 'b]
#assert [[1 3 5    ] = b: map-each      [p: x y]       [a b c d e] [index? p] 'b]
#assert [[1 4      ] = b: map-each/drop [/i x [word!]] [a 2 3 b 5] [i       ] 'b]	;-- iteration number counts even if not matched
#assert [[1 2 3 4 5] = b: map-each      [/i x [word!]] [a 2 3 b 5] [i       ] 'b]
#assert [[1        ] = b: map-each/drop [/i x [word!] y] [a 2 3 b 5] [i       ] 'b]
#assert [[2        ] = b: map-each/drop [/i x y [word!]] [a 2 3 b 5] [i       ] 'b]	;-- iteration number accounts for step size

;; image support
#assert [im: make image! [2x2 #{111111 222222 333333 444444}]]
; #assert [[17.17.17.0 34.34.34.0 51.51.51.0 78.78.78.0] = b: map-each c i [c] 'b]		;@@ uncomment me when #4421 gets fixed
; #assert [[1x1 2x1 1x2 2x2] = b: map-each [/i c] im  [i] 'b]				;-- special index for images - pair
#assert [[1 2 3 4        ] = b: map-each [p: c] im  [index? p] 'b]

;; 1D/2D ranges support
; #assert [error? e: try [map-each [/i x] 2x2 []] 'e]						;-- indexes with ranges forbidden
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
; #assert [error? e: try [map-each [/i x] #(1 2 3 4) []] 'e]
#assert [[1 2 3 4        ] = b: map-each [k v]       #(1 2 3 4) [reduce [k v]] 'b]		;-- map iteration is very relaxed
#assert [[1 2 3 4        ] = b: map-each x           #(1 2 3 4) [x]        'b]
#assert [[1 2 3 4 #[none]] = b: map-each [a b c d e] #(1 2 3 4) [reduce [a b c d e]] 'b]

;; vectors support
#assert [v: make vector! [1 2 3 4 5]]
#assert [[1 2 3 4 5               ] = b: map-each       x    v [x]            'b]
#assert [[[1 2] [3 4] [5 #[none]] ] = b: map-each/only [x y] v [reduce [x y]] 'b]
#assert [[1 2 6 4 5               ] = b: map-each      [(3)] v [6] 'b]			;-- vectors get appended as /only by default - need to ensure it's not the case
#assert [(make vector! [1 2 6 4 5]) = b: map-each/self [(3)] copy v [6] 'b]

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
#assert [[(1) (2) (3) (4)]   = b: map-each/only      x [1 2 3 4] [to paren! x] 'b]
#assert [[(1) (2) (3) (4)]   = b: map-each/eval      x [1 2 3 4] [[to paren! x]] 'b]
#assert [[1 [x y] 2 [x y]]   = b: map-each/eval      x [1 2    ] [[ x map-each x [x y] [x] ]] 'b]
#assert [[1 [x y] 2 [x y]]   = b: map-each           x [1 2    ] [reduce [ x map-each      x [x y]  [x] ]] 'b]
#assert [[1 [x y] 2 [x y]]   = b: map-each           x [1 2    ] [reduce [ x map-each/eval x [x y] [[x]] ]] 'b]

;; filtering (pattern matching)
#assert [[1 2 3 4 5 6]             = b: map-each            x             [1 "2" "3" 4 5 "6"] [to integer! x] 'b]
#assert [["1" "2" "3" "4" "5" "6"] = b: map-each           [x [integer!]] [1 "2" "3" 4 5 "6"] [form x]        'b]
#assert [[1 2 3 4 5 6]             = b: map-each           [x [string!]]  [1 "2" "3" 4 5 "6"] [to integer! x] 'b]
#assert [[1 [2] [3] 4 5 [6]]       = b: map-each/only/eval [x [string!]]  [1 "2" "3" 4 5 "6"] [[to integer! x]] 'b]
#assert [[[1] "2" "3" [4] [5] "6"] = b: map-each/only/eval [x [integer!]] [1 "2" "3" 4 5 "6"] [[x]] 'b]
#assert [[2 4 6]                   = b: map-each/drop      [x [integer!]] make vector! [1 2 3] [x * 2] 'b]	;-- vectors are no problem for type filter
#assert [[]                        = b: map-each/drop      [x [float!]]   make vector! [1 2 3] [x * 2] 'b]
#assert [[1 4 3]                   = b: map-each           [(2)]          make vector! [1 2 3] [4] 'b]

;; /same & /case value filters
#assert [[2 2          ] = (v: 2 b: map-each/case/drop [p: (v)] [2 2.0 #"^B" 2] [p/1]) 'b]
#assert [[2 2          ] = (v: 2 b: map-each/same/drop [p: (v)] [2 2.0 #"^B" 2] [p/1]) 'b]
#assert [[2 2.0 #"^B" 2] = (v: 2 b: map-each/case      [p: (v)] [2 2.0 #"^B" 2] [p/1]) 'b]
#assert [[2 2.0 #"^B" 2] = (v: 2 b: map-each/same      [p: (v)] [2 2.0 #"^B" 2] [p/1]) 'b]
#assert [r: reduce [v: "v" w: "v" w uppercase copy v]]
#assert [["v" "v" "v" "V"] == b: map-each           [p: (v)] r [p/1] 'b]
#assert [["v" "v" "v"    ] == b: map-each/case/drop [p: (v)] r [p/1] 'b]
#assert [["v" "v"        ] == b: map-each/same/drop [p: (w)] r [p/1] 'b]
#assert [["v"            ] == b: map-each/same/drop [p: (v)] r [p/1] 'b]
#assert [["V" "V" "V" "V"] == b: map-each/case      [p: (v)] r [uppercase copy p/1] 'b]
#assert [["v" "V" "V" "V"] == b: map-each/same      [p: (w)] r [uppercase copy p/1] 'b]
#assert [["V" "v" "v" "V"] == b: map-each/same      [p: (v)] r [uppercase copy p/1] 'b]

;; /self
#assert [error? try     [b: map-each/self x 4             [x]]                 'b]		;-- incompatible with ranges & maps
#assert [error? try     [b: map-each/self x 2x2           [x]]                 'b]
#assert [[1 2 3 4]     = b: map-each/self x [11 22 33 44] [x / 11]             'b]
#assert ["1234"        = s: map-each/self x "abcd"        [x - #"a" + #"1"]    's]		;-- string in, string out
#assert ["a1b2c3d4"    = s: map-each/self/eval x "abcd"  [[x x - #"a" + #"1"]] 's]
#assert ["c1d2"        = s: map-each/self/eval [/i x] skip "abcd" 2 [[x i]] 's]			;-- retains original index
#assert ["abc1d2" = s: head map-each/self/eval [/i x] skip "abcd" 2 [[x i]] 's]			;-- does not affect series before it's index
#assert ["abef"        =    map-each/self x s: "abCDef" [either x < #"a" [][x]] 's]		;-- unset should silently be formed into empty string
#assert [#(1 2 3 4   ) = m: map-each/self [k v]  #(1 2 3 4) [reduce [k v]] 'm]			;-- preserves map type
#assert [#(2 4       ) = m: map-each/self [k v]  #(1 2 3 4) [v]            'm]

; ;; `advance` support (NOTE: without /drop - advance makes little sense and hard to think about)
; #assert [[[2 3] #[none]] = b: map-each/drop/only  x    [1 2 3    ] [        advance] 'b]
; #assert [[[2 3 4] [4]  ] = b: map-each/drop/only  x    [1 2 3 4  ] [        advance] 'b]
; #assert [[[3 4] #[none]] = b: map-each/drop/only  x    [1 2 3 4  ] [advance advance] 'b]
; #assert [[[3 4]        ] = b: map-each/drop/only [x y] [1 2 3 4  ] [        advance] 'b]
; #assert [[[5]          ] = b: map-each/drop/only [x y] [1 2 3 4 5] [advance advance] 'b]
; #assert [[4 #[none]    ] = b: map-each/drop [x [integer!]] [1 2.0 #"3" 4 'e 6] [set [x] advance x] 'b]	;-- jumps to next match
; #assert [[2.0 6        ] = b: map-each/drop [x [number!] ] [1 2.0 #"3" 4 'e 6] [set [x] advance x] 'b]
; #assert [[1 6          ] = b: map-each/drop [x [integer!]] [1 2.0 #"3" 4 'e 6] [advance x] 'b]			;-- does not affect the `x`
; #assert [[4 'e #[none] ] = b: map-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [set [x] advance x] 'b]		;-- without /drop includes skipped items
; #assert [[2.0 #"3" 6   ] = b: map-each [x [number!] ] [1 2.0 #"3" 4 'e 6] [set [x] advance x] 'b]
; #assert [[1 'e 6       ] = b: map-each [x [integer!]] [1 2.0 #"3" 4 'e 6] [advance x] 'b]

;; pipe
#assert [[1 2 3          ] = b: map-each      [x |]     [1 2 3]   [x] 'b]
#assert [[1 2 3          ] = b: map-each      [/i x |]  [x y z]   [i] 'b]
#assert [[x y z          ] = b: map-each      [/i x |]  [x y z]   [x] 'b]
#assert [[1 2 3          ] = b: map-each      [p: x |]  [x y z]   [index? p] 'b]
#assert [[x y z          ] = b: map-each      [p: x |]  [x y z]   [x] 'b]
#assert [[x y z          ] = b: map-each      [p: | x]  [x y z]   [p: next p x] 'b]			;-- zero step, manual advance
#assert [[x y z          ] = b: map-each/drop [p: | x]  [x y z]   [p: next p x] 'b]
#assert [error? set/any 'r try [map-each [p: |] [x y z] [p: next p]] 'e]					;-- no mandatory words
#assert [[[x y]  [y z] z ] = b: map-each/only/eval      [x | y]   [x y z] [[x y]] 'b]
#assert [[[x y]  [y z]   ] = b: map-each/only/eval/drop [x | y]   [x y z] [[x y]] 'b]
#assert [[[x y z] y z    ] = b: map-each/only/eval      [x | y z] [x y z] [[x y z]] 'b]
#assert [[[x y z]        ] = b: map-each/only/eval/drop [x | y z] [x y z] [[x y z]] 'b]
#assert [[x y            ] = b: map-each/only/eval      [x | y z] [x y]   [[x y z]] 'b]		;-- too short to fit in
#assert [empty?              b: map-each/only/eval/drop [x | y z] [x y]   [[x y z]] 'b]		;-- too short to fit in
#assert [[1 2 3 3        ] = b: map-each/eval           [x y | z] [1 2 3]       [[x y z]] 'b]
#assert [[1 2 3          ] = b: map-each/eval/drop      [x y | z] [1 2 3]       [[x y z]] 'b]
#assert [[1 2 3 3 4      ] = b: map-each/eval           [x y | z] [1 2 3 4]     [[x y z]] 'b]
#assert [[1 2 3          ] = b: map-each/eval/drop      [x y | z] [1 2 3 4]     [[x y z]] 'b]
#assert [[1 2 3 3 4 5 5  ] = b: map-each/eval           [x y | z] [1 2 3 4 5]   [[x y z]] 'b]
#assert [[1 2 3 3 4 5    ] = b: map-each/eval/drop      [x y | z] [1 2 3 4 5]   [[x y z]] 'b]
#assert [[1 2 3 3 4 5 5 6] = b: map-each/eval           [x y | z] [1 2 3 4 5 6] [[x y z]] 'b]
#assert [[1 2 3 3 4 5    ] = b: map-each/eval/drop      [x y | z] [1 2 3 4 5 6] [[x y z]] 'b]

;; confirm that there's no leakage
#assert [(x: 1     map-each x     [2 3 4]   [x: x * x]  x = 1) 'x]
#assert [(x: y: 1  map-each [x y] [2 3 4 5] [x: y * x]  all [x = 1 y = 1]) 'x]





;---------------------------- REMOVE-EACH -----------------------------
#assert [#(a b c d) = m: remove-each x #(a 1 b 2 c 3 d 4) [integer? x] 'm]
#assert [#(1 2 3 4) = m: remove-each x #(a 1 b 2 c 3 d 4) [word? x] 'm]
#assert [[2x1 3x1 1x2 3x2 1x3 2x3] = remove-each p 3x3 [p/x = p/y]]
#assert [[1 2 3]    = b: remove-each x  3 [no]     'b]
#assert [[2]        = b: remove-each x  3 [odd? x] 'b]
#assert [[1]        = b: remove-each x  1 [no]     'b]
#assert [[]         = b: remove-each x  0 [no]     'b]
#assert [[]         = b: remove-each x -1 [no]     'b]
#assert ["ac"       = s: remove-each x "abc" [#"b" = x] 's]
#assert [["" ""]    = b: remove-each x ["abc" "def"] [remove-each x x [yes] no] 'b]
#assert [["ac" "df"]= b: remove-each x ["abc" "def"] [remove-each x x [find "be" x] no] 'b]
#assert [[2 3 4   ] = b: remove-each [/i x [word!]] [a 2 3 b 4] [yes] 'b]
#assert ["cf"       = s: remove-each x skip "abcdef" 2 [find "de" x] 's]	;-- retains original index
#assert ["abcf"= s: head remove-each x skip "abcdef" 2 [find "de" x] 's]



