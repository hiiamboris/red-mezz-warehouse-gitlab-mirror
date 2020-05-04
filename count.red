Red [
	title:   "COUNT mezzanine"
	purpose: "Count occurences of an item in the series"
	author:  [@hiiamboris @toomasv]
	license: 'BSD-3
	notes: {
		It is FIND-based (for performance)
		Due to bugs in FIND, the result is different from using operators =/==/=?:
			>> count [1 1.0 1 1.0000000000000001] 1
			== 2          ;) find-version
			== 4          ;) operator-version
		OTOH, allows to count types/typesets!
	}
]


count: function [
	"Count occurrences of X in S (using `=` by default)"
	s [series!]
	x [any-type!]
	/case "Use strict comparison (`==`)"
	/same "Use sameness comparison (`=?`)"
][
    n: 0 
    system/words/case [
        same [while [s: find/tail/same s :x][n: n + 1]]
        case [while [s: find/tail/case s :x][n: n + 1]]
        true [while [s: find/tail      s :x][n: n + 1]]
    ] 
    n
]


comment {
	;; `compose` involves too much memory pressure
	count: function [
		"Count occurrences of X in S (using `=` by default)"
		s [series!]
		x [any-type!]
		/case "Use strict comparison (`==`)"
		/same "Use sameness comparison (`=?`)"
	][
		cmp: pick pick [[find/tail/same find/tail/same] [find/tail/case find/tail]] same case
		r: 0
		while compose [s: (cmp) s :x] [r: r + 1]
		r
	]

	;; slow version
	count: function [
		"Count occurrences of X in S (using `=` by default)"
		s [series!]
		x [any-type!]
		/case "Use strict comparison (`==`)"
		/same "Use sameness comparison (`=?`)"
	][
		cmp: pick pick [[=? =?] [== =]] same case
		r: 0
		foreach y s compose [if :x (cmp) :y [r: r + 1]]
		r
	]

	;; parse-version - not better; can't support `same?` without extra checks
	count: function [
		"Count occurrences of X in S (using `=` by default)"
		s [series!]
		x [any-type!]
		/case "Use strict comparison (`==`)"
		/same "Use sameness comparison (`=?`)"
	][
		r: 0
		parse s [any thru [x (r: r + 1)]]
		r
	]

	;; test code
	#include %clock-each.red
	recycle/off
	clock-each/times [
		count  [1 2 a b 1.5 4% "c" #g [2 3] %f] 1
		count2 [1 2 a b 1.5 4% "c" #g [2 3] %f] 1
		count  [1 2 a b 1.5 4% "c" #g [2 3] %f] "c"
		count2 [1 2 a b 1.5 4% "c" #g [2 3] %f] "c"
		count  [1 2 a b 1.5 4% "c" #g [2 3] %f] number!
		count2 [1 2 a b 1.5 4% "c" #g [2 3] %f] number!
		count  [1 2 a b 1.5 4% "c" #g [2 3] %f] integer!
		count2 [1 2 a b 1.5 4% "c" #g [2 3] %f] integer!
	] 50000

}