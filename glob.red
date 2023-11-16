Red [
	title:   "GLOB mezzanine"
	purpose: "Recursively list all files"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		In Windows some masks have special meaning (8.3 filenames legacy)
		     these special cases are not replicated in `glob`:
		- "*.*" is an equivalent of "*" 
		    use "*" instead or better leave out the /only refinement
		- "*." historically meant any name with no extension, but now also matches filenames ending in a period
		    use `/omit "*.?*"` instead of it
		- "name?" matches "name1", "name2" ... but also "name"
		    use ["name" "name?"] set instead
	}
]

;@@ an option not to follow symlinks, somehow?
;@@ allow time! as /limit ? like, abort if takes too long..
;@@ asynchronous/concurrent listing (esp. of different physical devices)


#include %match.red
#include %tree-hopping.red

foreach-file: glob: none
context [
	directory-walker: make batched-walker! [
		depth-limit: 2 ** 30
		branch: function [path [file!] /from depth [integer!]] [
			if files: attempt [read path] [				;-- ignore IO errors ;@@ use try/catch [] [exit] - #3755
				depth: 1 + any [depth -1]
				foreach file files [
					repend/only plan
						either all [
							dir? file
							depth < depth-limit
						]	[['visit path file 'branch/from path/:file depth]]
							[['visit path file]]
				]
			]
		]
	]

	~only: func [value [any-type!]] [any [:value []]]
	
	set 'foreach-file function [
		path    [file!]
		visitor [block! function!]
		/limit max-depth [integer!] 
	][
		directory-walker/depth-limit: any [max-depth 2 ** 30]
		foreach-node path directory-walker :visitor
	]
	
	;; test if file matches a mask (any of)
	match-any: function [file [file!] masks [block!]] [
		if dir? file [take/last file: append clear %"" file]	;-- shouldn't try to match against the trailing slash
		forall masks [if match/glob file masks/1 [return yes]]
		no
	]
	
	set 'glob function [
		"Recursively list all files"
		/from "Starting from a given path"
			root [file!] "CWD by default"
		/limit "Recursion depth (otherwise limited by the maximum path size)"
			sublevels [integer!] "0 = root directory only"
		/only "Include only files matching the mask or block of masks"
			imask [string! block!] "* and ? wildcards are supported"
		/omit "Exclude files matching the mask or block of masks"
			xmask [string! block!] "* and ? wildcards are supported"
		/files "List only files, not directories"
		/dirs  "List only directories, not files"
		/into buffer [any-list!] "Put files into an existing list"
	][
		root: either from [clean-path dirize to-red-file root][copy %./]
		if string? imask [imask: reduce [imask]]
		if string? xmask [xmask: reduce [xmask]]
		result: any [buffer make [] 128]
		offset: length? root
		foreach-file/:limit root compose/deep [
			any [
				(~only if files [[dir? key]])					;-- it's a dir but only files are requested?
				(~only if dirs  [[not dir? key]])				;-- it's a file but only dirs are requested?
				(~only if only  [[not match-any key imask]])	;-- doesn't match the provided imask?
				(~only if omit  [[match-any key xmask]])		;-- matches the provided xmask?
				append result skip node/:key offset
			]
		] sublevels
		result
	]
]

