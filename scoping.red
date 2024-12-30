Red [
	title:    "Scoping support"
	purpose:  "Basis for scope-based resource management"
	author:   @hiiamboris
	license:  BSD-3
	provides: scoping
	notes: {
		See https://en.wikipedia.org/wiki/Resource_acquisition_is_initialization for background

		just a simple macro for now
		exception-safe macro TBD
		because it incurs usage of `try/all` which has it's issues
		notably disabling of non local control flow
		which we want to pass through but still release resources
	}
]


;; this is useful when errors/throws are not normally expected in the code and end of block is known to be reached
;; one strategy is to insert `also` before last token of the block, but this does not reverse the finalization order
;; another is to use `also do rest do finalizer` but `do` will prevent compilation
;; previously used `also if true [rest] (finalizer)` to avoid stack issues with parens
;; using `also (rest) (finalizer)` now that stack issues have been fixed
#macro [#leaving block!] func [[manual] s e /local rest cleanup] [
	either tail? e [									;-- unlikely case, but have to secure against it
		change s 'do
	][
		cleanup: to paren! s/2
		rest:    to paren! e
		clear change/only change/only change s 'also rest cleanup
	]
	new-line s on
]

;@@ need a better name, maybe #leaving/safe, but issues don't unstick refinements
#macro [#leaving-safe block!] func [[manual] s e /local rest cleanup] [
	either tail? e [									;-- unlikely case, but have to secure against it
		change s 'do
	][
		cleanup: s/2
		rest: copy e
		clear change change/only change/only change/only s 'following/method rest cleanup quote 'trap
	]
	new-line s on
]


; probe [1 + 2 #leaving [3]]
; probe do probe [1 + 2 #leaving [3 * 4] #leaving ['x] 5 + 6]
