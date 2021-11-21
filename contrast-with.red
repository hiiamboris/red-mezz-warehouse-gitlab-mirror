Red [
	title:   "CONTRAST-WITH mezzanine"
	purpose: "Pick a color that would contrast with the given one"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		It inverts the color then pushes it towards the closest limit (0 or 255)
		Not totally, but leaving some visible remaining hue.
	}
]

context [
	invert: func [c] [white - c]
	push:   func [c] [c - (min c/1 min c/2 c/3) / 1.4]		;-- 1.3 is the magic number found best from the test below

	set 'contrast-with function [
		"Pick a color that would contrast with the given one"
		c [tuple!]
	][
		mean: c/1 + c/2 + c/3 / 3
		either mean <= 128 [invert push c][push invert c]
	]
]

comment {	;; Test
	factor: 1.0
	invert: func [c] [white - c]
	push:   func [c] [c - (min c/1 min c/2 c/3) / factor]
	contrast-with: function [c][
		mean: c/1 + c/2 + c/3 / 3
		either mean <= 128 [invert push c][push invert c]
	]
	colors: reduce extract load help-string tuple! 2
	forall colors [if attempt [colors/1/4] [remove colors]]
	view collect [
		keep [sl: slider [factor: 2 * face/data + 1.0] text react [face/data: 1.0 * factor sl/data] return]
		n: round/ceiling/to sqrt length? colors 1
		repeat i n [
			repeat j n [
				if c: pick colors i - 1 * n + j [
					keep reduce [
						'base 50x50 "TEXT^/TEXT" c white
						'react [sl/data face/font/color: contrast-with face/color]
					]
				]
			]
			keep 'return
		]
	]
}
