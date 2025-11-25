Red [
	title:    "TIMESTAMP mezzanine"
	purpose:  "Ready-to-use and simple timestamp formatter for naming files"
	author:   @hiiamboris
	license:  BSD-3
	provides: [timestamp format-date]
	depends:  [format-number stepwise-macro]
]


#include %stepwise-macro.red
#include %format-number.red
#include %composite.red

;@@ use lazy evaluation to reduce the number of allocations and computations?
format-date: function compose [
	"Format date/time using a custom template"
	datetime [date!]
	template [string!] {E.g. "(month)-(day)/(hour):(minute)"}
	/local
		(exclude system/catalog/accessors/date! [date])			;-- common accessors aren't enough, so:
		millis micros											;-- 3-milliseconds and 6-microseconds accessors
		integer													;-- seconds since unix epoch
] compose/only [
	words: (copy system/catalog/accessors/date!)
	foreach word words [set word datetime/:word]
	;; provide custom accessors:
	micros:  to integer! second * 1e6 % 1e6						;-- extract micros before modifying seconds
	millis:  to integer! micros / 1000
	second:  to integer! second									;-- default /second is a float - we need an integer
	integer: to integer! datetime - multiply 0:0.001 millis		;-- has to be done without millis, otherwise is rounded
	;; ensure proper padding:
	foreach word [month day hour minute second] [
		set word pad/left/with get word 2 #"0"
	]
	millis: pad/left/with millis 3 #"0"
	micros: pad/left/with micros 6 #"0"
	year:   format-number year 4 0
	composite['local] template
]

assert [
	"2025/11/25 06:03:14"     = format-date 25-Nov-2025/6:3:14.6    "(year)/(month)/(day) (hour):(minute):(second)"
	"2025/11/25 06:03:14.999" = format-date 25-Nov-2025/6:3:14.9999 "(year)/(month)/(day) (hour):(minute):(second).(millis)"
	"06:03:14.999800"         = format-date 25-Nov-2025/6:3:14.9998 "(hour):(minute):(second).(micros)"
	"-0005/11/25 06:03:14"    = format-date 25-Nov--5/6:3:14        "(year)/(month)/(day) (hour):(minute):(second)"
	"1764050594.567"          = format-date 25-Nov-2025/6:3:14.5678 "(integer).(millis)"
]

;@@ should it have a /utc refinement? if so, how will it work with /from?
timestamp: function [
	"Get date & time in a sort-friendly YYYYMMDD-hhmmss-mmm format"
	/from dt [date!] "Use provided date+time instead of the current"
][
	dt: any [dt now/precise]
	r: make string! 32									;-- 19 used chars + up to 13 trailing junk from dt/second
	foreach field [year month day hour minute second] [
		append r format-number dt/:field 2 -3
	]
	#stepwise [
		skip r 8  insert . "-"
		skip . 6  change . "-"
		skip . 3  clear .
	]
	r
]
