Red [
	title:    "CLASSY-OBJECT! prototype"
	purpose:  "A per-class implementation of object field's type/value checking"
	author:   @hiiamboris
	license:  BSD-3
	provides: classy-object
	depends:  [error count typecheck maybe]				;@@ 'maybe' is only a debug dependency
	notes: {
		This implements objects with automatic:
		- type and value validity checking
		  this allows to put constraints on object's exposed words
		  and limit error propagation as well as provide user friendly error messages
		- laziness towards assignment of equal value
		  this allows to avoid doing extra work when new value equals old
		- separate on-change actor for every word
		  this is meant to simplify on-change and reduce the number of bugs in it
		- embedded documentation and object reflection
		
		Validation patterns are defined once per class and shared between objects of the same class.
		This is done to have the minimum overhead:
		- reduce the RAM requirements that would be high if validation data was unique to each object
		- reduce CPU load by avoiding recreation of validation data on each object creation
	}
	usage: {
	  * Typical usage workflow:
	  
		1. Declare a new named class using DECLARE-CLASS function.
		   It takes an object spec block with class specifiers and returns a MAKE-able spec block without them.
		2. Create as many objects of that class as needed using the obtained MAKE-able spec block.
		
		To demonstrate class declaration:
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
			]											;) my-spec is a block!
		After class is declared, objects can be instantiated:
			my-object1: make classy-object! my-spec
			my-object2: make classy-object! my-spec
			my-other-spec: declare-class 'other-class/my-class [
				u: "unrestricted"
				w: 'some-word  #type [word!]
			]
			my-object3: make my-object2 my-other-spec
		
		
	  * Supported class specifiers are:
	  
		1. Per-field #type which accepts in any order (all are optional):
		   - [block with type/typeset names]
		     by default any-type! is allowed
		     may contain (parens with expressions to test value's validity for ALL preceding types)
		     i.e. x [integer! float! (x >= 0) none!] tests both integer and float
		   - (paren with an expression to test the value's validity)
		     by default all values are accepted
		     applies to all accepted types that do NOT have a type-specific value check (in type block)
		   - equality type: one of [= == =?], which influences whether to call or skip the on-change 
		     by default no equality test is performed and on-change always gets called
		     has no effect if no on-change is assigned to this field
		     tip: `==` is good for scalars and strings, `=?` for blocks
		   - :existing-func-name for on-change handler
		     alias for #on-change :existing-func-name for declaration brevity
		   - "field description string", used only for run-time reflection
		2. Per-field #on-change in one of the forms:
		   - #on-change [obj word new-value] [function body]
		   - #on-change [obj word new-value old-value] [function body]
		   - #on-change :existing-func-name
		   It creates a (or uses an existing) `function` that is called after word's value is changed.
		3. Per-class "description string" may elaborate what this object is used for.
		   Similarly to the functions DSL, description must be the first value in the class spec. 
		   
		Per-field specifiers apply to the first set-word that precedes them.
		
		Multiple specifiers complement each other, so e.g. upper class may define allowed types,
		then descending class may define equality type or on-change handler.
		When the same feature (type check, value check, equality, on-change, docstring) is re-declared, it replaces the old declaration.
		
		
	  * Functions defined in this file are:
		
		- CLASSY-OBJECT function serves as a shortcut to create a *unique* object with type/value checking in it.
		  It's useful (as a replacement of CONTEXT) to type and document unique named objects in the system.
		  Such objects can then be inspected by the users with the SOURCE function.
		
		- CLASSIFY-OBJECT function assigns an object to a given class, enabling validation specific to that class.
		  It can be called at any time, but for more safety should be called before any assignments are made.
		  Normally, CLASSIFY-OBJECT is called automatically from the spec produced by DECLARE-CLASS,
		  so the above MY-SPEC once evaluated will classify itself first, then assign values.
		
		- DECLARE-CLASS <class-name> <spec> function registers a new named object class.
		  A class must be registered before it can be used to instantiate objects.
		  <class-name> can take one of the two forms:
		  1. A path of two words: 'new-class/base-class
		     will copy validation from already declared base-class to the new-class, then process the <spec>.
		  2. A single word: 'new-class
		     will collect validation data from the <spec>, without any inheritance.
		
		- MODIFY-CLASS <class-name> <spec> function is used to make adjustments to an existing class
		  Uses same syntax as DECLARE-CLASS, though set-words do not need any values or expressions in it.
		  Use cases:
		  1. Add on-change handler to a word that's not in the object's spec.
		  2. Adjust a class that was declared elsewhere in another file.
		  
		- CLASS? <object> function returns class name of an object, or `none` if it has no class.
		  It's similar to Red's CLASS-OF, and good for object identification purposes.
		  
		- SOURCE <name> is hijacked (only when it is included from the console help) to add object support.
		  Now <name> accepts objects as well and prints out info about object's class, specifiers, functions and sub-objects. 
		
		
	  * Let's do some tests with the objects declared in the examples above:
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
			
	  * Example of documenting a unique object:
	  
			my-object4: classy-object [
				"A simple object for demonstration purposes"
				
				i: 1		#type [integer!] (i > 0) "Some demo counter"
				s: "abc"	#type [string!]          "Some demo string"
					#on-change [obj word new] [
						print [word "changes to" mold :new]
					]
				f: func [
					"Increase the counter"
					n [integer!] "increase amount"
				][
					i: i + n
				]
				
				self-reference: self
				c: classy-object ["Another demo object"]
			]
		
		Reflection can now be used on it: 
		
			>> source my-object4
			MY-OBJECT4 is an object of class 'unnamed-classy-object-1':
			
			  A simple object for demonstration purposes.
			
			``FIELD``````````  DESCRIPTION``````  EQ  TYPES`````````````  ON-CHANGE``````````````````````````````````````````````` 
			  i:               Some demo counter      [integer!] (i > 0)
			  s:               Some demo string       [string!]           func [obj word new][print [word "changes to" mold :new]] 
			
			``FUNCTION```````  DESCRIPTION`````````  ARGS```````` 
			  f:               Increase the counter  n [integer!] 
			
			``CONTEXT````````  DESCRIPTION```````````````````````````````  WORDS````````````````` 
			  self-reference:  A simple object for demonstration purposes  i s f self-reference c 
			  c:               Another demo object
			
		See also %typed-object.red which is a different (and incompatible) approach to typing an object
	}
	benchmarks: {
		baseline:
		0.25 μs		object/word: value						;) with empty but existing on-change*
		0.98 μs		classy-object/untracked-word: value		;) minimum overhead
		
		change blocked (compared with `maybe` which is simplest function-based approach to equality):
		1.05 μs		maybe object/word: same-value
		1.43 μs		classy-object/tracked-word: same-value	;) overhead of equality test alone
		
		change accepted:
		1.34 μs		maybe object/word: new-value
		2.34 μs		classy-object/tracked-word: new-value	;) with equality test only
		
		change accepted and type/value checks kick in:
		3.04 μs		classy-object/tracked-word: new-value	;) with type test only
		3.30 μs		classy-object/tracked-word: new-value	;) with value test (regardless of other tests present; max overhead)
	}
	limitations: {
		on-change* cannot be redefined or it will break validation
		  use per-value #on-change markers instead
		  if it is redefined, it must include the following call:
			  on-change-dispatch 'class-name word :old :new
		  on-change-dispatch performs the validation
		  classify-object function just changes this <class-name> inside on-change*
		  and relies on the assumption that it's a single token, not an expression
		  
		errors are always reported in on-change-dispatch, can't do nothing about that :(
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
			
		Why is there a unique name assigned to every class?
			It helps to support inheritance. How else to reference the base class if not by name?
			Original class spec could have been used for that, but it's not nearly as convenient.
			Names are also used to test if object belongs to a class of interest.
			On the other hand, names create a possibility of class name clashes, so I may consider the other approach one day. 
			
		Why is class name held inside on-change*?
			If it's held within the object itself, it's much harder to validate /class field itself:
			the `if info: classes/:class/:word` will error out on /class override
			to avoid that I would have to write:
				set-quiet word :old						;) restores class to valid value
				if info: classes/:class/:word [...]		;) check doesn't fail anymore
				set-quiet word :new						;) restores the new value again
			which would double the check time, which is esp. critical for words that don't have checks
			It also can't be held outside the object or object will never be recycled by GC.
			Another reason to hide it is it's intended to set by the object creator, not changed by object's users.
			
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
			    
		Is there a need to access the old value from on-change?
			There is sometimes.
			E.g. I may want `on-change` to internally convert multiple types into one: 1 or 1.0 or 1x1 -> (1,1).
			In this case equality check will always fail e.g. if it's `new 1 = old (1,1)`, and on-change always gets called.
			For on-change to be able to detect that no further change is needed,
			it has to compare converted (1,1) with the old value.
			This example is from Spaces, where it caused constant invalidation when style had a `margin: 1` assignment.
			
		Why on-change has `obj word new old` arguments list?
			Ideally I wanted just `obj word new`, with the old value available as `obj/:word`.
			However that would require me to add two `set-quiet word ...` calls into on-change-dispatch, slowing it down.
			`obj` argument is required because on-change is a per-class function.
			`word` is required to be able to share single on-change between different words.
			`new` is not strictly required, but more convenient to have than `obj/:word`.
			`old` is optional, if it exists in the spec it gets the old value. It is rarely used anyway.
			When `old` follows `new`, support for specs of both arity 3 and 4 is cheap.  
		
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
			 
		Why embed documentation?
			Same reasons we use that in function specs: to shorten the learning curve and help our own memory.
			In projects as big as Spaces this is supposed to be of significant help to developers learning it.
			
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
		- maybe #constant or #lock/#locked keyword as alias for #type [] ? (will be set internally by set-quiet)
		  problem is how to initialize smth that supports no assignment, probably it should allow unset->value only
		  currently the main blocker is that this would slow down the whole implementation
		- #type [block! [subtype!]] kind of check (deep, e.g. block of words)?
		- expose classes by their names so their on-change handlers could be called from inherited handlers
		  useful when overriding one handler with another, and problem arises of keeping them in sync
		- maybe before throwing an error I should print out part of the object where it happened?
		- could class-typing be unified with instance-typing?
	}
]

; #include %debug.red
; #include %assert.red
; #include %with.red
; #include %setters.red
; #include %catchers.red
; #include %error-macro.red
; #include %count.red
; #include %typecheck.red


on-change-dispatch: function [
	"General on-change function built for object validation"
	class [word!]
	word  [any-word!]
	old   [any-type!]
	new   [any-type!]
][
	if info: classes/:class/:word [
		;; love nice names but they add considerable overhead, so calling `info/i` directly
		;; left as a reminder:  set [equals: check: on-change:] info 
		unless info/1 :old :new [
			; word: bind to word! word obj				;@@ bind part fixed early Sept 2022
			word: to word! word							;@@ to word! required for now
			#debug [									;-- disable checks in release ver
				if info/2 :new [
					set-quiet word :old
					do make error! info/2 :new
				]
			]
			info/3 context? word word :new :old
		]
	]
]

classify-object: function [
	"Assign a class to the object"
	obj   [object!]
	class [word!]
][
	;; using 'parse' because during object construction it can change its class many times
	either parse body-of :obj/on-change* ['on-change-dispatch lit-word! 3 word!] [
		; set-quiet in obj 'on-change* :classes/:class/#on-change	;-- shared on-change* helps save RAM - REP #115
		set-quiet in obj 'on-change* select classes/:class #on-change	;-- shared on-change* helps save RAM - REP #115; workaround for #5007 :(
	][
		call: find body-of :obj/on-change* 'on-change-dispatch
		unless call [ERROR "Object is unfit for classification: (mold/part obj 100)"]
		change next call to lit-word! class
	]
]


;; note: implementation of 'class?' is a choice of tradeoffs
;; timings and RAM of try-based and all-based versions are as follows:
;; _________________________________ 
;; |     |  success  |  failure    | 
;; | try | 1.10us 0B | 2.45us 700B | 
;; | all | 1.70us 0B | 0.90us   0B | 
;; |  %  |  ~64%     |  ~270%      | 
;; |_____|___________|_____________| 
;; I find that my code is significantly biased towards successful checks
;; thus I have chosen the try-based implementation here

; class?: function [										;-- class-of is taken already
	; "Determine class of an object"
	; obj     [object!]
	; return: [word! none!] "NONE if not classified"
; ][
	; all [												;-- `try` approach is slower
		; function? select obj 'on-change*				;-- may be unset, have to verify
		; type: select body-of :obj/on-change* 'on-change-dispatch
		; to word! :type
	; ]
; ]

#assert [error? try [to word! none]]					;-- the following 'class?' implementation relies on it

class?: function [										;-- class-of is taken already
	"Determine class of an object"
	obj     [object!]
	return: [word! none!] "NONE if not classified"
][
	try [return to word! select body-of :obj/on-change* 'on-change-dispatch]
	none
]

classes: make map! 20

modify-class: context [
	;; used as default equality test, which always fails and allows to trigger on-change even if value is the same
	falsey-compare: func [x [any-type!] y [any-type!]] [no]
	
	;; used as default value check (that always fails) - this simplifies and speeds up the check
	falsey-test: func [x [any-type!]] [no]

	return function [
		"Modify a named class"
		class [word!]  "Class name (word)"
		spec  [block!] "Spec block with validity directives"
		/local next-field
	][
		unless cmap: classes/:class [
			ERROR "Unknown class (class), defined are: (mold/flat words-of classes)"
		]
		field?: [(unless field [ERROR "A set-word expected before (mold/flat/part p 50)"])]
		parse spec: copy spec [
			opt [remove set desc string! (put cmap #description desc)]
			any [
				remove [p: #type (field?) 0 5 [
					set types block!
				|	set fallback paren!
				|	ahead word! set op ['== | '= | '=?]
				|	set name [get-word! | get-path!]
				|	set doc string!
				]] p: (new-line p on)
			|	remove [p: #on-change (field?) [
					set args block! if (find [3 4] count args any-word!) set body block!
				|	set name [get-word! | get-path!]
				|	(ERROR "Invalid #on-change handler at (mold/flat/part p 50)")
				]]
			|	set next-field [set-word! | end] (
					if any [op types fallback name args body doc] [	;-- don't include untyped words (for speed)
						field: to get-word! field
						info: any [cmap/:field cmap/:field: reduce [:falsey-compare :falsey-test none none none none]]
						if op     [info/1: switch op [= [:equal?] == [:strict-equal?] =? [:same?]]]
						if any [types fallback] [info/2: typechecking/make-check-func field info/4: types info/5: fallback]
						if any [body name] [info/3: either name [get name][function args body]]
						info/6: doc
						set [op: types: fallback: args: body: name: doc:] none
					]
					field: next-field
				)
			|	skip 
			]
		]
		spec
	]
]
	
declare-class: function [
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
	put classes/:class #on-change						;-- issue is used as a key to avoid conflict with possible object words
		func [word [any-word!] old [any-type!] new [any-type!]] compose [
			on-change-dispatch (to lit-word! class) word :old :new
		]
	unless manual [
		insert spec compose [
			classify-object self (to lit-word! class)
		]
	]
	spec												;-- spec can be passed to `make` now
]

classy-object: function [
	"Create a unique object with type/value checking in it"
	spec [block!]
][
	name: ["unnamed-classy-object-" 0]
	name/2: name/2 + 1
	make classy-object! declare-class to word! to string! name spec
]


;; simplest validated object prototype and basic class (needed for classes/:class to be valid)
classy-object!: object declare-class/manual 'classy-object! [
	on-change*: function [word [any-word!] old [any-type!] new [any-type!]] [
		on-change-dispatch 'classy-object! word :old :new
	]
	classify-object self 'classy-object!
]


if function? :source [									;-- only exists if help is included
	context [
		format-columns: function [								;@@ export this?
			"Format text as columns"
			rows    [block!] "Block of blocks, each representing a row"
			/header "Format first row as header"
			/align widths [block!] "Column widths (omit to auto-estimate)"
			return: [string!]
		][
			if empty? rows [return copy {}]
			ncols: length? rows/1
			unless widths [widths: copy []]
			append/dup widths 0 ncols - length? widths
			repeat i ncols [unless integer? widths/:i [widths/:i: 0]]
			foreach row rows [									;-- calculate column widths
				#assert [string? row/:i]
				#assert [ncols = length? row]
				repeat i ncols [widths/:i: max widths/:i length? row/:i]	;@@ use maximum-of with sift
			]
			if header [											;-- format the header
				repeat i ncols [
					rows/1/:i: pad/with uppercase copy rows/1/:i widths/:i #"`"
				]
			]
			output: clear {}
			foreach row rows [									;@@ use map-each
				repeat i ncols [
					pads: widths/:i + 2 - length? row/:i
					append/dup append output row/:i #" " pads
				]
				change back tail output #"^/"
			]
			copy output
		]
		
		class-info: function [
			"Get class information as formatted string"
			class   [word! object!] "Class name or object of that class"
			return: [string! none!] "None if class is not registered"
		][
			if object? class [unless class: class? obj: class [return none]]
			unless cmap: classes/:class [return none]
			
			align: copy [0]
			if obj [											;-- align words column
				funcs: exclude words-of obj [on-change* on-deep-change*]
				remove-each word funcs [not any-function? get/any word]	;@@ use map-each or sift
				
				ctxs: words-of obj
				remove-each word ctxs  [not object? get/any word]	;@@ use map-each
				
				longest: 0
				foreach word compose [(funcs) (ctxs)] [longest: max longest length? form word]	;@@ use map-each
				align: reduce [longest + 3]						;-- "  " prefix and ":" word suffix
				
				if empty? funcs [funcs: none]
				if empty? ctxs  [ctxs: none]
			]
			
			cols: copy/deep [["``FIELD" "DESCRIPTION" "EQ" "TYPES" "ON-CHANGE"]]
			foreach [word info] cmap [							;-- list class fields
				if issue? word [continue]						;@@ remove funcs & objects from this list?
				set [eq: _: on-change: types: fallback: doc:] info
				eq: case [
					:eq =? :equal?        ["="]
					:eq =? :strict-equal? ["=="]
					:eq =? :same?         ["=?"]
				]
				if types [
					types: mold/flat types
					if fallback [repend types [" " mold/flat fallback]]
				]
				if :on-change [on-change: rejoin [mold/flat/part :on-change 70]]
				repend/only cols [
					rejoin ["  " mold word ":"]
					any [doc ""]
					any [eq ""]
					any [types ""]
					any [on-change ""]
				]
			]
			fields: unless single? cols [format-columns/header/align cols align]
			
			if funcs [											;-- list also funcs
				cols: copy/deep [["``FUNCTION" "DESCRIPTION" "ARGS"]]
				foreach word funcs [
					parse spec: copy spec-of get word [opt block! set doc opt string! spec:]
					parse spec [any [remove [string! | [refinement! to end]] | skip]]
					repend/only cols [
						rejoin ["  " mold word ":"]
						any [doc ""]
						mold/only/flat spec
					]
				]
				funcs: format-columns/header/align cols reduce [align/1]
			] 
			
			if ctxs [											;-- list also contexts
				cols: copy/deep [["``CONTEXT" "DESCRIPTION" "WORDS"]]
				foreach word ctxs [
					desc': select select classes class? get word #description
					words: exclude words-of get word [on-change* on-deep-change*]
					repend/only cols [
						rejoin ["  " mold word ":"]
						any [desc' ""]
						mold/only/flat/part words 70
					]
				]
				ctxs: format-columns/header/align cols reduce [align/1]
			] 
			
			all [
				desc: select cmap #description
				not find desc #"^/"
				#"." <> last desc
				append desc #"."
			]
			
			output: copy {}
			case/all [
				desc   [repend output ["^/  " desc "^/^/"]]
				fields [repend output [fields "^/"]]
				funcs  [repend output [funcs "^/"]]
				ctxs   [repend output [ctxs "^/"]]
			]
			output
		]

		body: copy/deep body-of :source
		insert body/case [
			object? :val [
				either all [class: class? val info: class-info val]		;-- pass object to also get info about functions
					[[uppercase mold word "is an object of class" rejoin ["'" class "':^/"] info]]
					[[uppercase mold word "is an unclassified object, so no template info is available."]]
			]
		]
		set 'source function [
			"Print the source of a function or class of an object"
			'word [word! path!] "The name of the function or object"
			/local val
		] body 
	]
]


#debug [#hide [#assert [								;-- checks are disabled without #debug, will fail tests
	none? class? object []
	none? class? object [on-change*: func [w o n] []]
	none? object [on-change*: return class? self]
	
	msg?: func [error] [
		parse error: form error [
			remove thru ["Error: " opt [{"} | "{"]] to [opt ["}" | {"}] "^/"] remove to end
		]
		error
	]
	typed: make classy-object! declare-class 'test-class-1 [
		x: 1		#type == [integer!] (x >= 0)
		s: "str"	#type =? [any-string!] (0 < length? s) 
	]
	classify-object typed 'test-class-1
	'test-class-1 = class? typed
	
	typed/x: 2
	typed/x = 2
	error? try [typed/x: "abc"]
	error? try [typed/x: -1]
	typed/x = 2
	
	typed/s: "def"
	typed/s = "def"
	error? try [typed/s: 1]
	error? try [typed/s: ""]
	typed/s = "def"
	
	var: 0
	my-spec: declare-class 'test-class-2 [
		x: 1	#type [integer!] ==
		y: 0%	#type [number! (y >= 0) none!] (none? y)
		
		s: "data"
		#on-change [obj word val] [var: val]
		#type == [string!]
	]
	
	my-object1: make classy-object! my-spec
	my-object2: make classy-object! my-spec
	my-other-spec: declare-class 'test-class-3/test-class-2 [
		u: "unrestricted"
		w: 'some-word	#type [word!]
		m: none			#type [integer! float! (m = 1) word! ('word = m) none! logic!] (none? m)
	]
	my-object3: make my-object2 my-other-spec
	
	my-object1/x: 2
	my-object1/x = 2
	error? err: try [my-object1/x: 'oops]
	"Word x can't accept word value: oops, only [integer!]" = msg? err
	my-object1/x = 2
	
	none? my-object1/y: none
	my-object1/y = none
	
	my-object1/y: 10000
	my-object1/y = 10000
	error? err: try [my-object1/y: -10000]
	"Failed (y >= 0) for integer value: -10000" = msg? err
	my-object1/y = 10000
	
	my-object1/s: "new data"
	my-object1/s == "new data"
	my-object1/s: "new data"
	my-object1/s: "New Data"
	my-object1/s == "New Data"
	
	my-object2/s: "new data"
	my-object2/s == "new data"
	my-object2/s: "new data"
	my-object2/s: "New Data"
	my-object2/s == "New Data"
	
	error? err: try [my-object3/w: 1:0]
	"Word w can't accept time value: 1:00:00, only [word!]" = msg? err
	error? err: try [unset in my-object3 'w]
	"Word w can't accept unset value: unset, only [word!]" = msg? err
	:my-object3/w = 'some-word
	
	;; error messages test in mixed checks scenario:
	my-object3/m: 1
	my-object3/m == 1
	my-object3/m: 1.0
	my-object3/m == 1.0
	error? err: try [my-object3/m: 2.0]
	"Failed (m = 1) for float value: 2.0" = msg? err
	my-object3/m == 1.0
	
	my-object3/m: 'Word
	my-object3/m == 'Word
	error? err: try [my-object3/m: 'other]
	"Failed ('word = m) for word value: other" = msg? err
	my-object3/m == 'Word
	error? err: try [my-object3/m: off]
	"Failed (none? m) for logic value: false" = msg? err
	my-object3/m == 'Word
	
	unset in my-object3 'u
	unset? :my-object3/u
	
	; do [
	comment [												;; benchmarks
		#include %clock.red
		my-spec: declare-class 'test-class-2 [
			a: 1
			b: 1	#type ==
			c: 1	#type [integer!]
			d: 1	#type (d >= 0)
			e: 1	#type == [integer! (e >= 0)]
		]
		cobj: make classy-object! my-spec
		o: object [x: 1 on-change*: func [w o n][]]
		x: 1
		clock/times [99999] 1e7
		clock/times [random 99999] 1e7					;-- overhead of random itself over constant
		clock/times [x >= 0] 1e7						;-- overhead of condition itself
		clock/times [maybe o/x: 1] 1e6					;-- overhead of maybe
		clock/times [maybe o/x: random 99999] 1e6		;-- overhead of maybe (new)
		clock/times [o/x: random 99999] 1e6				;-- setting of normal tracked object
		clock/times [cobj/a: 1] 1e6						;-- overhead of unchecked field in classy object
		clock/times [cobj/b: 1] 1e6						;-- overhead of caching
		clock/times [cobj/b: random 99999] 1e6			;-- overhead of equality test
		clock/times [cobj/c: 1] 1e6						;-- overhead of type test
		clock/times [cobj/d: 1] 1e6						;-- overhead of condition
		clock/times [cobj/e: random 99999] 1e6			;-- overhead of everything
	]

	remove/key classes 'test-class-1					;-- cleanup
	remove/key classes 'test-class-2
	remove/key classes 'test-class-3
]]];; #debug [#hide [#assert []]]

