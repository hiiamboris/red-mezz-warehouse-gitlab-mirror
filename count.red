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


#include %new-apply.red

count: function [
	"Count occurrences of VALUE in SERIES (using `=` by default)"
	series [series!]
	value  [any-type!]
	/case "Use strict comparison (`==`)"
	/same "Use sameness comparison (`=?`)"
	/only "Treat series and typesets as single values"
	/head "Count the number of subsequent values at series' head"
	/tail "Count the number of subsequent values at series' tail"	;@@ doesn't work for strings! #3339
][
    match: head or tail
    unless tail: not reverse: tail [series: system/words/tail series]
	n: 0 while [series: find/:case/:same/:only/:match/:tail/:reverse series :value] [n: n + 1]
    n
]

{
	Toomas's version without apply: (and /case /same)

count: func [series item /only /head /tail /local cnt pos with-only without][
    cnt: 0
    set [       with-only                             without                  ] case [
        tail [[[find/reverse/match/only series item] [find/reverse/match series item]]]
        head [[[find/match/tail/only    series item] [find/match/tail    series item]]]
        true [[[find/tail/only          series item] [find/tail          series item]]]
    ]
    if tail [series: system/words/tail series]
    while [all [pos: either only with-only without series: pos]] [cnt: cnt + 1]
    cnt
]	
}

; probe count/head "aaabbc" "a"
; probe count/head "aaabbc" "aa"
; probe count/head "aaabbc" "aaa"
; probe count/tail [1 2 2 3 3 3] 3

comment {
	;; limited and ugly but fast version
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