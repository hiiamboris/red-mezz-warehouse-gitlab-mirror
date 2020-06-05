Red [
	title:   "TABLE style"
	purpose: "Renders data as a table, until such style is available out of the box"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		This is work in progress, and mainly an experiment!

		DESIGN

		Goal of this implementation is not speed, it's flexibility and reuse of `face!` functionality.
		50 rows - easy, 50000 - madness.

		Should table consist of columns or rows?
		Columns give natural resize of them, natural definition in VID (e.g. giving names to columns).
		Rows give natural row height balancing and also possibility to resize rows, simpler sorting.
		I chose columns; rows are auto-sized.
		Rows are also unnamed, so table is CSV-like, fit for listing objects, blocks, etc.

		Be careful when making cells editable and mapping them to global words: `data: 'none` will change global `none`!
	}
	todo: {
		* design wiki!
		* renderers should report minimum size, but try to otherwise occupy the whole cell
		  only then we'll be able to both infer row heights and make `field`s the height of the row
		* use spacing between rows
		* columns manual resize and dragging around (too many bugs in View to attempt this now)
		* reverse sorting
	  	* user-defined actors
		* provide a block renderer that would arrange multiple values in a cell (e.g. image + text)
		* ability to overload 'cell' style to implement the whole table in draw?
	  	  it will be a virtual deep reactor that reflects everything on a canvas
	  	  not sure how View will handle panes with fake faces...
		* how to support multi-row/multi-column spanning faces?
		  I have no need of that though, and that will rule out panels usage as they clip content

	}
]

recycle/off

#include %setters.red
#include %keep-type.red
#include %map-each.red
#include %extremi.red
#include %clock.red
#include %clock-each.red
#include %do-unseen.red
#include %show-trace.red
; #include %../red-view-test/elasticity.red
do https://gitlab.com/hiiamboris/red-elastic-ui/-/raw/master/elasticity.red
#include %scrollpanel.red
#include %reshape.red
#include %relativity.red

; #include %"/d/devel/red/red-src/red/environment/reactivity.red"

by: make op! :as-pair

{
	Geometry event flow:

	cell/size <=> canvas/size : user may change the cell size to affect canvas, but canvas when rendered may change cell size
		text canvas respects cell width, but adapts it's height
		image canvas sets both width and height of the cell
		this way one can set column width and it will make all cells fit the column exactly
		canvas height still can be smaller than cell height if some adjacent cell has bigger height
	cell/size/y <= max height of it's canvas and adjacent cells : rows have to be balanced
		this is hard...
			both cell and column can be used alone - without table
			in this case cells freely dictate their heights
			but when used within a table, they have to adjust row height
			still we have to provide O(1) row height inquiries, and worst case O(n) resize (as all rows below have to be repositioned)
			crazy idea: resize can be faster (?) if column is recursive: cell and a panel with cell and a panel also.. and so on...
			(more likely it will destroy View totally ;)
		one way: let cells make requests to the table about row height
			but then, the amount of requests per row(!) = number-of-columns ** 2, which is a lot (each has to query each)
			and when each next cell is taller than the previous, this echoes back (number-of-columns ** 2) / 2 resizes
		so way two: probably better: let columns lay out their cells
			then cell heights are adjusted in an atomic operation by the table (full text rows won't even need any adjustment)
			then columns with changes are re-rendered
			then a show operation is casted once on the whole table
		how to make table delay re-rendering until all cells are set? and at the same be able to react to single updates?
			easiest thing that comes to my mind is a queue flushed by timer
			for that, cell will try to find and call a table's callback that fills the queue
			on timer: table will change (atomically) cell (row) heights, and columns will process a bunch of events each
			+ same idea for column height auto inferrence (cell reports to column, column to table)

	cell/size/x <= column/size/x : text cells adapt to column width
		image (or custom) cells may set custom width but column doesn't care (for ease of column resizing)
	column/extent : auto determined sum of all cells arranged vertically
	column/extent/y => column/size/y : by default, automatically expands/contracts column height to fit it's contents
	column/extent/x <= max of cell/size/x : usually total width is that of cells, which often equals column width
	column/size/x is static and does not depend on cell width (although controlled by the table)
		otherwise it's impossible: cell data can be huge, and column width cannot auto-resize with it
		one may simply define a reaction: column/extent/x => column/size/x when this is required

	table/extent : auto determined sum of all columns arranged horizontally
	table/extent/y <= max of column/size/y = max of column/extent/y
	table/extent/x <= sum of column/size/x
	table/size/x <= table/extent/x : by default, table adjusts it's width to columns within it
	table/size/x => each column/size/x => each column/extent/x => each cell/size/x
		this works both ways:
		user can change column widths and table width will change
		user can change table width and it will stretch all columns proportionally
	table/size/y <= table/extent/y : automatic
	TIP: put table into a scrollable panel to contain it if it's big!

	sorting: triggered by column click, but makes no sense in a separate column (?)
	either we hook table to each column's pane, and then user can also reorder cells
	(but will be hard to track those movements)
	or we let table to do the sorting, and it takes care of all columns on it's route
}

; system/reactivity/debug?: 'full
; system/view/debug?: yes
table: context [
	profile?: yes
	debug?:   yes
	~colors: system/view/metrics/colors

	clock-each: either profile? [:system/words/clock-each][:do]
	clock:      either profile? [:system/words/clock]     [:do]
	report:     either debug? [:print] [:comment]

	;; `compose` readability helper
	when: make op! func [value test] [either :test [:value][[]]]

	~cell: cell: context [
		default-image-height: 40

		zoom-factor?: function [
			"Determine the maximum zoom factor that allows to fit SRC-SIZE within DST-SIZE"
			src-size [pair!] dst-size [pair!]
		][
			min 1.0 * dst-size/x / max 1 src-size/x			;-- use the narrowest dimension
				1.0 * dst-size/y / max 1 src-size/y
		]

		default-renderer: function [cell [object!] canvas [object!] value [any-type!]] [
			maybe canvas/image: none
			maybe canvas/text:  mold/flat/part :value to integer! cell/size/x / 4		;-- 4 pixels per char limit
			maybe canvas/size:  cell/size/x by 25
		]
		
		string-renderer: function [cell [object!] canvas [object!] string [string!]] [
			maybe canvas/image: none
			maybe canvas/text:  either 'base = canvas/type [
				copy/part string to integer! cell/size/x / 4		;-- 4 pixels per char limit
			][	string												;-- expose string directly into field
			]
			maybe canvas/size:  cell/size/x by 25
		]
		
		number-renderer: function [cell [object!] canvas [object!] number [number!]] [
			maybe canvas/image: none
			maybe canvas/text:  mold number
			maybe canvas/size:  cell/size/x by 25
		]
		
		image-renderer: function [cell [object!] canvas [object!] image [image!]] [
			maybe canvas/text:  form image/size
			maybe canvas/image: image
			maybe canvas/size:  image/size * zoom-factor? image/size max 40x40 cell/size
		]

		spec-renderer: function [cell [object!] canvas [object!] fun [any-function!]] [
			maybe canvas/image: none
			maybe canvas/text:  mold/flat keep-type spec-of :fun any-word!
			maybe canvas/size:  cell/size/x by 25
		]

		keys-renderer: function [cell [object!] canvas [object!] obj [any-object! map!]] [
			maybe canvas/image: none
			maybe canvas/text:  mold/flat/part words-of obj to integer! cell/size/x / 4		;-- 4 pixels per char limit
			maybe canvas/size:  cell/size/x by 25
		]

		renderers: make map! reduce [
			'default   :default-renderer
			'string!   :string-renderer
			'integer!  :number-renderer
			'float!    :number-renderer
			'percent!  :number-renderer
			'image!    :image-renderer
			'function! :spec-renderer
			'native!   :spec-renderer
			'action!   :spec-renderer
			'op!       :spec-renderer
			'object!   :keys-renderer
			'error!    :keys-renderer
			'port!     :keys-renderer
			'map!      :keys-renderer
		]

		editable!: make typeset! [string! number!]
		
		default-canvas-provider: function [cell [object!]] [
			value: get-value :cell/data
			read-only?: to logic! any [
				cell/read-only?
				not find editable! type? :value
			]
			
			type: pick [base field] read-only?
			either any [
				empty? cell/pane
				cell/pane/1/type <> type
			][
				canvas: make face! compose/deep [
					(system/view/VID/styles/:type/template)
					offset: 0x0
					color: (any [cell/color ~colors/panel white])
					size: (cell/size)
					font: (either object? cell/font [copy cell/font][cell/font])
					para: (any [cell/para  make para! [align: 'left]])
				]
				if type = 'field [
					canvas/actors: make object! [
						on-change: func [fa ev] [push-value fa/parent fa/text]
					]
				]
				cell/pane: reduce [canvas]
			][
				canvas: cell/pane/1
			]

			if renderer: any [
				select cell/renderers type?/word :value
				:cell/renderers/default
			][
				;; cell might not have a parent, yet it should be able to stretch to parent (column) width
				;; so first I'm setting it width to column width, then it may render canvas with the knowledge of cell width
				if column: cell/parent [maybe cell/size/x: column/size/x]
				renderer cell canvas :value
				if all [								;-- report size change to parent
					cell/size/y <> canvas/size/y		;-- do not report cells which size didn't change!
					column
					function? on-resize: select column 'on-cell-resize
				][
					report ["SCHEDULING ROW CHECK FOR A CELL AT" cell/offset]
					on-resize cell
				]
			]
		]

		renew-canvas: func [cell [object!]] [
			cell/canvas-provider cell
		]

		;; force redraw of cell content when the data changed
		;;  e.g. if we bind to a word and it's value changes, or we map to a block and it's first value changes
		;;  otherwise we have no way to know
		;;  maybe in addition to it, some tracking mechanism can be invented?
		update: func [cell [object!]] [
			cell/data: cell/data
		]

		;@@ BUG: when changing cell size it's required to call renew-canvas manually or call `update` (see REP #77)
		change-hook: function [cell word old [any-type!] new [any-type!]] [
			; print ["change-hook" word :old :new]
			unless action: select/skip [				;-- these are ordered in predicted update frequency order
; size [] 								;-- can't react to size! flush changes size -> we call renew -> renew calls flush -> idiocy
				data [] read-only? []					;-- these warrant a canvas check & re-render  @@ TODO: don't react to size/y - how?
				text  [set-to cell :new  exit]			;-- exit because it will re-enter with `data` facet changed
				color [maybe child/color: :new]
				font  [maybe child/font:  either object? :new [copy :new][:new]]
				;@@ any other facets to transfer?
				; font [print ["change-hook" word :old :new]]
			] word 2 [exit]
			renew-canvas cell
			child: cell/pane/1
			do action
		]
		
		deep-change-hook: function [cell word target action new [any-type!] index part] [
			; print ["deep-change-hook" word target :new :action :index :part]
			change-hook cell word none :new
		]

		;@@ TODO: also an evaluating version??
		get-value: func [data [any-type!]] [
			switch/default type?/word :data [
				block! paren! [:data/1]
				word! path! get-word! [get/any data]
				get-path! [get/any as path! data]				;@@ workaround for #4448
			][	:data
			]
		]

		push-value: func [cell [object!] value [any-type!] /local data] [
			set/any 'data cell/data
			switch type?/word :data [
				block! [change/only data to :data/1 :value]
				word! path! get-word! get-path! [
					if get-path? data [data: as path! data]		;@@ workaround for #4448
					attempt [set data to get/any data :value]	;-- attempt for validation
				]
			]
		]

		bind-to: func [cell [object!] target [word! path! get-word! get-path!]] [
			unless :cell/data =? target [cell/data: target]
		]

		map-to: func [cell [object!] target [block!]] [
			unless :cell/data =? target [cell/data: target]
		]

		;; has to guarantee that the value, when changed, will not have repercussions outside
		;; that's why it's using parens - to distinguish from blocks used by map-to
		set-to: func [cell [object!] value [any-type!]] [
			;; this check is hard, as what if value is a huge block?
			;; and same huge block is already in cell/data?
			;; need to tread with care...
			;; still it's worth doing to avoid triggering reactivity
			;@@ TODO: maybe use non-block values as is, without `reduce`?
			unless all [
				yes = try [:value =? :cell/data/1]
				paren? :cell/data
			] [cell/data: as paren! reduce [:value]]
		]

		;; optimization - this is even faster than inlining the whole thing into template (why? makes template shorter?)
		on-change-template: compose [
			change-hook self word :old :new
			(body-of :face!/on-change*)
		]

		extend system/view/VID/styles compose/deep [
			cell: [
				default-actor: 'on-down					;-- e.g. for actions, highlighting
				template: [
					type:  'panel
					size:  100x25
					color: (any [~colors/panel white])

					value:            does [get-value :data]		;-- needed for sort
					read-only?:       yes
					canvas-provider: :default-canvas-provider
					renderers:       :cell/renderers

					;; reactivity is unbelievably slow (at least for now), so have to use hooks:
					on-change*:      function spec-of :face!/on-change* [(on-change-template)]
					                          ; bind/copy on-change-template self		;@@ faster but BUGGY: see #4500
					on-deep-change*: function spec-of :face!/on-deep-change* [
						deep-change-hook     owner word target action :new index part
						on-face-deep-change* owner word target action :new index part state no
					]
				]
			]
		]
	];; ~cell: cell: context [


	~column: column: context [
		;; used to preallocate a bulk of cells for mapping them later
		;; length = 0 includes header, length = 1 is header + cell, etc.
		set-length: function [column [object!] len [integer!] /local i] [
			#assert [len >= 0]
			more: 1 + len - length? pane: column/pane			;-- `1` for the header
			case [
				more < 0 [clear skip pane 1 + len]
				more > 0 [loop more [append pane make-face 'cell]]				;@@ what's fastest here?
				; more > 0 [append pane collect [loop more [keep make-face 'cell]]]
				; more > 0 [append pane map-each i more [make-face 'cell]]
			]
		]

		rename: function [column [object!] title [any-type!]] [
			unless empty? column/pane [~cell/set-to column/header :title]
		]

		;@@ TODO: update it in one go, else too many events
		assign: function [method [word!] column [object!] data [block!]] [
		do-atomic [do-unseen [clock-each [
			set-length column len: length? data
			pane: next column/pane
			action: select/skip [
				set  [~cell/set-to  pane/:i :data/:i]
				bind [~cell/bind-to pane/:i :data/:i]
				map  [~cell/map-to  pane/:i at data i]
			] method 2
			repeat i len action
			autosize column
		]]]
		]

		;; creates a 2-way binding between words and column
		bind-to: function [column [object!] words [block!]] [
			assign 'bind column words
		]

		;; creates a 2-way binding between data block and column
		map-to: function [column [object!] data [block!]] [
			assign 'map column data
		]

		;; fills column with values from the data block
		set-to: function [column [object!] data [block!]] [
			assign 'set column data
		]

		;; call it after chaning the mapped-to/bound-to data, to force redraw
		update: function [column [object!]] [
			do-atomic [foreach cell column/pane [~cell/update cell]]
		]

		;; index=1 starts from the header, index=2 - from the 1st cell after the header
		autosize: function [column [object!] /from index [integer!]] [
			report "COLUMN AUTOSIZE"
			clock [do-unseen [
; clear column/queue							;-- clean pending updates - before calling ~cell/update!
				pos: 0x2									;-- 2px upper margin
				;@@ BUG: with `/from` we cannot reliably calculate the width, so we shouldn't udpate it
				pane: column/pane
				if from [
					pane: at pane index
					pos: pane/1/offset
				]
				foreach cell pane [
					maybe cell/offset: pos * 0x1
					;; cell sets it's width automatically from column width (or doesn't, depends on renderer)
					if cell/size/x <> column/size/x	[
						cell/size/x: column/size/x			;@@ affected by bug #4454 -- don't use from `init`
						~cell/update cell					;@@ required, see REP #77
					]
					; maybe cell/size/x: column/size/x		;@@ affected by bug #4454 -- don't use from `init`
					; maybe cell/size: as-pair column/size/x cell/size/y		;@@ workaround
					pos/x: max pos/x cell/size/x
					pos/y: pos/y + cell/size/y + 1			;-- 1 for spacing
				]
				either from [
					maybe column/extent/y: pos/y
				][	maybe column/extent:   pos
				]
				maybe column/size/y: pos/y					;-- auto adjust height only
			]]
		]

		flush: function [column [object!]] [
			;; there are 2 scenarios here:
			;;  - column inside a table: then we let table handle cell size update (this is the most efficient way)
			;;  - column is standalone: then it handles it all on it's own
			unless all [								;-- table will handle it
				table: select column 'parent
				yes =  select table 'balance-rows?
			][											;-- column has to handle it
				do-unseen [
					first: length? pane: column/pane
					foreach cell column/queue [
						first: min first index? find/same pane cell
						maybe cell/size/y: cell/pane/1/size/y
					]
					autosize/from column first
					; attempt [show column]
				]
			]
		]

		on-header-down: function [fa ev] [
			if all [
				column: fa/parent
				table: column/parent
				function? sort: select table 'sort-by
			][
				sort column
				show table
			]
		]

		extend system/view/VID/styles reshape [
			;@@ TODO: add resizing of columns into the table
			column: [
				template: [
					type:   'panel
					pane:   []
					color:  !(any [~colors/text black])
					size:   100x400
					text:   "Header"
					rate:   8
					actors: [on-time: func [fa ev] [flush fa]]

					extent: 0x0
					queue:  []
					header: make-face/spec 'cell compose [
						bold with [read-only?: yes]									;-- bold font for the header and always readonly
						(color * 0.3 + !(0.7 * any [~colors/panel white]))			;-- give it's background a slight tint of the text color
						on-down :on-header-down
					]
					insert pane header													;-- insert preserves user-defined pane
					on-cell-resize: function [cell [object!]] [append queue cell]		;-- exposed to be user-controllable

					react [rename self self/text]										;-- text facet controls the header
					react [if block? data [set-to self self/data]]		;@@ TODO: use on-deep-change? otherwise a single deep change triggers full column reset
					react/later [[self/pane self/size/x] autosize self]
					; autosize self
				]
			]
		]
	];; ~column: column: context [


	set-width: function [table [object!] width [integer!]] [
		more: width - length? table/pane
		case [
			more < 0 [clear skip table/pane width]
			more > 0 [loop more [append table/pane make-face 'column]]
		]
		; table/pane: table/pane
	]

	resize: function [table [object!] size [pair!]] [
		do-unseen [clock-each [
			set-width table size/x
			foreach column table/pane [~column/set-length column size/y]
		; attempt [show table]
		]]
	]

	;; to be called on column resize only
	autosize: function [table [object!]] [
		report "SETTING UP COLUMNS & RESIZING TABLE"
		do-unseen [clock [
			pos: 1x0 * table/spacing
			foreach column table/pane [
				maybe column/offset: pos * 1x0
				report ["COLUMN" index? find/same table/pane column "AT" column/offset]
				pos/x: pos/x + column/size/x + table/spacing/x
				pos/y: max pos/y column/size/y
			]
			maybe table/extent: pos
			; ? pos
			table/shares: map-each column table/pane [100% * column/size/x / pos/x]
			report ["SHARES" mold table/shares]
			report ["NEW SIZE" pos]
			maybe table/size: pos
			; attempt [show table]
		]]
	]

	;; to be called on table resize only
	;; table/size/x -> column/size/x + table/extent/x
	adjust-width: function [table [object!] /force] [
		report "ADJUSTING COLUMNS WIDTHS"
		; ???
		all [not force  2 > absolute table/size/x - table/extent/x  exit]		;-- don't react to minor resizes
		do-unseen [clock [
			ncol: length? table/pane
			pos: 1x0 * table/spacing
			used: table/size/x - (ncol + 1 * table/spacing/x)
			total: sum table/shares
			for-each [/i column] table/pane [
			; ???
				maybe column/offset: pos
				; maybe column/size/x: to integer! column/size/x * factor	;@@ BUG: this will have issues due to rounding! TODO: save original column widths
				width: to integer! used * table/shares/:i / total
				; if i = length? table/pane [width: table/size/x - table/spacing/x - pos/x]
				report ["COLUMN" i "WIDTH" width]
				maybe column/size/x: width
				pos/x: pos/x + column/size/x + table/spacing/x
			]
			; if pos/x <> table/size/x [print ["======WTFFFFFFFFFFFFFFF======" pos/x table/size/x]]
			maybe table/extent/x: pos/x
			; attempt [show table]
		]]
	]

	;@@ TODO: probably inefficient to do by-column updates; make a by-row algorithm
	update: function [
		"Update table contents with the data it maps to"
		table [object!]
	][
		report "TABLE UPDATE"
		foreach column table/pane [~column/update column]
	]

	; balance-rows: function [table [object!] /from first [integer!] offset [pair!]] [
	; do-unseen [clock [
	; 	row: any [first 1]
	; 	pos: any [offset 0x0]
	; 	report ["BALANCING ROWS FROM" row]
	; 	columns: table/pane
	; 	forever [
	; 		height: 0
	; 		ncol: 0
	; 		repeat col length? columns [
	; 			cell: columns/:col/pane/:row
	; 			if cell [
	; 				ncol: ncol + 1						;-- count the number of columns that extend this far
	; 				maybe cell/offset: pos
	; 				height: max height cell/size/y
	; 			]
	; 		]
	; 													;@@ TODO: with 1 = ncol delegate the resize to that column
	; 		if 0 = ncol [break]							;-- reached the end of table
			
	; 		repeat col length? columns [
	; 			cell: columns/:col/pane/:row
	; 			report ["RESIZING CELL" col by row "TO" height]
	; 			; cell/size: cell/size/x by height
	; 			cell/size/y: height
	; 			; ?? cell/size
	; 		]
	; 		pos/y: pos/y + height + 1					;-- 1 for spacing
	; 		row: row + 1
	; 	]
		
	; 	repeat col length? columns [
	; 		maybe columns/:col/extent/y: pos/y
	; 		maybe columns/:col/size/y: pos/y
	; 		clear columns/:col/queue					;-- clear pending updates
	; 	]

	; 	; show table
	; ]]
	; ]

	get-row: function [table [object!] row [integer!] into [block!]] [
		clear into
		foreach column table/pane [append into any [column/pane/:row []]]
		into
	]

	;; resizes all rows according to all queued updates
	;;@@ BUG: does not change column & table widths (cannot be reliably known without iterating thru each cell)
	flush: function [table [object!] /force] [
		columns: table/pane

		rows: either force [
			maximum-of map-each c columns [length? c/pane]
		][
			sort unique map-each column columns [
				map-each cell column/queue [index? find/same column/pane cell]		;@@ BUG: this is slow for big updates! optimize somehow
			]
		]
		buf: copy []
		do-unseen [
			for-each row rows [
				row: get-row table row buf
				; height: maximum-of map-each cell row [cell/pane/1/size/y]
				height: 0  foreach cell row [height: max height cell/pane/1/size/y]
				foreach cell row [
					if cell/size/y <> height [
						modified?: yes
						cell/size/y: height
					]
				]
			]
			if modified? [
				foreach column columns [~column/autosize column]
				; autosize table							;-- expand/contract the table height  ;@@ BUG: disables scrolling wtf
				; attempt [show table]
			]
		]
	]

	map-object-to-table: function [
		"Prepare TABLE layout and create a mapping between TABLE and OBJ"
		table [object!] obj [object!]
		/index "Add index column"
		/types "Add type column"
		/names "Override column headers"
			headers [block!]
		/local i w title share
	][
		report ["MAPPING to" mold/part obj 100]
		clock-each [
			ncol: pick pick [[4 3] [3 2]] index = on types = on			;-- how many columns will we have
			resize table ncol by len: length? words: words-of obj
			columns: table/pane
			used: 1.0 * table/size/x - (ncol + 1 * table/spacing/x) / table/size/x		;-- x space occupied by columns
			shares: compose [(10% when index) 20% (20% when types) 50%]
			total: sum shares
			table/shares: map-each share shares [share / total * used]
			adjust-width/force table									;-- resize columns before changing cells data! (cells will adapt to columns)
			headers: any [headers  compose [("#" when index) "Field" ("Type" when types) "Value"]]
			for-each [/i title] headers [columns/:i/text: title]
			if index [
				~column/map-to columns/1 map-each i len [i]
				columns: next columns
			]
			~column/map-to columns/1 words
			if types [~column/map-to columns/2 map-each w words [type?/word get/any w]]
			~column/bind-to last columns words
			; autosize table
		]
	]

	map-block-to-table: function [
		"Prepare TABLE layout and create a mapping between TABLE and BLOCK"
		table [object!] block [block!]
		/skip  "Put more than one item per row"
			period [integer!] "Block period (default: 1)"
		/index "Add index column(s)"
		/types "Add type column(s)"
		/names "Override column headers"
			headers [block!]
		/local i v title share i-col t-col v-col
	][
		period: any [period 1]
		#assert [period >= 1]
		report ["MAPPING to" mold/part block 100]
		clock-each [
			group: pick pick [[3 2] [2 1]] index = on types = on		;-- how many columns will we have per skip
			ncol: group * period										;-- total columns
			len: length? block
			height: to integer! len + period - 1 / period
			resize table ncol by (height + 1)							;-- +1 for headers
			columns: table/pane
			used: 1.0 * table/size/x - (ncol + 1 * table/spacing/x) / table/size/x		;-- x space occupied by columns
			shares: compose [(15% when index) (30% when types) 55%]
			total: sum shares
			table/shares: map-each share shares [share / total / group * used]
			adjust-width/force table									;-- resize columns before changing cells data! (cells will adapt to columns)
			headers: any [headers  compose [("#" when index) ("Type" when types) "Value"]]
			for-each [/i column] columns [column/text: pick headers i - 1 % group + 1]
			spec: compose [/i ('i-col when index) ('t-col when types) v-col]
			if index [indexes: map-each i len [i]]
			if types [types:   map-each v block [type?/word :v]]
			for-each (spec) columns [
				offset: (to integer! i - 1 / group) * height + 1
				if index [~column/map-to i-col at indexes offset]
				if types [~column/map-to t-col at types   offset]
				~column/map-to v-col at block offset
			]
			; autosize table
		]
	]

	default-mapper: function [table [object!] data [default!]] [
		switch type?/word :data [
			block!  [map-block-to-table/index/types  table data]
			object! [map-object-to-table/index/types table data]
			;@@ can more types be mapped?
		]
	]

	mappers: make map! reduce [
		'default   :default-mapper
		'block!    :default-mapper
		'object!   :default-mapper
	]

	map-to: function [table [object!] data [default!]] [
		if mapper: any [
			select table/mappers type?/word :data
			:table/mappers/default
		][
			mapper table data
			flush/force table
			; balance-rows table
		]
	]

	image-cmp: func [a b] [				;@@ workaround for #4502
		any [
			a/size < b/size
			all [
				a/size == b/size
				a/argb <= b/argb
			]
		]
	]

	;@@ TODO: reverse sorting
	sort-by: function [table [object!] column [object! integer!] /local i c v1 v2] [
		report "SORTING TABLE"
		columns: table/pane
		either integer? icol: column [
			column: columns/:column
		][	icol: index? find/same columns column
		]
		cells: next column/pane							;-- `next` to exclude the header
		indexes: map-each i length? cells [i]
		values: map-each c cells [c/value]

		buf: [- -]
		;@@ BUG: THIS CRASHES; use it when #4489 gets fixed
		; sort/stable/compare indexes func [a b] [
		; 	buf1/1: :values/:a  buf2/1: :values/:b		;-- we're sorting generic unknown data, so `<` doesn't work here
		; 	buf1 <= buf2
		; ]
		; clear buf1

		;@@ temporary bubble sort workaround
		len: -1 + length? cells
		until [
			sorted?: yes
			s: next indexes
			forall s [
				change/only change/only buf	
					set/any 'v1 pick values s/-1
					set/any 'v2 pick values s/1
				either all [image? :v1 image? :v2] [
					;@@ workaround for #4502
					sort/compare buf :image-cmp
				][
					sort buf							;-- we're sorting generic unknown data, so `<` doesn't work here
				]
				unless :buf/1 =? :v1 [
					sorted?: no
					move back s s
					; insert/only back s take s
				]
			]
			sorted?
		]

		;; rearrange all columns
		do-unseen [do-atomic [
			foreach col columns [
				cells: head clear next copy col/pane
				; foreach i indexes [append cells pick col/pane i + 1]
				append cells map-each i indexes [pick col/pane i + 1]
				change col/pane cells
				~column/autosize col
				; clock [show col]
			]
			; clock [attempt [show table]]
		]]
	]

	update-read-only: function [table [object!]] [
	do-atomic [do-unseen [clock-each [
		foreach column table/pane [
			foreach cell next column/pane [				;-- `next` to skip the header!
				cell/read-only?: table/read-only?
			]
		]
		; attempt [show table]
	]]]
	]

	; table?: function [face [object!]] [
	; 	all [select face 'mappers  select face 'shares  panel = select face 'type]
	; ]

	extend system/view/VID/styles [
		table: [
			default-actor: 'on-down		;???
			template: [
				type:   'panel
				size:   400x400
				color:  ~colors/text
				pane:   []
				flags:  [all-over]						;-- required for column resize to work
				rate:   10
				actors: [								;@@ TODO: allows user-defined actors & combine these with those
					on-time: func [fa ev] [if fa/balance-rows? [flush fa]]
					;@@ this could have all worked in `on-create`, but it doesn't - see #4473
					on-create: func [fa] [
						react/link func [table _] [
							map-to table table/data		;@@ TODO: block of blocks too ;@@ also see #4471
						] [fa fa]
					]
					on-created: func [fa] [
						context [
							table: fa
							react [[table/pane] autosize table]
							react [[table/size] adjust-width table]
							react [[table/read-only?] update-read-only table]
						]
					]

					; ;;@@ TODO: resizing when #4479 is resolved; until then - will be too hard and inelegant to work around
					; on-up: func [fa ev] [fa/drag-info: none]
					; on-down: function [fa ev /local c1 c2] [
					; 	unless fa =? ev/face [exit]		;-- click on a column/cell
					; 	o: ev/offset
					; 	for-each/stride [c1 c2] fa/pane [
					; 		unless all [c1/offset/x + c1/size/x < o/x  o/x < c2/offset/x] [continue]
					; 		fa/drag-info: reduce [o c1]
					; 	]
					; ]
					; on-over: function [fa ev /local ofs left-col] [
					; 	unless set [old-ofs left-col] fa/drag-info [exit]
					; 	; ?? ev/offset
					; 	if fa/actors =? self [
					; 	probe new-ofs: ev/offset
					; 	]
					; 	; new-ofs: either fa =? ev/face [ev/offset][probe new-ofs: face-to-face ev/offset ev/face fa]
					; 	; right-col: second find/same fa/pane left-col
					; 	; dx: new-ofs/x - old-ofs/x
					; 	; fa/drag-info/1: new-ofs
					; 	; ; dx: min dx right-col/size/x - 5
					; 	; ; dx: max dx 5 - left-col/size/x
					; 	; if dx = 0 [exit]
					; 	; do-unseen [
					; 	; 	maybe left-col/size/x:    left-col/size/x + dx
					; 	; 	maybe right-col/size/x:   right-col/size/x - dx
					; 	; 	maybe right-col/offset/x: right-col/offset/x + dx
					; 	; ]
					; ]
				]

				read-only?:    no
				balance-rows?: yes		;-- indicates that table handles cell resize, not columns
				extent:  0x0			;-- auto inferred size of the content, for the user to hook to
				spacing: 5x1			;-- inter-column band width x inter-row band height  ;@@ TODO: inter-row band is unused yet
				;@@ this is required in absense of floating point pairs, as otherwise each minor resize would distort column widths:
				shares: []				;-- percentage of width occupied by each column, set by autosize
				mappers: system/words/table/mappers
				sort-by: func [column [object! integer!]] [table/sort-by self column]

				; drag-info: none			;-- internal; used by column resize mechanism

				; insert-column ?
				; remove-column ?
				; insert-row ?
				; remove-row ?
			]
		]
	]

	;; TAB navigation support
	focusables: [field area button toggle check radio slider text-list drop-list drop-down]		;@@ calendar? tab-panel?
	tab-handler: function [fa ev] [
		unless all [
			ev/type = 'key-down
			ev/key = #"^-"
			attempt [fa =? fa/parent/selected]
		] [return none]

		look-forward: [
			case [
				fa =? face [found: yes]
				logic? found [found: face  break]		;@@ break doesn't work (see REP #78)
			]
		]
		look-back: [
			if fa =? face [found: last-face  break]		;@@ break doesn't work (see REP #78)
			last-face: face
		]
		foreach-face/with window-of fa 
			either ev/shift? [look-back][look-forward]
			[
				all [
					find focusables face/type
					face/enabled?
					face/visible?
				]
			]

		if object? found [set-focus found]
		'done
	]

	unless find/same system/view/handlers :tab-handler [
		insert-event-func :tab-handler
	]
];; table: context [


test-object: object [		;@@ reactor doesn't work - ownership limitation
	a: b: c: d: e: f: g: h: i: j: k: l: m: none
	on-change*: func [word old new] [
		poke types index? find words-of self word type?/word :new
	]
]
types: append/dup [] none length? words-of test-object
update-types: does [
	repeat i length? types [types/:i: type?/word get pick words-of test-object i]
]
; for-each [/i w] words-of test-object [
; 	react probe compose [poke types (i) type?/word (as get-path! reduce ['test-object w])]
; ]
random-value: does [
	do random/only [
		[as get random/only exclude to block! any-string! [ref!] copy random "string"]
		[to get random/only to block! number! random 100.0]
		[random white]
		[draw 50x50 + random 200x200 reduce [
			'fill-pen random white
			random/only [ellipse box]
			-20x-20 + random 50x50
			50x50 + random 100x100
		]]
	]
]
words: exclude words-of test-object [on-change* on-deep-change*]
foreach w words [set w random-value]
update-types
; clock [
; view/no-wait/options elastic [t: table [column column c3: column "1123" 300x400 [cell cell "abc"]] #fill]
; view/no-wait/options elastic [t: base 500x400 #fill data table]
; ~: :system/words
; view/no-wait/options probe elastic [scrollpanel [t: table 500x400 [column 300 column c3: column "1123"] data (system/catalog/errors/script)] #fill]
; view/no-wait/options probe [s: panel [t: base 500x400] react [probe t/size: face/size - 20]]
view/no-wait/options probe elastic [
	s: scrollpanel [
		at 0x0 t: table data test-object #fill-x
		on-down [
			c: event/face
			unless c/type = 'panel [c: c/parent]
			addr/data: (index? find/same t/pane col: c/parent)
			        by (-1 + index? find/same col/pane c)
		]
	] #fill
	return
	panel #fix [
		text "Cell:" addr: field on-change [cell: t/pane/(addr/data/x)/pane/(addr/data/y + 1)] button "Random cell" [addr/data: (random 4) by (random -1 + length? t/pane/1/pane)]
		return
		button "Random color" [cell/color: random white]
		button "Random font" [cell/font: make font! compose [color: (random white) size: (5 + random 10) name: (random/only ["Times New Roman" "Courier New" "Verdana"])]]
		return
		button "Randomize an object's field" [set random/only words random-value  update-types  table/update t]
	]
]
; view/no-wait/options probe elastic [backdrop red s: scrollpanel [at 0x0 t: table data [1 2 3] #fill-x] #scale]; react [t/size/x: face/size/x - 20]]
; view/no-wait/options probe elastic [backdrop red s: scrollpanel [at 0x0 t: table data system/catalog/errors/script #fill-x] #scale]; react [t/size/x: face/size/x - 20]]
; view/no-wait/options probe elastic [backdrop red s: scrollpanel [at 0x0 t: table data system/catalog/errors/script #fill-x] #scale]; react [t/size/x: face/size/x - 20]]
; view/no-wait/options probe elastic [s: panel 500x400 [t: table 500x400 data system/catalog/errors/script]  #scale react [probe t/size/x: face/size/x - 20]]
; view/no-wait/options elastic [s: scrollpanel 500x400 [t: base 500x400] #scale react [probe t/size/x: face/size/x - 20]]
; view/no-wait/options elastic [s: scrollpanel 500x400 [t: table 500x400 data system/catalog/errors/script] #scale react [probe t/size/x: s/size/x - 20]]
; view/no-wait/options probe elastic [s: scrollpanel [t: table 500x400 data table] #fill]
; view/no-wait/options probe elastic [t: reflection 500x400 data table #fill]
; view/no-wait/options elastic [t: table 500x400 [column column c3: column "1123"] #fill data table]
; view/no-wait/options elastic [t: table [column column column c3: column "1123" 200x400] #fill data table]
	[flags: [resize]]
; t/size/y: t/pane/1/size/y
; view/no-wait/options [t: table] [offset: 600x400 size: 600x400]
; ]


addr/data: 1x1
table/~column/map-to t/pane/3 types

