Red [
	title:   "EXPLORE mezzanine"
	purpose: "Provides UI to interactively inspect a Red value in detail"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		Plan is to make it accept any complex Red value and let it find the best layout to display it.
		Throw something onto it and don't care.
		Current version only supports images!!!

		Some design ramblings:

		It should display the path to the value represented in a window (in the title?)

		Should somehow be embeddable into a side-by-side comparison layout used in the View test system
		For that, will require a refinement that will generate and return the layout only (to be added into a panel in a window)

		For complex values there are 2 rendering types: short/thumbnail and full (in a separate window)

		Hardest task here is to display a block of code with the ability to also explore each word's value
		(use Toomas's work for that)

		How to display values?
		These should be just molded:
			datatype! 
			unset! 
			none! 
			logic! 
			char! 
			integer! 
			word! 
			set-word! 
			lit-word! 
			get-word! 
			issue! 
			refinement! 
			path! 
			lit-path! 
			set-path! 
			get-path! 
			pair! 
			time! 
			money! 
			date! 

		Floats may require formatting? Or maybe not; then also molded (mold/all)
			float! 
			percent! 

		Mold/all?
			handle! 

		For strings it depends:
		short strings should be just molded;
		paragraphs require a text/base/area to display them formatted
		big multiline strings (e.g. >10 lines) should be considered "text" and allow opening a new window
		(or maybe allow that for paragraphs too?)
			string! 
		other stringy types should be immediate one-liners (though long; possibly wrapped into a few lines)
			tag! 
			file! 
			url! 
			email! 
			ref! 

		Hovering over should display the contains:
			typeset! 

		Any-func should be looked up in system/words
		then if it's a known native/whatever - just display it's name
		and when hovered/clicked - open it's source
		When unknown - show summary - num of args, code length, last expression(?)
		then when hovered/clicked - open it's source (for natives - use nsource)
		Function bodies should be explorable as code
			op! 
			function! 
			routine! 
			native! 
			action! 

		Block - try to find out if it's a table - when types of values are different but match 2+ columns set
		Each table cell should be explorable or not - applying same general by-type rules
		Normal linear blocks (esp if all value types are the same) - probably show as 1 column? or by 10 values in a row? (also explorable)
		this may depend on type too: blocks of images; blocks of bitsets; blocks of strings - a lot of room for heuristics
		If it's code (requires heuristics to know) - requires formatting, caret-to-word metrics, and tooltips/openable windows
				heuristics for code:
				- lots of words
				- small percentage of final values of logic/unset/datatype/any-func/typeset/bitset/any-object/image/event/port type - those not having lexical forms
				- not a table
				- known control flow constructs, used properly - very reliable marker; but not for one-liners
				- ......?
			block! 
			hash! 

		Paren is CODE; a small expression, but may contain explorable values - this is the hard part
			paren! 

		Vector is not explorable and not a table - arrange in 1 or 10 columns?
		Technically it can be a table - but hard to determine that (maybe find columns by repeatable patterns in value magnitude?)
			vector! 

		Object & map is a 2-column table; values all explorable. For map - keys too. Events - use accessors list.
			object! 
			error! 
			map! 
			event!

		Bitset will need 8-bit grouping; maybe visual form - b/w squares with bit numbers? or characters? or both?
		Arrange long bitset into multiple rows; possibly explorable if huge?? (e.g. unicode chars)
			bitset! 

		Binary: formatting is essential for >8digit values, explorable if big (same rules as for strings)
			binary! 

		Tuples - 3/4-tuples may be colors, should be displayed as a box of that color
			tuple! 

		Image - display thumbnail in lists, explore it in detail when clicked/hovered
		On thumbnail: info (size, has alpha or not)
		Alpha enabled images - diplay on checkered background
			image! 

		Not known yet:
			port! 

		One possibility is to add a 2-state or multi-state button that will toggle the meaning of blocks/bitsets,
		but esp. blocks - whether it's code/data, and maybe a way to control the number of columns
		heuristic then will only be used to guess the starting values
	}
]


#include %xyloop.red
#include %relativity.red
#include %contrast-with.red


;@@ TODO: make a routine out of this
;@@ should this be globally exported?
upscale: function [
	"Upscale an IMAGE by a ratio BY so that each pixel is identifiable"
	image [image!]
	by    [integer!] "> 1"
	/into "Specify a target image (else allocates a new one)"
		tgt [image!]
	/only "Specify a region to upscale (else the whole image)"
		from [pair!] "Offset (0x0 = no offset; left top corner)"
		size [pair!] "Size of the region"
][
	#assert [1 < by]
	box: [pen coal box 0x0 0x0]							;-- single pixel
	box/5: by * 1x1
	unless only [from: 0x0 size: image/size]

	cache: [0x0]										;-- somewhat faster having cache
	if cache/1 <> size [								;-- build the skeleton
		clear change cache size
		xyloop xy size [
			append cache reduce [
				'fill-pen 0.0.0
				'translate xy - 1x1 * by
				box
			]
		]
	]

	i: 3
	xyloop xy size [								;-- fill it with the colors
		cache/:i: any [image/(from + xy) white]		;-- make absent pixels white
		i: i + 5
	]

	draw any [tgt size * by + 1] next head cache
]


zoom-factor?: function [
	"Determine the maximum zoom factor that allows to fit SRC-SIZE within DST-SIZE"
	src-size [pair!]
	dst-size [pair!]
][
	min 												;-- use the narrowest dimension
		1.0 * dst-size/x / max 1 src-size/x
		1.0 * dst-size/y / max 1 src-size/y
]


explore: function [
	"Opens up a window to explore an image in detail (TODO: other types)"
	im [image!]
][
	window-sz: system/view/screens/1/size * 0.8					;-- do not make the window too big
	min-scale: 4												;-- if can't be zoomed to this ratio - needs a separate magnifier
	fit?: within? im/size * min-scale 0x0 window-sz				;-- does the zoomed image fully fit?

	either fit? [												;-- determine the final zoom ratio and "whole image" size
		scale: to integer! zoom-factor? im/size window-sz
		#assert [scale >= min-scale]
		whole-sz: im/size * scale							;-- window size will adapt to the image dimensions
		magn-im: upscale im scale
		piece-sz: 0x0
		magnifier: []
		canvas: [canvas: image magn-im]
	][
		whole-sz: window-sz * 2x1 / 3x1							;-- allocate 2/3 of the window for the original image
		scale: min 1 zoom-factor? im/size whole-sz				;-- don't upscale by a small factor
		whole-sz: im/size * scale + 1
		
		zoom: 5													;-- low values generate too much latency
		magn-sz: as-pair										;-- size of the magnified image
			min 500 window-sz/x - whole-sz/x					;-- window without the whole part, but not too wide
			max 500 whole-sz/y									;-- not too slim
		piece-sz: magn-sz / zoom								;-- size of fragment that will be zoomed
		magn-sz: piece-sz * zoom + 1x1
		magn-im: make image! magn-sz							;-- magnified image
		magnifier: [magnifier: image magn-im all-over on-over :aim]
		canvas: [canvas: image im whole-sz]
	]

	curly: charset "{}"
	aim: func [fa ev] [
		if either fa =? canvas [not any [fit? ev/down?]][ev/away?] [exit]	;-- no action on zoomed canvas with LMB up
		ofs: ev/offset
		img-ofs: 1x1 + either fa =? canvas [ofs / scale][ofs / zoom + box-ofs]
		dpi-ofs: pixels-to-units img-ofs									;-- face coords, useful in case image is a face shot
		txt-ofs: max 0x0 ofs - 60x12										;-- don't put text outside of the canvas
		txt-ofs: min txt-ofs fa/size - 60x40
		color: attempt [replace/all form to binary! im/:img-ofs curly ""]	;-- pixel color in text form
		fa/draw: compose [
			pen (magenta + contrast-with any [im/:img-ofs white])  fill-pen off  font fnt
			line (ofs * 1x0) (as-pair ofs/x fa/size/y)						;-- draw the cross
			line (ofs * 0x1) (as-pair fa/size/x ofs/y)
			(either all [fa =? canvas not fit?] [
				compose/deep [
					scale (scale) (scale) [
						box  (box-ofs: img-ofs - (piece-sz / 2) - 1)		;-- draw the box outline
						     (box-ofs + piece-sz)
					]
				]
			][ [] ])
			text (txt-ofs)        (form img-ofs)							;-- show the coords
			text (txt-ofs + 0x16) (form dpi-ofs)
			text (txt-ofs + 0x30) (any [color ""])
		]
		info/data: compose [												;-- duplicate the text in case it's invisible
			"offset:"       (img-ofs) 
			"  offset/dpi:" (dpi-ofs)
			"  color:"      (color)
		]
		unless any [fit? fa =? magnifier] [														;-- update the magnifier
			magnifier/image: upscale/into/only im zoom magn-im box-ofs piece-sz
		]
	]

	fnt: make font! [name: system/view/fonts/fixed size: 7 style: 'bold]		;-- font for coordinates
	view compose [
		info: text font fnt 300 "" return
		(magnifier)
		(canvas)
		on-down :aim
		on-over :aim all-over
		on-created [aim face object [offset: 1x1 down?: yes away?: no]]
	]
]

; explore load %../red-view-test/old/buggy-image.png
