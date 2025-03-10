Red [
	title:    "Tree visitor pattern"
	purpose:  "Generalize recursive data collection and tree replication"
	author:   @hiiamboris
	license:  BSD-3
	provides: tree-hopping
	depends:  [with without-gc xyloop]
	notes: {
		This is a scaffolding for building tree iterators without the need for recursing.
	
		Usage:
		
		1. Define iteration order over your data by creating a `walker!` object
		
		   For examples see walker implementations in:
			- %glob.red (directory listing: unordered, with depth-control)
			- %tabbing.red (face tree iteration: ordered, from any point on the tree)
			- %parsee.red (data replication: unordered, with uniqueness)
		   
		   A walker! object must define:
		   - a `plan` block! which will contain blocks of code to evaluate at each step
		   - `init` and `stop` functions that will be evaluated before and after the loop
		     they may do nothing, but are meant to take care of walker state cleanup
		   - `branch` function! of single argument that will receive the root node
		     this function fully controls the iteration order by receiving branch nodes,
		     and modifying `plan` to include visits and branches into subnodes
		     it's up to `branch` to decide the order and what to branch into and what to visit
		     since `plan` is currently positioned at the currently evaluated step (block),
		     `branch` should insert new commands after it (`next plan`) when order is required
		     or append them if order is irrelevant and faster operation is required
		   - `visit` function! of two arguments: `node` and `key`
		     meaning of these arguments is up to `branch` to define:
		     for blocks this may be block and index in it, for objects - object and word, for faces - parent and child
		     reason behind separate `key` is to allow `visit` to modify original values where desired
		     this function is given as argument to `foreach-node`, which assigns it to the walker object
		     
		2. Call `foreach-node` with given walker as argument and with a visit function or block
		
		   `foreach-node` simply calls `branch` with the root and then walks over `plan` and evaluates it block by block,
		   expecting `branch` to fill it with new calls.
		   
		   See the source of `foreach-node`, it's really simple to understand.
		   
		   
	   Example walker that visits all faces within the given one, deeply, similar to foreach-face:
		   
			face-walker: make batched-walker! [
				branch: function [parent [object!]] [
					if parent/pane [
						clear batch
						foreach face parent/pane [				;) accumulate next visits in a 'batch'
							repend/only batch [
								'visit parent face
								'branch face
							]
						]
						insert next plan batch					;) multiple visits are 'insert'ed in one go
					]
				]
			]
			>> foreach-node
				layout [panel [base text] group-box [field area]]
				face-walker
				[print [key/type "in" node/type]]
				
			panel in window
			base in panel
			text in panel
			group-box in window
			field in group-box
			area in group-box

		
		On control flow:
		
		- return is trapped inside visitor - will have no effect :/
		- break and break/return work as expected
		- continue works as expected
		- last value returned normally by the walker is ignored (for performance reasons)
		
		
		On design:
		
		The concept has two structural notions:
		- branch node, which represents a source of inner nodes, but not necessarily has to be visited
		- visit node, which has to be visited by a vistor
		This separation allows to visit only the necessary nodes, saving time on unnecessary checks.
		`branch` function direcly decides what branch nodes and what visit nodes each node has.
		For example, if we want to increase the word `counter` of every object in a tree,
		we should define `branch` to only visit such `counter` nodes and no other word nodes.
		
		Implementation makes no assumptions on what constitutes a node or its key - it's `any-type!`.
		Thus walkers able to handle arbitrary data must define arguments of `branch` and `visit` as get-words.
		
		Recursion in meant to be unrolled as it limits possible visit depth to hundreds of levels or so.
		It's not forbidden: `branch` may just call itself on subnodes directly, but then using `foreach-node` is pointless.
		For a practical example, `glob` has to work with up to 32768 depth levels supported by NTFS.
		Red data may also have unlimited nesting and if we want to traverse arbitrary data we shouldn't assume shallowness.
		
		Such unrolling however generally makes the order of iteration ring-like:
		root, then branches of root, then subbranches of branches of root (the case when `append`ing to the `plan`)
		To keep the order one must use `insert`, which has O(length) complexity and limits the scale of such ordered iteration.
		In practice to saturate `insert` one needs either >~10^5 nodes, or very small branch nodes, each performing an insertion.
		When that happens, `plan` can become a linked list.
		However I'd rather see a list! datatype than spawn ad-hoc variants of it built on top of Red.
		
		
		I studied different implementation models of such tree visitor engine:
		
		1. Ideal (simplest) model would be a single `do plan` call, in which `plan` gets extended.
		   Unfortunately it's not supported at all (see #5423).
		   Other drawbacks:
		   - `continue` cannot work properly
		   - only appending is possible as 'current location' in the 'plan' is not exposed
		2. A variant of (1) is do/next-based, a bit slower.
		   Unfortunately, it crashes Red (see #5423).
		   Also `continue` does not skip the current iteration and deadlocks the loop, and is bugged - #5424.
		3. A parse-based model, of similar performance as (2).
		   It works but is not flexible:
		   - to be able to use linked lists in it I have to hardcode the `plan` format
		   - only hardcoded set of keywords is supported
		   To overcome the second limitation, arbitrary code can be inserted as paren, but that brings it closer to (4).
		   First limitation is quite inelegant and cannot be overcome.
		   Even to support recursion depth control useful in `glob` requires certain hacks.
		4. A model where every expression is a block to `do`.
		   With GC - slower than 2-3 by 15% on `append`, without - can be even faster by 5%. But has bigger GC pressure.
		   Faster when using `insert` due to shorter plan, scaling ordered iteration further without linked lists.
		   Generality and simplicity makes it a better choice than (3), despite additional GC load.
		   
		   
		On performance:
		
		My study shows that a lightweight ad-hoc recursion takes about 70% of the time unordered `foreach-node` takes.
		So `foreach-node` should be good for most use cases.
	}
]


; #include %with.red										;-- used in series-walker
; #include %without-gc.red								;-- gives massive speedup
; #include %xyloop.red									;-- for image iteration

;; by default tree walker branches only into any-block, object and map
;@@ make a REP with this typeset? seems useful, also defined in Spaces
;@@ container is defined as a type that we use to hold (unlike error) any kind of values (unlike strings)
container!: make typeset! [any-block! map! object!]
container?: function [
	"Test if value is a container"
	value [any-type!]
][
	find container! type? :value
]
	
walker!: object [										;-- minimal tree walker template
	plan:   []
	init:   does [clear plan]							;-- ensures clean slate (esp. when iteration doesn't finish correctly)
	stop:   does [plan: make [] 128]					;-- used to free (possibly big) series
	branch: func [:node] []
	visit:  func [:node :key] []
]

batched-walker!: make walker! [							;-- GC-smarter basic template
	batch:  []											;-- 'batch' can be used to hold 'plan' changes before insertion
	stop:   does [
		plan:  make [] 128
		batch: make [] 128
	]
]

series-walker!: make batched-walker! [					;-- template that visits all values in all series
	;; NOTE: given a container, visitor MUST return new (or old) container to branch into it
	
	;; avoids deadlocks and double visiting by keeping track of visits
	history: make hash! 128
	filter: unique-filter: func [value [any-type!]] [
		all [
			not find/only/same history :value
			append/only history :value
		]
	]
	
	init: does [
		clear plan
		clear history
	]
	stop: does [
		plan:    make block! 128
		history: make hash!  128
		batch:   make block! 128
	]
	
	;; controls whether iteration is ordered or fast
	; schedule: :append
	schedule: :insert
	
	branch: function [:node [any-type!]] [branch' :node]		;-- entry point requires get-arg
	branch': function [node [any-type!]] compose/deep [			;-- any-type because container! may be replaced
		clear batch
		switch type?/word :node [
			(to [] any-block!) (to [] any-string!) vector! binary!
					[repeat  key length? node [push :node/:key]]
			(to [] any-object!)
					[foreach key keys-of node [push :node/:key]]
			;; while map can be iterated without keys-of, keys will become set-words, which isn't great
			;; also maps are case-sensitive, so without iteration select/case has to be used
			map!	[foreach key keys-of node [push select/case node :key]]
			image!	[xyloop key node [push node/:key]]			;@@ use for-each
			event!	[foreach key system/catalog/accessors/event! [push node/:key]]
		]
		schedule next plan batch
	]
	
	push: func [value [any-type!]] with :branch' [
		repend/only batch
			either all [container? :value filter :value]
				[['branch' 'visit node key]]
				[['visit node key]]
	]
]

make-series-walker: function [types [block! typeset!] /unordered] [
	make series-walker! [
		container!: make typeset! types
		if unordered [schedule: :append]
		bind body-of :push :branch'
	]
]

foreach-node: function [
	"Iterate over the tree starting at root"
	root    [any-type!]        "Starting node"
	walker  [object!]          "A walker! object specifying the manner of iteration"
	visitor [function! block!] "A visitor function [node key] that may read or modify data"
	/extern plan
][
	walker/visit: either block? :visitor [func [:node :key] visitor][:visitor]
	walker/init
	repend/only walker/plan [in walker 'branch :root]	;@@ to visit root will need its address somehow
	also without-gc bind/copy [forall plan [do plan/1]] walker	;-- without copy can't be reentrant
		walker/stop
]
	
