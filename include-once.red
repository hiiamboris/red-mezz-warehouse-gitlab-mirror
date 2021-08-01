Red [
	title:   "#INCLUDE directive replacement"
	purpose: "Speed up Red loading phase 100+ times"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		I once inserted a 'print' inside `assert.red`...
		and found out it gets included from `everything.red` 126 times!!!
		No wonder Red loaded in 15-20 seconds.
		That's just enough.

		This #include replacement attempts to keep it under control.
		As a side effect it also prints the file name, so you always know where is the error.

		Implementation is tricky. #include has to:
		- check if file is already included
		- load macros into preprocessor
		- replace itself with a `do call` if interpreted
		- replace itself with file contents if compiled

		Due to #4941 it doesn't seem all possible, so instead I do the following:
		- if we're compiling, do NOT declare the macro
		- check if file is already included
		- replace itself with file contents (this will likely mess reported error line numbers)
		- insert `change-dir` into file contents block to properly handle relative includes
	}
]

#if not object? rebol [									;-- do nothing when compiling
	;-- since it's now running in Red, we don't need R2 compatibility
	#do [verbose-inclusion?: yes]						;-- comment this out to disable file names dump
	
	#macro [#include] func [[manual] s e /local file data old-path path _] [
		unless file? :s/2 [
			do make error! rejoin [
				"#include expects a file argument, not " mold/part :s/2 100
			]
		]
		
		unless block? :included-scripts [included-scripts: copy []]
		file: clean-path :s/2							;-- use absolute paths to ensure uniqueness
		if find included-scripts file [					;-- if already included, skip it
			return remove/part s 2
		]

		data: try [load file]
		if error? data [								;-- on loading error, report & skip
			print data
			return remove/part s 2
		]

		if true = :verbose-inclusion? [print ["including" mold file]]
		old-path: what-dir
		set [path _] split-path file
		change/part s compose/deep [					;-- insert contents
			(to issue! 'do) [change-dir (path)]			;-- descend into paths for relative includes to work
			(data)
			(to issue! 'do) [change-dir (old-path)]
		] 2
		append included-scripts file
		s												;-- continue processing from contents itself
	]
]
