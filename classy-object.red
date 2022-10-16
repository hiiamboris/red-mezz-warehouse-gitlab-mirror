Red [
	title:       "CLASSY-OBJECT! prototype"
	description: "A per-class implementation of object field's type/value checking"
	author:      @hiiamboris
	license:     'BSD-3
	notes: {
		This implements objects with automatic:
		- type and value validity checking
		  this allows to put constraints on object's exposed words
		  and limit error propagation as well as provide user friendly error messages
		- laziness towards assignment of equal value
		  this allows to avoid doing extra work when new value equals old
		- separate on-change actor for every word
		  this is meant to simplify on-change and reduce the number of bugs in it
		
		Validation patterns are defined once per class and shared between objects of the same class.
		This is done to have the minimum overhead:
		- reduce the RAM requirements that would be high if validation data was unique to each object
		- reduce CPU load by avoiding recreation of validation data on each object creation
	}
	usage: {
		Class is declared with DECLARE-CLASS function.
		It takes an object spec block with specifiers and returns a make-able spec block without them:
			my-spec: declare-class 'my-class [
				x: 1   #type [integer!]					;) just type restriction for X
				y: 0%  #type [number!] (y >= 0)			;) type+value restriction for Y
				z: 1:0 #type [							;) type-specific value restrictions for Z
					time! (z >= 0:0)
					date! (z >= 1900/1/1)
					any-string! (all [date? z: transcode/one as string! z  z >= 1900/1/1])
				]
				
				s: "data"
				#on-change [obj word val] [				;) action on S change
					print ["changing s to" val]
				]
				#type == [string!]						;) change tolerance and type restriction for S
			]
			
		Supported specifiers are:
		  #type which accepts in any order (all are optional):
			- [block with type/typeset names]
			  by default any-type! is allowed
			  may contain (parens with expressions to test value's validity for ALL preceding types)
			  i.e. x [integer! float! (x >= 0) none!] tests both integer and float
			- (paren with an expression to test the value's validity)
			  by default all values are accepted
			  applies to all accepted types that do NOT have a type-specific value check (in type block)
			- equality type: one of [= == =?]
			  by default no equality test is performed and on-change always gets called
			  tip: `==` is good for scalars and strings, `=?` for blocks
			- :existing-func-name for on-change handler
			  alias for #on-change :existing-func-name for declaration brevity
		  #on-change [obj word value] [function body], or
		  #on-change :existing-func-name
			which creates a `function` that reacts to word's changes
		Specifiers apply to the first set-word that precedes them.
		
		Multiple specifiers complement each other, so e.g. upper class may define allowed types,
		then descending class may define equality type or on-change handler.
		Of course, the same feature (type check, value check, equality, on-change) gets replaced when it's specified again.
		
		CLASSIFY-OBJECT function assigns an object to a given class, enabling validation specific to that class.
		It can be called at any time, but for more safety should be before any assignments are made.
		The above MY-SPEC once evaluated will classify itself first, then assign values,
		because `classify-object` call is inserted automatically into the spec produced by declare-class.
		
		DECLARE-CLASS <class-name> <spec> can take a path of two words as it's <class-name>: 'new-class/other-class.
		It will copy validation from already declared other-class to the new-class.
		
		MODIFY-CLASS <class-name> <spec> is used to make adjustments to an existing class
		Uses same syntax as DECLARE-CLASS, though set-words do not need any values in it.
		Use cases:
		- add on-change handler to a word that's not in the object's spec
		- (in some addon) adjust a class that was declared elsewhere
		
		After class is declared, objects can be instantiated:
			my-object1: make classy-object! my-spec
			my-object2: make classy-object! my-spec
			my-other-spec: declare-class 'other-class/my-class [
				u: "unrestricted"
				w: 'some-word  #type [word!]
			]
			my-object3: make my-object2 my-other-spec
		
		Let's do some tests now:
			>> my-object1/x: 2
			== 2
			>> my-object1/x: 'oops
			*** User Error: {Word x can't accept `oops` of type word!, only [integer!]}
			*** Where: do
			*** Near : types'
			*** Stack: on-change-dispatch check-type
			
			>> my-object1/y: 10000
			== 10000
			>> my-object1/y: -10000
			*** User Error: "Word y can't accept `-10000` value, only [y >= 0]"
			*** Where: do
			*** Near : values'
			*** Stack: on-change-dispatch check-value
			
			>> my-object1/s: "new data"
			changing s to new data
			== "new data"
			>> my-object1/s: "new data"					;) notice that on-change doesn't fire here
			== "new data"
			>> my-object1/s: "New Data"
			changing s to New Data
			== "New Data"
			
			>> ?? my-object1
			my-object1: make object! [
			    x: 2
			    y: 10000
			    s: "New Data"
			]
			
			>> my-object3/w: 1:0
			*** User Error: {Word w can't accept `1:00:00` of type time!, only [word!]}
			*** Where: do
			*** Near : types'
			*** Stack: on-change-dispatch check-type
			
			>> unset in my-object3 'w
			*** User Error: {Word w can't accept `unset` of type unset!, only [word!]}
			*** Where: do
			*** Near : types'
			*** Stack: on-change-dispatch check-type
			
			>> unset in my-object3 'u
			>> ?? my-object3
			my-object3: make object! [
			    x: 1
			    y: 0%
			    s: "data"
			    u: unset
			    w: 'some-word
			]
			
		See also %typed-object.red which is a different (and incompatible) approach
	}
	benchmarks: {
		0.24 μs		object/word: value					;) with empty but existing on-change*
		1.21 μs		maybe object/word: value
		1.07 μs		classy-object/untracked-word: value
		1.59 μs		classy-object/tracked-word: same-value
		2.88 μs		classy-object/tracked-word: new-value
	}
	limitations: {
		on-change* cannot be redefined or it will break validation
		  use per-value #on-change markers instead
		  if it is redefined, it must include the following call:
			  on-change-dispatch 'class-name self word :old :new
		  on-change-dispatch performs the validation
		  classify-object function uses it's name as a marker to change the class-name
		  and relies on the assumption that it's a single token
		  
		error are always reported in on-change-dispatch, can't do nothing about that :(
		  need rebol's [catch] function attribute for that
	}
	design: {
		Why spec preprocessing?
			I needed to remove validation setup from object's instantiation code,
			so I wouldn't add overhead to each object's creation.
			My primary use case is Spaces, and there every bit of performance makes a difference in FPS.
			Having separate validation data keeps `mold obj` output clean as well.
			
		Why not use Red preprocessor for that?
			I wanted to be able to share single on-change between multiple words.
			For that it has to be a get-word with the current syntax.
			And get-word has to be bound, but at the time of macro evaluation it's unbound and can even be in R2.
			Plus, making code compatible with R2 adds a lot of ugly hacky code.
			
		Why not keep validation spec separate from the object's spec?
			Mainly it will be impossible to figure out if they're in sync (unless you love tedious work).
			Keeping them as a single body allows to guarantee it's all kept in sync during refactors.
			It also makes spec more descriptive, adding meaning to each object's word. 
		
		Why single on-change* and multiple on-change funcs?
			In spaces I have a lot of templates based on other templates,
			and to let each template handle it's own words I had to write all the time:
				parent-on-change*: :on-change*
				on-change*: func [...] [
					if find [new words] word [..process new words..]
					call parent-on-change* to process inherited words
				]
			in the end there appears a whole chain of on-change funcs calling each other and a chain of finds
			needless to say this brings about unnecessary load to each assignment.
			Single carefully crafted on-change keeps the overhead from growing with inheritance depth.
			Also single controlled on-change is easy to use for object to class pairing.
			
		Why is class name held inside on-change*?
			If it's held within the object itself, it's much harder to validate /class field itself:
			the `if info: classes/:class/:word` will error out on /class override
			to avoid that I would have to write:
				set-quiet word :old						;) restores class to valid value
				if info: classes/:class/:word [...]		;) check doesn't fail anymore
				set-quiet word :new						;) restores the new value again
			which would double the check time, which is esp. critical for words that don't have checks
			It also can't be held outside the object or object will never be recycled by GC.
			
		Why this syntax?
			I need to balance between readability and conciseness:
			it should be possible to declare word types in the same line of code where word is declared.
			This is the best syntax I have come up with so far.
			Some names I considered:
			  for #type:
				#details #description #desc #meta #info #summary #behavior #operation
				#mode #properties #rule #role #purpose #goal #intent #plan #restrict
			  for more verbosity:
				#equality #tolerance #op #eq (comparison operator)
			    #validity #check #range (value conditions)
			    
		Why having both typed and untyped value checks?
			Without typed value checks, any value's check that supports multiple types becomes unreadable.
			Example: instead of
				x [integer! (x >= 0) pair! (0x0 +<= x) none!]
			I would have to write:
				x [integer! pair! none!] (any [none =? x all [integer? x x >= 0] 0x0 +<= x])
			or  x [integer! pair! none!] (switch type?/word x [none! [yes] integer! [x >= 0] pair! [0x0 +<= x]])
			and it only gets worse as the number of types grows.
			    
		Why on-change has `obj word value` arguments?
			Since all the checks are already made, I don't see a use for `old` value there.
			It may be supported later if this need is proven.
			`obj` argument is required because on-change is a per-class function.
			`word` is required to be able to share single on-change between different words.
		
		Why test for equality?
			I've found riddling my code with `maybe word: expression` instead of simple assignments.
			Later also with `maybe/same word: expression`.
			Because I didn't want to trigger on-change in vain.
			At the same time some of my `on-change*` funcs had their own checks via either `=?` or `==`,
			because I don't wanna risk invalidating the spaces tree if I (or user) forgot `maybe` somewhere.
			This was a disorganized mess with bugs scattered around.
			Equality type declared per word unifies it all and removes the need for `maybe` checks.
			It should also perform better.
			
		Why type specification follows the set-word, not precedes it?
			First implementation used preceding type spec, and it turned out to be way less readable.
			In folowing type spec there's a danger:
				x: 1 + y: 2  #type [integer!]  			;) type applies to y, not x
			But overall it's worth it. Just don't multiple set-words in the same expression, or it will become a mess. 
			 
		Make safety.
			Implementation was designed so that `make` on classy-object creates another *valid* classy-object.
			For that, validity data has to be kept outside, because it's a map and maps are not copied by `make`.
			
		Validation order:
			1. Equality test
			2. Type test
			3. Value test
			4. On-change call
			This ensures that faster tests come first and that on-change is not called on value that will be reset back,
			otherwise it may react to change and leave the object in inconsistent state.
		
		Context of value checks.
			Value check is internally a `function` that gets it's object field as argument.
			So all set-words that appear inside it, stay /local.
		
		Multiple on-change actions per single word, e.g. one per every inherited class?
			Not supported. Would be slower, and I don't see the need in that as worth it.
			Besides, that would need a way to override these, some additional syntax. 
	}
	TODO: {
		- friendlier reflection, esp. how final on-change maps to words
		- maybe #constant or #lock/#locked keyword as alias for #type [] ? (will be set internally by set-quiet)
		  problem is how to initialize smth that supports no assignment, probably it should allow unset->value only
		- #type [block! [subtype!]] kind of check (deep, e.g. block of words)?
		- expose classes by their names so their on-change handlers could be called from inherited handlers
		  useful when overriding one handler with another, and problem arises of keeping them in sync
		- maybe before throwing an error I should print out part of the object where it happened?
		- automated tests suite
	}
]

; #include %debug.red
#include %error-macro.red


context [
	set 'on-change-dispatch function [
		"General on-change function built for object validation"
		class [word!]
		obj   [object!]
		word  [any-word!]
		old   [any-type!]
		new   [any-type!]
	][
		if info: classes/:class/:word [
			;; love these names but this single `set` slows everything down by 15-20%; so using path accessors instead
			;; left as a reminder:  set [equals: types: values: on-change:] info 
			unless info/1 :old :new [
				; word: bind to word! word obj			;@@ bind part fixed early Sept 2022
				word: to word! word						;@@ to word! required for now
				#debug [								;-- disable checks in release ver
					unless find info/2 type? :new [		;-- check type
						set-quiet word :old				;-- in case of error, word must have the old value
						new':   mold/flat/part :new 20
						types': mold to block! info/2
						either empty? types'
							[ERROR "Word (word) is marked constant and cannot be set to (new')"]
							[ERROR "Word (word) can't accept `(new')` of type (mold type? :new), only (types')"]
					]
					unless info/3 :new [				;-- check value
						set-quiet word :old				;-- in case of error, word must have the old value
						new':    mold/flat/part :new 40
						values': mold body-of :info/3
						ERROR "Word (word) can't accept `(new')` value, only (values')"
					]
				]
				info/4 obj word :new
			]
		]
	]
]

classify-object: function [
	"Assign a class to the object"
	class [word!]
	obj   [object!]
][
	call: find body-of :obj/on-change* 'on-change-dispatch
	unless call [ERROR "Object is unfit for classification: (mold/part obj 100)"]
	change next call to lit-word! class
]


classes: make map! 20

context [
	;; used as default equality test, which always fails and allows to trigger on-change even if value is the same
	falsey-compare: func [x [any-type!] y [any-type!]] [no]
	
	;; used as default value check (that always succeeds) - this simplifies and speeds up the check
	truthy-test: func [x [any-type!]] [true]

	extract-value-checks: function [field [set-word!] types [block!] values [word!] /local check words] [
		field: to get-word! field
		typeset: clear []
		options: clear []
		parse types [any [
			copy words some word! (append typeset words)
			opt [
				set check paren! (
					mask: clear []
					foreach type words [				;@@ use map-each
						append mask either datatype? type: get type [type][reduce to block! type]
					]
					append/only append options mask as block! check
				)
			]
		]]
		unless empty? options [
			default: either get values [as block! get values][[true]]
			set values compose/only [switch/default type? (field) (options) (default)]
		]
		make typeset! typeset
	]
	
	set 'modify-class function [
		"Modify a named class"
		class [word!]  "Class name (word)"
		spec  [block!] "Spec block with validity directives"
		/local next-field
	][
		
		unless cmap: classes/:class [
			ERROR "Unknown class (class), defined are: (mold/flat words-of classes)"
		]
		parse spec: copy spec [any [
			remove [#type 0 4 [
				set types block!
			|	set values paren!
			|	ahead word! set op ['== | '= | '=?]
			|	set name [get-word! | get-path!]
			]] p: (new-line p on)
		|	remove [#on-change [set args block! set body block! | set name [get-word! | get-path!]]]
		|	set next-field [set-word! | end] (
				if any [op types values args body name] [		;-- don't include untyped words (for speed)
					unless field [
						ERROR "Type specification found without a preceding set-word at (mold/flat/part spec 70)"
					]
					info: any [cmap/:field cmap/:field: reduce [:falsey-compare  any-type!  :truthy-test  none]]
					if op     [info/1: switch op [= [:equal?] == [:strict-equal?] =? [:same?]]]
					if types  [info/2: extract-value-checks field types 'values]
					if values [info/3: function reduce [to word! field [any-type!]] as block! values]
					if any [body name] [info/4: either name [get name][function args body]]
					set [op: types: values: args: body: name:] none
				]
				field: next-field
			)
		|	skip 
		]]
		spec
	]
	
	set 'declare-class function [
		"Declare a named class (overrides if already exists), return preprocessed spec"
		class       [word! path!]  "Class name (word) or class-name/prototype-name (path)"
		spec        [block!]       "Spec block with validity directives"
		/manual                    "Don't insert classify-object call automatically"
	][
		; if classes/:class [ERROR "Class (class) is already declared"]
		if path? class [
			#assert [parse class [2 word! end]]
			set [class: proto:] class
		]
		classes/:class: either proto [
			unless pmap: classes/:proto [ERROR "Unknown class: (proto)"]
			copy/deep pmap
		][
			make map! 20
		]
		spec: modify-class class spec
		unless manual [
			insert spec compose [
				classify-object (to lit-word! class) self
			]
		]
		spec												;-- spec can be passed to `make` now
	]
]


;; simplest validated object prototype and basic class (needed for classes/:class to be valid)
classy-object!: object declare-class/manual 'classy-object! [
	on-change*: function [word [any-word!] old [any-type!] new [any-type!]] [
		on-change-dispatch 'classy-object! self word :old :new
	]
	classify-object 'classy-object! self
]


; do [
comment [												;; test code
	typed: make classy-object! probe declare-class 'test [
		x: 1		#type == [integer!] (x >= 0)
		s: "str"	#type =? [any-string!] (0 < length? s) 
	]
	
	classify-object 'test typed
	
	; ?? spec
	?? typed
	print mold/all typed
	?? classes
	
	typed/x: 2
	print try [typed/x: "abc"]
	print try [typed/x: -1]
	typed/s: "def"
	print try [typed/s: 1]
	print try [typed/s: ""]
	?? typed

	my-spec: declare-class 'my-class [
		x: 1	#type [integer!] ==
		y: 0%	#type [number! (print "number check!" y >= 0) none!] (print "general check!" yes)
		
		s: "data"
		#on-change [obj val] [print ["changing s to" val]]
		#type == [string!]
		
		zz: 0
	]
	
	my-object1: make classy-object! my-spec
	my-object2: make classy-object! my-spec
	my-other-spec: declare-class 'other-class/my-class [
		u: "unrestricted"
		w: 'some-word	#type [word!]
	]
	my-object3: make my-object2 my-other-spec
	
	my-object1/x: 2
	print try [my-object1/x: 'oops]
	my-object1/y: none
	my-object1/y: 10000
	print try [my-object1/y: -10000]
	
	my-object1/s: "new data"
	my-object1/s: "new data"
	my-object1/s: "New Data"
	?? my-object1
	
	print try [my-object3/w: 1:0]
	print try [unset in my-object3 'w]
	unset in my-object3 'u
	?? my-object3
		
	#include %clock.red
	class: 'test
	o: object [x: 1 on-change*: func [w o n][]]
	clock/times [o/x: 2] 1e7
	clock/times [my-object1/zz: 1] 1e6
	clock/times [my-object1/x: 2] 1e6
	; clock/times [my-object1/y: random 99999] 1e6
	clock/times [o/x: random 99999] 1e6
	clock/times [my-object1/x: random 99999] 1e6
	; clock/times [maybe o/x: 2] 1e6
	m: #(1 2 3 4 5 6 7 8 9 0)
	x: 3
	clock/times [m/:x] 1e7
]
