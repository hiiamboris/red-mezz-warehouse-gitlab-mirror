Red [
	title:   "COUNT mezzanine"
	purpose: "Count occurences of an item in the series"
	author:  @hiiamboris
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
	cmp: pick pick [[find/tail/same find/tail/same] [find/tail/case find/tail]] same case
	r: 0
	while compose [s: (cmp) s :x] [r: r + 1]
	r
]

comment {
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
}