Red [
	title:    "JOIN function"
	purpose:  "Join a list as a string"
	author:   @hiiamboris
	license:  BSD-3
	provides: join
	depends:  interleave
]

; #include %delimit.red

join: function [
	"Delimit a list and join as a string"
	list  [any-list!]
	delim [any-type!]
][
	to string! delimit list :delim
]

