Red [
	title:   "FORMAT-READABLE mezzanine"
	purpose: "Advanced number formatter targeted at human reader"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		For simple and dumb format see FORMAT-NUMBER mezz
		For mask based formatters see Gregg's formatting repository

		EXAMPLES
		/size n
			>> format-readable/size pi * 1e-5 3			;) 3 significant figures
			== "0.0000314"
			>> format-readable/size pi * 1e-5 10		;) 10 significant figures
			== "0.00003141592654"		
			>> format-readable/size pi * 1e5 3			;) integer part is not rounded off, groups separated with `'`
			== "314'159"
			>> format-readable pi / 2					;) /size defaults to 2, result is rounded to the last figure
			== "1.6"
			>> format-readable/size pi 0				;) zero /size can be used to format as integer
			== "3"
			>> format-readable/size pi / 10 0			;) 0.314 is closest to integer 0
			== "0"

		/exp e
			>> format-readable/size/exp pi * 1e5 3 5	;) expressed using the exponent=5
			== "3.14e5"
			>> format-readable/size/exp pi * 1e5 3 0	;) using exp=0: integer part is not rounded off even in e-form
			== "314'159e0"
			>> format-readable/exp x: pi * 1e10 exponent-of x	;) exponent can be deduced with `exponent-of`
			== "3.1e10"
			>> format-readable/exp pi * 1e10 'auto		;) or using 'auto as /exp parameter
			== "3.1e10"
			>> format-readable/exp -12345% 'auto		;) '%' is just a sigil and does not affect formatting
			== "-1.2e4%"

		/extend
			>> format-readable/extend pi / 2			;) /extend adds a digit for 1xx numbers
			== "1.57"
			>> format-readable/extend pi				;) but not to 2xx to 9xx
			== "3.1"

		/clean
			>> format-readable 0.01						;) by default significant figures are always added
			== "0.010"
			>> format-readable/clean 0.01				;) /clean reduces the visual noise to a minimum
			== ".01"

		More involved formatters can be built upon it, e.g.:
			format-together: function [value error] [
				error: (absolute value) * error
				ex: exponent-of value
				fer: format-readable/exp/size/extend error ex 1
				clear find fer "e"
				fva: format-readable/exp/size value ex (length? fer) - 1
				fex: take/part find fva "e" tail fva
				rejoin ["(" fva " ± " fer ")" fex]
			]
			>> format-together exp 5  5%
			== "(1.48 ± 0.07)e2"
			>> format-together exp 5  2%
			== "(1.48 ± 0.03)e2"
			>> format-together exp 5  1%
			== "(1.484 ± 0.015)e2"
	}
]

; #include %assert.red
; #include %show-trace.red

context [
	digit:   charset [#"0" - #"9"]
	; dig19:   charset [#"1" - #"9"]
	; nonzero: charset [not #"0"]

	insert-separators: function [formed] [				;-- does not expect separators to be already inserted
		parse formed [
			to [digit | #"."]										;-- skip optional sign, but not leading dot
			s: any digit e: (len: offset? s e)						;-- count digits until suffix/dot/end
			:s (lead: len + 2 % 3 + 1) lead skip					;-- skip leading group
			(grps: max 0 len - lead / 3) grps [insert #"'" 3 skip]	;-- insert separators
		]
		formed
	]

	#assert ["999'999'999'999"   = r: insert-separators "999999999999"   'r]
	#assert [ "99'999'999'999"   = r: insert-separators  "99999999999"   'r]
	#assert [  "9'999'999'999"   = r: insert-separators   "9999999999"   'r]
	#assert [    "999'999'999"   = r: insert-separators    "999999999"   'r]
	#assert [     "99'999'999"   = r: insert-separators     "99999999"   'r]
	#assert [      "9'999'999"   = r: insert-separators      "9999999"   'r]
	#assert [        "999'999"   = r: insert-separators       "999999"   'r]
	#assert [         "99'999"   = r: insert-separators        "99999"   'r]
	#assert [          "9'999"   = r: insert-separators         "9999"   'r]
	#assert [            "999"   = r: insert-separators          "999"   'r]
	#assert [             "99"   = r: insert-separators           "99"   'r]
	#assert [              "9"   = r: insert-separators            "9"   'r]
	#assert [               ""   = r: insert-separators             ""   'r]
	#assert [     "9'999.0000"   = r: insert-separators    "9999.0000"   'r]
	#assert [       "999.0000"   = r: insert-separators     "999.0000"   'r]
	#assert [        "99.0000"   = r: insert-separators      "99.0000"   'r]
	#assert [         "9.0000"   = r: insert-separators       "9.0000"   'r]
	#assert [         "9.000"    = r: insert-separators       "9.000"    'r]
	#assert [         "9.00"     = r: insert-separators       "9.00"     'r]
	#assert [         "9.0"      = r: insert-separators       "9.0"      'r]
	#assert [         "0.999"    = r: insert-separators       "0.999"    'r]
	#assert [         "0.0999"   = r: insert-separators       "0.0999"   'r]
	#assert [          ".00999"  = r: insert-separators        ".00999"  'r]
	#assert [         "0.00999"  = r: insert-separators       "0.00999"  'r]
	#assert [         "0.000999" = r: insert-separators       "0.000999" 'r]
	#assert [         "0.999999" = r: insert-separators       "0.999999" 'r]
	#assert [     "9'999.000%"   = r: insert-separators    "9999.000%"   'r]
	#assert [    "-9'999.000%"   = r: insert-separators   "-9999.000%"   'r]
	#assert [   "-99'999.000%"   = r: insert-separators  "-99999.000%"   'r]
	#assert [  "-999'999.000%"   = r: insert-separators "-999999.000%"   'r]
	#assert [ "-$XX9'999.000"    = r: insert-separators"-$XX9999.000"    'r]	;-- money-like
	#assert ["12'345'678.9E-10"  = r: insert-separators"12345678.9E-10"  'r]	;-- exp notation
	#assert [        "12.3456E3" = r: insert-separators      "12.3456E3" 'r]	;-- but not after the dot

	set 'exponent-of function [
		"Returns the exponent E of X = m * (10 ** e), 1 <= m < 10"
		x [number!]
	][
		if 0 <> x [to 1 round/to/floor log-10 absolute x 1.0]	;-- zero has undefined exponent
	]

	set 'format-readable function [
		"Format a number for readability, in decimal or exponential form"
		num [number!]									;-- original number is needed for rounding to work
		/size   "Specify the number of significant figures"
			n [integer!] "Defaults to 2"
		/exp    "Format in exponential form instead of decimal, using E as exponent"
			e [integer! word!] "E.g. E=0 NUM=123 => 123e0 output; 'auto to deduce E automatically"
		/extend "Let numbers starting with '1' get an additional digit"
		/clean  "Remove trailing zeroes after the dot and leading zero before the dot"
	][
		#assert [any [none? e  integer? e  'auto = e]]
		#assert [(
			|num|: absolute num
			any [0 = |num|  all [1e-30 < |num| |num| < 1e30]]	;-- limits help simplify the algorithm
		)]														;-- bigger limits reduce rounding precision and fail the tests
																;@@ ideally we want string-based precise rounding here
		;-- setup
		n: any [n 2]
		e: any [e 0]
		num': 1e50 * absolute num						;-- convert percent/int into float, force exp output
		if percent? num [num': num' * 100]
		
		;-- determine the rounding digit and round it
		do renew: [
			e0: -50 + any [exponent-of num'  50]		;-- extract original exponent
			if 'auto = e [e: e0]
			formed: form num'
			ext: make 1 extend and (#"1" = formed/1)	;-- add a digit for 1.xx numbers
			n-digits: max								;-- determine the number of digits for rounding
				n + ext									;-- requested size + possibly extended by 1
				e0 - e + 1								;-- number of whole digits which we don't want to zero out
		]
		num': round/to num' 10 ** (e0 - n-digits + 1) * 1e50

		;-- form rounded result and update width
		do renew
		
		;-- clean up formed result and ensure proper length
		clear find (remove find formed #".") #"e"			;-- leave only digits
		clear skip formed n-digits							;-- clean up possible rounding errors e.g. 0.9900000000002
		append/dup formed #"0" n-digits - length? formed	;-- right-pad with zeroes up to N size
		if e0 < e [											;-- left-pad the future dot with zeroes
			insert/dup formed #"0" e - e0
			e0: e
		]

		;-- insert the dot, but only if there are digits after it
		dot: skip formed e0 - e + 1
		unless tail? dot [insert dot #"."]

		;-- remove unnecessary zeroes as visual noise
		if clean [
			parse reverse dot [remove [any #"0" opt #"."]]	;-- trailing zeroes
			reverse dot
			parse formed [remove [#"0" ahead skip]]			;-- leading zero
		]

		if exp [append append formed #"e" e]			;-- add the exponent if requested
		if percent? num [append formed #"%"]			;-- type sigil
		if num < 0 [insert formed #"-"]					;-- sign
		insert-separators formed
	]

	#assert [     "23"       = r: format-readable             23.45      'r]
	#assert [    "-23"       = r: format-readable            -23.45      'r]
	#assert [      "2.3"     = r: format-readable              2.345     'r]
	#assert [      "0.23"    = r: format-readable              0.2345    'r]
	#assert [      "0.023"   = r: format-readable              0.02345   'r]
	#assert [      "0.0023"  = r: format-readable              0.002345  'r]
	#assert [      "0.00023" = r: format-readable              0.0002345 'r]
	#assert [      "0.0123"  = r: format-readable/extend       0.0123    'r]
	#assert [       ".0001"  = r: format-readable/clean   1e-4           'r]
	#assert [      "-.0001"  = r: format-readable/clean  -1e-4           'r]
	#assert [      "0.00010" = r: format-readable         1e-4           'r]
	#assert [     "-0.000100"= r: format-readable/extend -1e-4           'r]
	#assert ["999'999"       = r: format-readable         999999         'r]
	#assert ["999'999"       = r: format-readable         999999.1       'r]
	#assert ["999'999"       = r: format-readable         999999.123     'r]
	#assert ["100'000"       = r: format-readable          99999.999     'r]
	#assert ["-10'000"       = r: format-readable          -9999.999     'r]
	#assert [ "-1'000"       = r: format-readable           -999.999     'r]
	#assert [   "-100"       = r: format-readable            -99.999     'r]
	#assert [    "-10"       = r: format-readable             -9.999     'r]
	#assert [    "-10.0"     = r: format-readable/extend      -9.999     'r]
	#assert ["111'112.0"     = r: format-readable/size    111111.999 7   'r]
	#assert ["211'112"       = r: format-readable/size    211111.999 3   'r]
	#assert ["111'112"       = r: format-readable         111111.999     'r]
	#assert [ "11'112"       = r: format-readable          11111.999     'r]
	#assert [  "1'112"       = r: format-readable           1111.999     'r]
	#assert [    "112"       = r: format-readable            111.999     'r]
	#assert [     "12"       = r: format-readable             11.999     'r]
	#assert [     "12.0"     = r: format-readable/extend      11.999     'r]
	#assert [      "2"       = r: format-readable/clean        1.999     'r]
	#assert [      "0.99"    = r: format-readable              0.991     'r]
	#assert [      "1.0"     = r: format-readable              0.999     'r]
	#assert [      "1"       = r: format-readable/clean        0.999     'r]
	#assert [      "0.099"   = r: format-readable              0.0991    'r]
	#assert [      "0.10"    = r: format-readable              0.0999    'r]
	#assert [       ".1"     = r: format-readable/clean        0.0999    'r]
	#assert [      "0.0099"  = r: format-readable              0.00989   'r]
	#assert [      "0.0099"  = r: format-readable              0.00991   'r]
	#assert [      "0.010"   = r: format-readable              0.00999   'r]
	#assert [       ".01"    = r: format-readable/clean        0.00999   'r]
	#assert [      "0.0199"  = r: format-readable/extend       0.01989   'r]
	#assert [      "0.0199"  = r: format-readable/extend       0.01991   'r]
	#assert [      "0.020"   = r: format-readable              0.01999   'r]
	#assert [       ".02"    = r: format-readable/clean        0.01999   'r]
	#assert [      "0.021"   = r: format-readable              0.02099   'r]
	#assert [      "0.021"   = r: format-readable              0.02111   'r]
	#assert [      "0.123"   = r: format-readable/extend       0.1234    'r]
	#assert [      "0.20"    = r: format-readable/extend       0.1999    'r]
	#assert [       ".2"     = r: format-readable/clean        0.1999    'r]
	#assert [      "0.21"    = r: format-readable              0.2099    'r]
	#assert [      "2.1"     = r: format-readable              2.099     'r]
	#assert [     "21"       = r: format-readable             20.99      'r]
	#assert [    "210"       = r: format-readable            209.9       'r]
	#assert [  "2'100"       = r: format-readable           2099.9       'r]
	#assert [  "2'099"       = r: format-readable           2099.1       'r]
	
	#assert [      "0"       = r: format-readable/clean        0         'r]		;-- log overflow test
	#assert [      "0"       = r: format-readable/clean        0.0       'r]
	#assert [      "0"       = r: format-readable/clean       -0.0       'r]		;-- form removes the sign; mold doesn't
	#assert [      "0.0"     = r: format-readable              0         'r]
	#assert [      "0.00"    = r: format-readable/size         0 3       'r]
	#assert [      "0"       = r: format-readable/clean/size   0 3       'r]
	#assert [      "0.0000"  = r: format-readable/size         0 5       'r]
	#assert [       ".00001" = r: format-readable/clean        1e-5      'r]		;-- shouldn't be formed as "1e-5"
	
	#assert [      "0%"      = r: format-readable/clean        0%        'r]
	#assert [    "123%"      = r: format-readable            123%        'r]
	#assert [  "2'345%"      = r: format-readable           2345%        'r]
	#assert [      "2.3%"    = r: format-readable              2.345%    'r]
	#assert [     "-2.3%"    = r: format-readable             -2.345%    'r]

	#assert [    "123e0"     = r: format-readable/exp        123 0       'r]
	#assert [   "12.3e1"     = r: format-readable/exp/extend 123 1       'r]
	#assert [    "1.2e2"     = r: format-readable/exp        123 2       'r]
	#assert [    "234e0"     = r: format-readable/exp        234 0       'r]
	#assert [    "234e0"     = r: format-readable/exp/size   234 0 1     'r]
	#assert [    "234e0"     = r: format-readable/exp/size   234 0 2     'r]
	#assert [  "234.0e0"     = r: format-readable/exp/size   234 0 4     'r]
	#assert [     "23e1"     = r: format-readable/exp        234 1       'r]
	#assert [    "2.3e2"     = r: format-readable/exp        234 2       'r]
	#assert [   "0.23e3"     = r: format-readable/exp        234 3       'r]
	#assert [  "0.023e4"     = r: format-readable/exp        234 4       'r]
	#assert [ "0.0123e4"     = r: format-readable/exp/extend 123 4       'r]
	#assert [ "0.0023e5"     = r: format-readable/exp        234 5       'r]
	#assert [  "2'340e-1"    = r: format-readable/exp        234 -1      'r]
	#assert [ "23'400e-2"    = r: format-readable/exp        234 -2      'r]
	#assert [ "12'300e-2"    = r: format-readable/exp        123 -2      'r]
	#assert [ "12'300e-2"    = r: format-readable/exp/clean  123 -2      'r]
	#assert ["-12'300e-2"    = r: format-readable/exp       -123 -2      'r]
	; #assert [   "0.23e83"    = r: format-readable/exp        234e80 83   'r]
	; #assert [   "0.20e83"    = r: format-readable/exp        200e80 83   'r]
	; #assert [  "-0.20e83"    = r: format-readable/exp       -200e80 83   'r]
	#assert [    "1.2e3"     = r: format-readable/exp       1.234e3 3    'r]
	#assert [    "1.2e1"     = r: format-readable/exp       1.234e1 1    'r]
	#assert [    "1.2e0"     = r: format-readable/exp       1.234e0 0    'r]
	#assert [    "1.2e-1"    = r: format-readable/exp       1.234e-1 -1  'r]
	#assert [     "12e-3"    = r: format-readable/exp       1.234e-2 -3  'r]
	#assert [     "12e-5"    = r: format-readable/exp       1.234e-4 -5  'r]
]


{
	;-- reversed version - not better if done correctly, because has to skip a lot of extra stuff
	insert-separators: function [formed] [
		parse reverse formed [
			opt #"%"
			opt [some digit opt #"-" #"e"]
			opt [some digit #"."]
			any [3 digit ahead digit insert #"'"]
		]
		reverse formed
	]

	;-- a bit more convoluted version, and limited by exponent range even more
	;-- instead of forming in e-form it forms in decimal form internally (but that works up to 1e20 max)
	;-- has a bug, /exp is not implemented
	format-readable: function [
		"Format a number in decimal form, using N significant digits"
		num [number!]
		/size "Defaults to -2; numbers starting with '1' get an additional digit"
			n [integer!] "Negative N won't round integer part of NUM (i.e. 9876.5 -> 9877, not 9900)"
		; /exp "Format with exponent instead of decimal form"
		; 	e [integer!] "E.g. E=0 NUM=123 => 123e+0 output"
		/clean "Remove trailing zeroes after the dot"
	][
		n: any [n -2]
		e: any [e 0]

		;-- need to move all visible digits after the dot to get non-exp output from `form`
		|n|: absolute n
		either num = 0 [								;-- special case for zero, where log-10 = -inf
			whole: 1
			power: 0
		][
			whole: 1 + to 1 round/floor/to log-10 num / 2 1.0	;-- number of whole digits; /to 1 is buggy (#4882) so using 1.0
																;-- num / 2 allows to add a digit to numbers starting with "1"
			power: |n| - whole							;-- power of 10 to multiply the num with to get rid of fractional part
		]
		if n < 0 [power: max 0 power]					;-- don't round integers if n<0
		
		;-- multiply by power of 10 so `form` does not result in exponential notation
		rounded: round/to 10.0 ** power * num 1.0
		formed: form rounded
		
		;-- find the dot position and remove the ".0" suffix
		clear skip tail formed -2
		dot: (1 + length? formed) - power				;-- dot was shifted by power digits
		whole: dot - 1
		
		;-- ensure max(n,whole) digits even if num=0
		append/dup formed #"0" (max |n| whole) - length? formed
		
		;-- insert the new dot
		dot: either dot <= 1 [							;-- dot should be inserted at head or earlier?
			next head insert/dup formed #"0" 2 - dot	;-- pad with zeroes before the dot then
		][
			at formed dot
		]
		insert dot #"."

		;-- cleanup
		case/all [
			clean [										;-- remove trailing zeroes when clean=on
				clear find/last/tail dot nonzero
			]
			#"." = last formed [						;-- don't leave trailing dot without any more digits
				take/last formed
			]
			all [clean find/match formed "0."] [		;-- remove leading zero when clean=on
				take formed
			]
		]
		if percent? num [append formed #"%"]
		formed
	]

}

