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
	brightness: func [c] [								;-- returns 1 for a value halfway between B and W
		(c/1 / 240 ** 2) + (c/2 / 200 ** 2) ** 0.5		;-- doesn't count blue for better speed
	]

	set 'contrast-with function [
		"Pick a color that would contrast with the given one"
		c [tuple!]
	][
		bw: either 1 > brightness c [white][black]		;-- pick black or write: what's more contrast 
		white - c / 5 + (bw * 0.8)						;-- 20% of inverted color + 80% of B/W
	]
]

; comment {	;; Test
	factor: 1.0
	brightness: func [c] [(c/1 / 240 ** 2) + (c/2 / 200 ** 2) ** 0.5]	;-- doesn't count blue for speed
	contrast-with: function [c][
		bw: either 1 > brightness c [white][black]
		; white - c / 5 + (bw * 0.8)
		(white - c / factor) + (bw * (1.0 - (1.0 / factor)))
	]
	colors: reduce extract load help-string tuple! 2
	insert colors 75.142.254
	forall colors [if attempt [colors/1/4] [remove colors]]
	view collect [
		keep [sl: slider focus [factor: 100 * face/data + 1.0] text react [face/data: 1.0 * factor sl/data] return]
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
; }
