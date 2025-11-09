Red [
	title:    "Value constructors"
	purpose:  "Convenient selection of words into a map or object"
	author:   @hiiamboris
	license:  BSD-3
	provides: [as-map as-object]
	notes: {
		This is often useful when passing a complex result outside of the function.
		When all data is prepared, then instead of:
			make map! compose/only [
				x: (:x)
				y: (:y)
				z: (:z)
			]
		we can write just: `as-map [x y z]`
	}
]


as-object: function [
	"Create an object with given WORDS and assign values from these words"
	words   [block!] "Block of set-words, each must have a value"	;@@ I'd prefer words, but this is currently a performance matter
	return: [object!]
][
	#assert [parse words [some set-word!]]
	also obj: construct words
	foreach w words [set-quiet in obj 'w get w]
]

as-map: function [
	"Create a map with given WORDS and assign values from these words"
	words   [block!] "Block of words or set-words, each must have a value"
	return: [map!]
][
	#assert [parse words [some [set-word! | word!]]]
	also map: make map! length? words
	foreach w words [map/:w: get w]
]
	
