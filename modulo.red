Red [
	title:   "Proper MODULO function"
	purpose: "Tired of waiting for it to be fixed in Red"
	author:  @hiiamboris
	license: 'BSD-3
]


#include %assert.red

context [
	abs: :absolute
	positives!: make typeset! [char! tuple!]				;-- limited types (can't be negated)
	roundable!: make typeset! [float! time!]				;-- types that may be rounded

	set 'modulo function [
		"Returns a modulo R of A divided by B. Defaults to Euclidean definition of modulo (R >= 0)"
		a [number! char! pair! tuple! vector! time!]
		b [number! char! pair! tuple! vector! time!]
		/floor "Follow the Floored definition: sgn(R) = sgn(B)"
		/trunc "Follow the Truncated definition: sgn(R) = sgn(A)"
		/round "Round near-terminal results (e.g. near zero or near B) to zero"
		; return: [number! char! pair! tuple! vector! time!] "Same type as A"
	][
		#assert [not all [floor trunc] "/floor & /trunc are mutually exclusive"]

		r: a % b
		case [
			find positives! type? a [
				#assert [any [							;-- check allowed divisor combinations
					(type? a) = type? b					;-- tuple+tuple, char+char
					all [
						integer? b    					;-- require integer divisor otherwise
					    any [b > 0  not floor]			;-- >0 in case of Floor (R cannot be negative)
					]									;-- (=0 case triggers error on the 1st line)
				]]
			]
			trunc   []									;@@ TODO: move this check up when #4576 gets fixed
			floor   [r: r + b % b]
			'euclid [|b|: abs b  r: r + |b| % b]
		]

		;; integral types just skip rounding
		;; in vectors we would have to round every item separately, which is inefficient, so we skip them too
		if all [round  find roundable! type? r] [		;-- force result to satisfy `0 <= abs(r) < abs(b)` equation
			|b|:  any [|b| abs b]
			|r|+|b|: |b| + abs r
			if any [
				|r|+|b| - |b| == |b|					;-- result is near b, as it turns into b with r+b-b
				|r|+|b| + |b| == (|b| * 2)				;-- result is near 0, as it gets lost by appending 2b
														;-- (r+2b=2b is more aggressive than r+b=b, for symmetry with r+b-b)
			][
				r: r * 0								;-- zero multiplication preserves the original type and sign (even zero sign)
			]
		]

		r
	]

	set '// make op! func [
		"Returns a modulo R of A divided by B, following Euclidean definition of it (R >= 0)"
		a [number! char! pair! tuple! vector! time!]
		b [number! char! pair! tuple! vector! time!]
		; return: [number! char! pair! tuple! vector! time!] "Same type as A"
	][
		modulo a b
	]
]

;@@ TODO: Linux and esp. ARM may produce different results for floats, and may need tests update

;; need a few values defined
#assert [-1.3877787807814457e-17 =? -x: 0.15 - 0.05 - 0.1  'x]	;-- comes from some test on the internet IIRC
#assert [ 1.3877787807814457e-17 =? +x: 0 - -x]
#assert [-a: -1e-16]											;-- just a few values near float/epsilon
#assert [+a:  1e-16]
#assert [-b: -1e-17]
#assert [+b:  1e-17]
#assert [-c: -1e-18]
#assert [+c:  1e-18]
#assert [+max:  2147483647]										;-- extreme integers
#assert [-max: -2147483648]
#assert [ 0.1 + -x =? +I:   0.09999999999999999 '+I]			;-- results of adding epsilon to a value near 1
#assert [-0.1 + +x =? -I:  -0.09999999999999999 '-I]
#assert [ 0.1 + -a =? +IA:  0.09999999999999991 '+IA]
#assert [-0.1 + +a =? -IA: -0.09999999999999991 '-IA]
#assert [+a + 0.1 - 0.1 =? +a':  9.71445146547012e-17 '+a']		;-- FP rounding errors distort original small value
#assert [-a - 0.1 + 0.1 =? -a': -9.71445146547012e-17 '-a']
#assert [+b + 0.1 - 0.1 =? +b':  1.3877787807814457e-17 '+b']
#assert [-b - 0.1 + 0.1 =? -b': -1.3877787807814457e-17 '-b']

; #assert [ 0.1 + -c =? +C:  0.09999999999999991 '+C]
; #assert [-0.1 + +c =? -C: -0.09999999999999991 '-C]

;; euclidean definition - always nonnegative
#assert [+I   =? r: modulo -x  0.1             'r]
#assert [+I   =? r: modulo -x -0.1             'r]
#assert [+x   =? r: modulo +x  0.1             'r]
#assert [+x   =? r: modulo +x -0.1             'r]

#assert [+IA  =? r: modulo -a  0.1             'r]
#assert [+IA  =? r: modulo -a -0.1             'r]
#assert [+a'  =? r: modulo +a  0.1             'r]		;-- gets distorted by addition/subtraction
#assert [+a'  =? r: modulo +a -0.1             'r]

#assert [+I   =? r: modulo -b  0.1             'r]
#assert [+I   =? r: modulo -b -0.1             'r]
#assert [+b'  =? r: modulo +b  0.1             'r]		;-- gets distorted by addition/subtraction
#assert [+b'  =? r: modulo +b -0.1             'r]

#assert [0.0  =? r: modulo -c  0.1             'r]		;-- small enough to disappear
#assert [0.0  =? r: modulo -c -0.1             'r]
#assert [0.0  =? r: modulo +c  0.1             'r]
#assert [0.0  =? r: modulo +c -0.1             'r]

#assert [0.0  =? r: modulo/round -x  0.1       'r]
#assert [0.0  =? r: modulo/round -x -0.1       'r]
#assert [0.0  =? r: modulo/round +x  0.1       'r]
#assert [0.0  =? r: modulo/round +x -0.1       'r]

#assert [+IA  =? r: modulo/round -a  0.1       'r]		;-- big enough not to get rounded
#assert [+IA  =? r: modulo/round -a -0.1       'r]
#assert [+a'  =? r: modulo/round +a  0.1       'r]
#assert [+a'  =? r: modulo/round +a -0.1       'r]

#assert [0.0  =? r: modulo/round -b  0.1       'r]
#assert [0.0  =? r: modulo/round -b -0.1       'r]
#assert [0.0  =? r: modulo/round +b  0.1       'r]
#assert [0.0  =? r: modulo/round +b -0.1       'r]

#assert [0.0  =? r: modulo/round -c  0.1       'r]
#assert [0.0  =? r: modulo/round -c -0.1       'r]
#assert [0.0  =? r: modulo/round +c  0.1       'r]
#assert [0.0  =? r: modulo/round +c -0.1       'r]


;; floored definition - same sign as divisor
#assert [+I   =? r: modulo/floor -x  0.1       'r]
#assert [-x   =? r: modulo/floor -x -0.1       'r]
#assert [+x   =? r: modulo/floor +x  0.1       'r]
#assert [-I   =? r: modulo/floor +x -0.1       'r]

#assert [+IA  =? r: modulo/floor -a  0.1       'r]
#assert [-a'  =? r: modulo/floor -a -0.1       'r]
#assert [+a'  =? r: modulo/floor +a  0.1       'r]
#assert [-IA  =? r: modulo/floor +a -0.1       'r]

#assert [+I   =? r: modulo/floor -b  0.1       'r]
#assert [-b'  =? r: modulo/floor -b -0.1       'r]
#assert [+b'  =? r: modulo/floor +b  0.1       'r]
#assert [-I   =? r: modulo/floor +b -0.1       'r]

#assert [ 0.0 =? r: modulo/floor -c  0.1       'r]
#assert [-0.0 =? r: modulo/floor -c -0.1       'r]		;-- =? (same?) allows to distinguish -0 from +0
#assert [ 0.0 =? r: modulo/floor +c  0.1       'r]
#assert [-0.0 =? r: modulo/floor +c -0.1       'r]

#assert [ 0.0 =? r: modulo/floor/round -x  0.1 'r]
#assert [-0.0 =? r: modulo/floor/round -x -0.1 'r]
#assert [ 0.0 =? r: modulo/floor/round +x  0.1 'r]
#assert [-0.0 =? r: modulo/floor/round +x -0.1 'r]

#assert [+IA  =? r: modulo/floor/round -a  0.1 'r]
#assert [-a'  =? r: modulo/floor/round -a -0.1 'r]
#assert [+a'  =? r: modulo/floor/round +a  0.1 'r]
#assert [-IA  =? r: modulo/floor/round +a -0.1 'r]

#assert [ 0.0 =? r: modulo/floor/round -b  0.1 'r]
#assert [-0.0 =? r: modulo/floor/round -b -0.1 'r]
#assert [ 0.0 =? r: modulo/floor/round +b  0.1 'r]
#assert [-0.0 =? r: modulo/floor/round +b -0.1 'r]

#assert [ 0.0 =? r: modulo/floor/round -c  0.1 'r]
#assert [-0.0 =? r: modulo/floor/round -c -0.1 'r]
#assert [ 0.0 =? r: modulo/floor/round +c  0.1 'r]
#assert [-0.0 =? r: modulo/floor/round +c -0.1 'r]


;; truncated definition - same sign as dividend
#assert [-x   =? r: modulo/trunc -x  0.1       'r]
#assert [-x   =? r: modulo/trunc -x -0.1       'r]
#assert [+x   =? r: modulo/trunc +x  0.1       'r]
#assert [+x   =? r: modulo/trunc +x -0.1       'r]

#assert [-a   =? r: modulo/trunc -a  0.1       'r]
#assert [-a   =? r: modulo/trunc -a -0.1       'r]
#assert [+a   =? r: modulo/trunc +a  0.1       'r]
#assert [+a   =? r: modulo/trunc +a -0.1       'r]

#assert [-b   =? r: modulo/trunc -b  0.1       'r]
#assert [-b   =? r: modulo/trunc -b -0.1       'r]
#assert [+b   =? r: modulo/trunc +b  0.1       'r]
#assert [+b   =? r: modulo/trunc +b -0.1       'r]

#assert [-c   =? r: modulo/trunc -c  0.1       'r]
#assert [-c   =? r: modulo/trunc -c -0.1       'r]
#assert [+c   =? r: modulo/trunc +c  0.1       'r]
#assert [+c   =? r: modulo/trunc +c -0.1       'r]

#assert [-0.0 =? r: modulo/trunc/round -x  0.1 'r]
#assert [-0.0 =? r: modulo/trunc/round -x -0.1 'r]
#assert [ 0.0 =? r: modulo/trunc/round +x  0.1 'r]
#assert [ 0.0 =? r: modulo/trunc/round +x -0.1 'r]

#assert [-a   =? r: modulo/trunc/round -a  0.1 'r]
#assert [-a   =? r: modulo/trunc/round -a -0.1 'r]
#assert [+a   =? r: modulo/trunc/round +a  0.1 'r]
#assert [+a   =? r: modulo/trunc/round +a -0.1 'r]

#assert [-0.0 =? r: modulo/trunc/round -b  0.1 'r]
#assert [-0.0 =? r: modulo/trunc/round -b -0.1 'r]
#assert [ 0.0 =? r: modulo/trunc/round +b  0.1 'r]
#assert [ 0.0 =? r: modulo/trunc/round +b -0.1 'r]

#assert [-0.0 =? r: modulo/trunc/round -c  0.1 'r]
#assert [-0.0 =? r: modulo/trunc/round -c -0.1 'r]
#assert [ 0.0 =? r: modulo/trunc/round +c  0.1 'r]
#assert [ 0.0 =? r: modulo/trunc/round +c -0.1 'r]


;; integer tests
#assert [   0 = r: modulo       1000  500 'r]

#assert [ 123 = r: modulo        123  500 'r]
#assert [ 123 = r: modulo        123 -500 'r]
#assert [ 377 = r: modulo       -123  500 'r]
#assert [ 377 = r: modulo       -123 -500 'r]

#assert [ 123 = r: modulo/floor  123  500 'r]
#assert [-377 = r: modulo/floor  123 -500 'r]
#assert [ 377 = r: modulo/floor -123  500 'r]
#assert [-123 = r: modulo/floor -123 -500 'r]

#assert [ 123 = r: modulo/trunc  123  500 'r]
#assert [ 123 = r: modulo/trunc  123 -500 'r]
#assert [-123 = r: modulo/trunc -123  500 'r]
#assert [-123 = r: modulo/trunc -123 -500 'r]

#assert [  23 = r: modulo        123  50  'r]
#assert [  23 = r: modulo        123 -50  'r]
#assert [  27 = r: modulo       -123  50  'r]
#assert [  27 = r: modulo       -123 -50  'r]

#assert [  23 = r: modulo/floor  123  50  'r]
#assert [ -27 = r: modulo/floor  123 -50  'r]
#assert [  27 = r: modulo/floor -123  50  'r]
#assert [ -23 = r: modulo/floor -123 -50  'r]

#assert [  23 = r: modulo/trunc  123  50  'r]
#assert [  23 = r: modulo/trunc  123 -50  'r]
#assert [ -23 = r: modulo/trunc -123  50  'r]
#assert [ -23 = r: modulo/trunc -123 -50  'r]

#assert [2    =? r: modulo       -max  10 'r]		;-- extreme ints produce ints, not floats
#assert [2    =? r: modulo       -max -10 'r]
#assert [7    =? r: modulo       +max  10 'r]
#assert [7    =? r: modulo       +max -10 'r]

#assert [ 2   =? r: modulo/floor -max  10 'r]
#assert [-8   =? r: modulo/floor -max -10 'r]
#assert [ 7   =? r: modulo/floor +max  10 'r]
#assert [-3   =? r: modulo/floor +max -10 'r]

#assert [-8   =? r: modulo/trunc -max  10 'r]
#assert [-8   =? r: modulo/trunc -max -10 'r]
#assert [ 7   =? r: modulo/trunc +max  10 'r]
#assert [ 7   =? r: modulo/trunc +max -10 'r]


;; time tests
#assert [ 0:03:45 = r: modulo        1:23:45  0:10 'r]
#assert [ 0:03:45 = r: modulo        1:23:45 -0:10 'r]
#assert [ 0:06:15 = r: modulo       -1:23:45  0:10 'r]
#assert [ 0:06:15 = r: modulo       -1:23:45 -0:10 'r]

#assert [ 0:03:45 = r: modulo/floor  1:23:45  0:10 'r]
#assert [-0:06:15 = r: modulo/floor  1:23:45 -0:10 'r]
#assert [ 0:06:15 = r: modulo/floor -1:23:45  0:10 'r]
#assert [-0:03:45 = r: modulo/floor -1:23:45 -0:10 'r]

#assert [ 0:03:45 = r: modulo/trunc  1:23:45  0:10 'r]
#assert [ 0:03:45 = r: modulo/trunc  1:23:45 -0:10 'r]
#assert [-0:03:45 = r: modulo/trunc -1:23:45  0:10 'r]
#assert [-0:03:45 = r: modulo/trunc -1:23:45 -0:10 'r]


;; vector tests
#assert [vec: func [x][make vector! x]]
#assert [+v: vec[-4 -3 -2 -1 0 1 2 3 4]]
#assert [-v: (copy +v) * -1]

#assert [(vec[2 0 1 2 0 1 2 0 1])      = r: modulo        copy +v  3 'r]
#assert [(vec[2 0 1 2 0 1 2 0 1])      = r: modulo        copy +v -3 'r]
#assert [(vec[1 0 2 1 0 2 1 0 2])      = r: modulo        copy -v  3 'r]
#assert [(vec[1 0 2 1 0 2 1 0 2])      = r: modulo        copy -v -3 'r]

#assert [(vec[2 0 1 2 0 1 2 0 1])      = r: modulo/floor  copy +v  3 'r]
#assert [(vec[1 0 2 1 0 2 1 0 2]) * -1 = r: modulo/floor  copy +v -3 'r]
#assert [(vec[1 0 2 1 0 2 1 0 2])      = r: modulo/floor  copy -v  3 'r]
#assert [(vec[2 0 1 2 0 1 2 0 1]) * -1 = r: modulo/floor  copy -v -3 'r]

#assert [(vec[-1 0 -2 -1 0 1 2 0 1])   = r: modulo/trunc  copy +v  3 'r]
#assert [(vec[-1 0 -2 -1 0 1 2 0 1])   = r: modulo/trunc  copy +v -3 'r]
#assert [(vec[1 0 2 1 0 -1 -2 0 -1])   = r: modulo/trunc  copy -v  3 'r]
#assert [(vec[1 0 2 1 0 -1 -2 0 -1])   = r: modulo/trunc  copy -v -3 'r]


;; pair tests
#assert [ 2x4  = r: modulo        12x34  5x10  'r]
#assert [ 2x4  = r: modulo        12x34 -5x10  'r]
#assert [ 3x4  = r: modulo       -12x34  5x10  'r]
#assert [ 3x4  = r: modulo       -12x34 -5x10  'r]

#assert [ 2x4  = r: modulo/floor  12x34  5x10  'r]
#assert [-3x4  = r: modulo/floor  12x34 -5x10  'r]
#assert [ 3x4  = r: modulo/floor -12x34  5x10  'r]
#assert [-2x4  = r: modulo/floor -12x34 -5x10  'r]

#assert [ 2x4  = r: modulo/trunc  12x34  5x10  'r]
#assert [ 2x4  = r: modulo/trunc  12x34 -5x10  'r]
#assert [-2x4  = r: modulo/trunc -12x34  5x10  'r]
#assert [-2x4  = r: modulo/trunc -12x34 -5x10  'r]


;; positives tests
#assert [23.34.56.7 = r: modulo       123.234.56.7 100 'r]
#assert [23.34.56.7 = r: modulo/floor 123.234.56.7 100 'r]
#assert [23.34.56.7 = r: modulo/trunc 123.234.56.7 100 'r]
#assert [23.34.56.7 = r: modulo       123.234.56.7 -100 'r]	;-- allow negative divisor when result will be positive
#assert [23.34.56.7 = r: modulo/trunc 123.234.56.7 -100 'r]

#assert [23.34.56.7 = r: modulo       123.234.56.7 50.100.200.250 'r]
#assert [23.34.56.7 = r: modulo/floor 123.234.56.7 50.100.200.250 'r]
#assert [23.34.56.7 = r: modulo/trunc 123.234.56.7 50.100.200.250 'r]

#assert [#"^A" = r: modulo       #"^I" #"^D" 'r]
#assert [#"^A" = r: modulo/floor #"^I" #"^D" 'r]
#assert [#"^A" = r: modulo/trunc #"^I" #"^D" 'r]
#assert [#"^A" = r: modulo       #"^I" 4 'r]
#assert [#"^A" = r: modulo/floor #"^I" 4 'r]
#assert [#"^A" = r: modulo/trunc #"^I" 4 'r]
#assert [#"^A" = r: modulo       #"^I" -4 'r]	;-- allow negative divisor when result will be positive
#assert [#"^A" = r: modulo/trunc #"^I" -4 'r]
#assert [   1  = r: modulo       9 #"^D" 'r]
#assert [   1  = r: modulo/floor 9 #"^D" 'r]
#assert [   1  = r: modulo/trunc 9 #"^D" 'r]

