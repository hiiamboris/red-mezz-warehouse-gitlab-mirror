Red [
	title:   "HSL/RGB conversions"
	purpose: "Reliable statistically neutral conversion between common color models"
	author:  @hiiamboris
	license: 'BSD-3
	TODO:    {HSV, HSI does anyone use these?}
]

; #include %assert.red
; #include %hide-macro.red

;@@ consider moving these out into another module
;; these are designed to be statistically neutral:
;; 0/255    1/255    2/255     ..       253/255      254/255      255/255 <- [0,1]
;; ^        ^        ^         ..             ^            ^            ^ <- how byte range maps into [0,1]
;; 0        1        2         ..           253          254          255 <- byte range
;; ^^^^^^^^ ^^^^^^^^ ^^^^^^^^  ..  ^^^^^^^^^^^^ ^^^^^^^^^^^^ ^^^^^^^^^^^^ <- how [0,1] maps into byte range
;; 0..1/256 1..2/256 2..3/256  ..  253..254/256 254..255/256 255..256/256 <- [0,1]
;; so each 1/256th inteval during roundtrip conversion collapses into a point in the same interval
;; this point's offset within the inteval is (N-1)/(255*256) where N is the interval number 1-256
;; but most importantly 0 maps to 0 and 1 to 1, to have pure black/white colors during color conversion
to-byte: function [
	"Convert VALUE from [0,1] range into a byte [0..255]"
	value [number!]
][
	to integer! value * 255.999'999'999'999				;-- 256 would round contested values up
]
from-byte: function [
	"Convert byte value [0..255] into [0,1] range"
	value [integer!]
][
	value / 255
]

#hide [
	#assert [
		do [
			#include %map-each.red
			; sample: map-each i 10000 [i / 10000]				;-- slow test
			sample: map-each i 100 [i / 100]
			sum1:  sum sample
			loop  1 [map-each/self x sample [from-byte to-byte x]]
			sum2:  sum sample
			loop 10 [map-each/self x sample [from-byte to-byte x]]
			sum3:  sum sample
			error: (absolute sum1 - sum2)
			; ?? [sum1 sum2 sum3 error]
		]
		error <= 0.05									;-- initial error should be small on uniform sample
		sum2 == sum3									;-- no additional error should be introduced by subsequent conversions
	]
]

;@@ consider moving these out into another module
tuple->point: function [
	"Convert tuple into a point3D"
	tuple [tuple!]
][
	as-point3D
		from-byte tuple/1
		from-byte tuple/2
		from-byte tuple/3
]
point->tuple: function [
	"Convert point3D into a tuple"
	point [point3D!]
][
	as-color											;@@ this routine may overflow if > 255 - need bounds checking
		to-byte point/1
		to-byte point/2
		to-byte point/3
]

;; https://en.wikipedia.org/wiki/HSL_and_HSV#Color_conversion_formulae
RGB->HSL: RGB2HSL: function [
	"Convert colors from RGB(1,1,1) into HSL(360,1,1) color model"
	RGB [point3D! tuple!] "0-1 each if point"
	/tuple "Return as a 3-tuple"
][
	if tuple? RGB [RGB: tuple->point RGB]
	R: RGB/1  G: RGB/2  B: RGB/3
	X+: max max R G B									;-- max of channels = value
	X-: min min R G B									;-- min of channels
	C:  X+ - X-											;-- chroma
	L:  X+ + X- / 2										;-- lightness
	S:  either C = 0 [0.0][C / 2 / min L 1 - L]			;-- saturation
	H:  60 * case [										;-- hue
		C  =  0 [0.0]
		X+ == R [G - B / C // 6]
		X+ == G [B - R / C +  2]
		X+ == B [r - G / C +  4]
	]
	HSL: as-point3D H S L
	if tuple [HSL: point->tuple HSL / (360,1,1)]
	HSL
]

HSL->RGB: HSL2RGB: function [
	"Convert colors from HSL(360,1,1) into RGB(1,1,1) color model"
	HSL [point3D! tuple!] "0-360 hue, 0-1 others if point"
	/tuple "Return as a 3-tuple"
][
	if tuple? HSL [HSL: (360,1,1) * tuple->point HSL]
	H: HSL/1 // 360  S: HSL/2  L: HSL/3
	H': H / 60
	C:  S * 2 * min L 1 - L								;-- chroma
	D:  L - (C / 2)										;-- darkest channel
	B:  C + D											;-- brightest channel
	M:  C * (1 - absolute H' % 2 - 1) + D				;-- middle channel
	RGB: switch to integer! H' [
		0 6 [as-point3D B M D]							;-- 6=0 - for H=360 case
		1   [as-point3D M B D]
		2   [as-point3D D B M]
		3   [as-point3D D M B]
		4   [as-point3D M D B]
		5   [as-point3D B D M]
	]
	if tuple [RGB: point->tuple RGB]
	RGB
]


#hide [#assert [
	~=: make op! func [a b] [							;-- account for byte rounding error
		all [
			0.3% >= absolute a/1 - b/1
			0.3% >= absolute a/2 - b/2
			0.3% >= absolute a/3 - b/3
		]
	]
  	(  0, 0, 0.00) ~= RGB->HSL 0.0.0
  	(  0, 0, 1.00) ~= RGB->HSL 255.255.255
  	(  0, 1, 0.50) ~= RGB->HSL 255.0.0
  	(120, 1, 0.50) ~= RGB->HSL 0.255.0
  	(240, 1, 0.50) ~= RGB->HSL 0.0.255
  	( 60, 1, 0.50) ~= RGB->HSL 255.255.0
  	(180, 1, 0.50) ~= RGB->HSL 0.255.255
  	(300, 1, 0.50) ~= RGB->HSL 255.0.255
  	(  0, 0, 0.75) ~= RGB->HSL 191.191.191
  	(  0, 0, 0.50) ~= RGB->HSL 127.127.127
  	(  0, 1, 0.25) ~= RGB->HSL 127.0.0
  	( 60, 1, 0.25) ~= RGB->HSL 127.127.0
  	(120, 1, 0.25) ~= RGB->HSL 0.127.0
  	(300, 1, 0.25) ~= RGB->HSL 127.0.127
  	(180, 1, 0.25) ~= RGB->HSL 0.127.127
  	(240, 1, 0.25) ~= RGB->HSL 0.0.127
]]
#assert [
  	(HSL->RGB/tuple (  0, 0, 0.00)) = 0.0.0
  	(HSL->RGB/tuple (  0, 0, 1.00)) = 255.255.255
  	(HSL->RGB/tuple (  0, 1, 0.50)) = 255.0.0
  	(HSL->RGB/tuple (120, 1, 0.50)) = 0.255.0
  	(HSL->RGB/tuple (240, 1, 0.50)) = 0.0.255
  	(HSL->RGB/tuple ( 60, 1, 0.50)) = 255.255.0
  	(HSL->RGB/tuple (180, 1, 0.50)) = 0.255.255
  	(HSL->RGB/tuple (300, 1, 0.50)) = 255.0.255
  	(HSL->RGB/tuple (  0, 0, 0.75)) = 191.191.191
  	(HSL->RGB/tuple (  0, 0, 0.50)) = 127.127.127
  	(HSL->RGB/tuple (  0, 1, 0.25)) = 127.0.0
  	(HSL->RGB/tuple ( 60, 1, 0.25)) = 127.127.0
  	(HSL->RGB/tuple (120, 1, 0.25)) = 0.127.0
  	(HSL->RGB/tuple (300, 1, 0.25)) = 127.0.127
  	(HSL->RGB/tuple (180, 1, 0.25)) = 0.127.127
  	(HSL->RGB/tuple (240, 1, 0.25)) = 0.0.127
  	
  	(HSL->RGB/tuple RGB->HSL 0.0.0      ) = 0.0.0      
  	(HSL->RGB/tuple RGB->HSL 255.255.255) = 255.255.255
  	(HSL->RGB/tuple RGB->HSL 255.0.0    ) = 255.0.0    
  	(HSL->RGB/tuple RGB->HSL 0.255.0    ) = 0.255.0    
  	(HSL->RGB/tuple RGB->HSL 0.0.255    ) = 0.0.255    
  	(HSL->RGB/tuple RGB->HSL 255.255.0  ) = 255.255.0  
  	(HSL->RGB/tuple RGB->HSL 0.255.255  ) = 0.255.255  
  	(HSL->RGB/tuple RGB->HSL 255.0.255  ) = 255.0.255  
  	(HSL->RGB/tuple RGB->HSL 191.191.191) = 191.191.191
  	(HSL->RGB/tuple RGB->HSL 128.128.128) = 128.128.128
  	(HSL->RGB/tuple RGB->HSL 128.0.0    ) = 128.0.0    
  	(HSL->RGB/tuple RGB->HSL 128.128.0  ) = 128.128.0  
  	(HSL->RGB/tuple RGB->HSL 0.128.0    ) = 0.128.0    
  	(HSL->RGB/tuple RGB->HSL 128.0.128  ) = 128.0.128  
  	(HSL->RGB/tuple RGB->HSL 0.128.128  ) = 0.128.128  
  	(HSL->RGB/tuple RGB->HSL 0.0.128    ) = 0.0.128    
]


brightness?: none
context [
	;; gamma (transfer function) comes from https://en.wikipedia.org/wiki/SRGB#Transformation
	gamma-inverse: func [c] [
		either (c: c / 255) <= 0.04045 [c / 12.92][c + 0.055 / 1.055 ** 2.4]
	]
	gamma: func [x] compose/deep [
		either x <= 0.0031308 [x * 12.92][x ** (1 / 2.4) * 1.055 - 0.055]
	]

	;; CIELab L* formula comes from https://stackoverflow.com/a/13558570 
	;; see also https://en.wikipedia.org/wiki/Relative_luminance#Relative_luminance_and_%22gamma_encoded%22_colorspaces
	;; grayscale example:  https://i.gyazo.com/bbdfa22004bc06ecd0cfa1a6276b784b.jpg
	set 'brightness? function [
		"Get brightness [0..1] of a color tuple as CIELAB achromatic luminance L*"
		color [tuple!]
	][
		gamma add add
			0.212655 * gamma-inverse color/1
			0.715158 * gamma-inverse color/2
			0.072187 * gamma-inverse color/3
	]
]

