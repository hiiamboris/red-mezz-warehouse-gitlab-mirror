Red [
	title:   "COUNT mezzanine"
	purpose: "Count occurences of an item in the series"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		See https://github.com/greggirwin/red-hof/tree/master/code-analysis#count for design notes
		As it is FIND-based, it supports types/typesets and fast hash lookups.
	}
]


#include %assert.red
#include %new-apply.red


count: function [
	"Count occurrences of value in series (using `=` by default)"
	series [series!]									;-- docstrings & arg names mirror FIND action
	value  [any-type!]
	/part "Limit the counting range"
		length [number! series!]
	/only "Treat series and typeset value arguments as single values"
	/case "Perform a case-sensitive search"
	/same {Use "same?" as comparator}
	/skip "Treat the series as fixed size records"
		size [integer!]
	/reverse "Count from current index to the head"
	; /any & /with - TBD in FIND
	; return: [integer!]
][
	n: 0 
	tail: not reverse
	while [series: apply find 'local] [n: n + 1]
	n
]

#assert [
	0 = count              [          ] 1
	3 = count              [1 1 1     ] 1 
	2 = count              [1 2 1     ] 1 
	3 = count              [1 2 3     ] integer! 
	2 = count/skip         [1 2 3 4   ] integer! 2 
	0 = count/only         [1 2 3     ] integer! 
	1 = count/only  reduce [1 integer!] integer! 
	2 = count         next [1 2 3     ] integer! 
	1 = count/reverse next [1 2 3     ] integer! 
	3 = count/reverse tail [1 2 3     ] integer! 
	2 = count              [1 [1] 1   ] [1]
	1 = count/only         [1 [1] 1   ] [1]
]

