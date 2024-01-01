Red [
	title:   "CONTRAST-WITH function"
	purpose: "Pick a color that would contrast with the given one"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		This is useful e.g. if you have a background color and want to pick a text color that will be visible on it.
		
		It inverts the color then pushes it towards the closest limit (0 or 255).
		Not totally, but leaving some visible remaining hue (20% of it).
	
		Performance with 20% hue on:
		- predefined Red colors: https://i.gyazo.com/00ed678b3ebcb517ba9f81e0f4003a27.png
		- random color set: https://i.gyazo.com/f780d62e1fe3d87c745b9ebbe4a10bd9.png
	}
]


#include %color-models.red

contrast-with: function [
	"Pick a color that would contrast with the given one"
	color [tuple!]
	/both other [tuple!] "Should contrast with both given colors"
][
	either all [both other <> color] [
		;@@ this should be done in Lab space, otherwise prone to bad choices, esp on blue
		hsl1: RGB2HSL color
		hsl2: RGB2HSL other
		h: hsl1/1 + hsl2/1 / 2									;-- pick hue contrast to the average hue of both
		if (absolute h - hsl1/1) < 90 [h: h + 180 % 360]		;-- pick the longer arc center
		l+: max hsl1/3 hsl2/3
		l-: min hsl1/3 hsl2/3
		l: l+ + l- / 2
		d: l+ - l- / 2											;-- distance from l to both colors lightness
		foreach l' [0.8 0.2] [									;-- pick best of 3 variants of lightness: l1+l2/2, 0.2 and 0.8
			d': min absolute l' - l- absolute l' - l+			;-- distance from l' to closest color lightness
			if d' > d [d: d' l: l']
		]
		HSL2RGB/tuple as-point3D h 1 l							;-- always saturated
	][
		bw: either 0.5 > brightness? color [white][black]		;-- pick black or write: what's more contrast 
		white - color / 5 + (bw * 0.8)							;-- 20% of inverted color + 80% of B/W
	]
]


comment {
	;; Dual color test
	colors: map-each/drop [n t [tuple!]] body-of system/words [to word! n]
	view/tight [
		b1: base "TEXT" bold right b2: base "TEXT" bold left rate 1 on-time [
			b1/color: get probe random/only colors
			b2/color: get probe random/only colors
			b1/font/color: b2/font/color: contrast-with/both b1/color b2/color
		]
	]

	;; Single color test (up to 30% factor works best, but closer to 0% loses hue)
	factor: 5.0
	brightness: func [c] [(c/1 / 240 ** 2) + (c/2 / 200 ** 2) ** 0.5]	;-- doesn't count blue for speed
	contrast-with: function [c][
		bw: either 1 > brightness c [white][black]
		; white - c / 5 + (bw * 0.8)
		(white - c / factor) + (bw * (1.0 - (1.0 / factor)))
	]
	colors: reduce extract load help-string tuple! 2	;-- predefined color selection
	insert colors 75.142.254
	forall colors [if attempt [colors/1/4] [remove colors]]
	; colors: collect [repeat i 100 [keep random white]]	;-- random selection
	view collect [
		keep [sl: slider data 20% focus [factor: 1 / (max 1% face/data)] text react [face/data: 100% / factor sl/data] return]
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

