Red [
	title:   "#INCLUDE directive replacement"
	purpose: "Speed up Red loading phase 100+ times"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		NOTE: MAKE SURE THIS IS THE FIRST INCLUDED SCRIPT
		                IN THE MAIN FILE!
		                
		   ALSO PAY ATTENTION TO THE USAGE OF `DO %FILE`!
		`DO` RUNS PREPROCESSOR AND EVALUATION IN DIFFERENT PLACES! (#5121)		                
		                
		Otherwise the following mess happens:
		1. preprocessor "includes" and discards every file, replaces `#include` with `do`
		2. `do` now expands files that "seem" to have been included already, and now become empty (deduplicated)
		3. you get "undefined symbol" kind of errors, etc
	
		Description:
		
		I once inserted a 'print' inside `assert.red`...
		and found out it gets included from `everything.red` 126 times!!!
		No wonder Red loaded in 15-20 seconds.
		That's just enough.

		This #include replacement attempts to keep it under control.
		It can also prints the included file names, so you would always know where is the error
		(turned on by `verbose-inclusion?` flag below).

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
		
		It's not possible to compile using this approach, because Red code is not usually loadable in R2
		For compiling, see https://codeberg.org/hiiamboris/red-cli/src/master/mockups/inline
		
		
		Addendum.
		
		It now has rudimentary dependency specification.
		File header may contain the following recognized fields:
		- 'provides' [block! word!] - name(s) of the dependencies provided by this file
		- 'depends'  [block! word!] - name(s) of the dependencies required to load this file
		  (this does not include dependencies needed to run this file's functions)
		
		Currently, just a warning will be issued if a dependency is not present.
		Proper dependency resolution needs modules design, as otherwise it will be just a kludge in the current include system.
		Besides, this file does not affect compiled or inlined code, so such resolution is far out of its scope.
	}
]
;@@ TODO: instead of printing, use `try/all` and report the file where the error happens

#if all [
	not object? :rebol									;-- do nothing when compiling
	not block? :included-scripts						;-- do not reinclude itself (does not shield from double evaluation though)
][
	; #do [verbose-inclusion?: yes]						;-- comment this out to disable file names dump
	#do [	
		system/words/included-scripts: reduce [			;@@ no /extern support - #5386
			append what-dir %include-once.red			;-- add itself to avoid double evaluation
		]
	]
	
	;; since it's now running in Red, we don't need R2 compatibility
	#macro [#include] function [[manual] s e] [
		indent: ""
		unless file? :s/2 [
			do make error! rejoin [
				"#include expects a file argument, not " mold/part :s/2 100
			]
		]
		
		file: clean-path to-red-file :s/2				;-- use absolute paths to ensure uniqueness
		if find included-scripts file [					;-- if already included, skip it
			return remove/part s 2
		]
		if verb?: true = :verbose-inclusion? [
			print rejoin ["including " mold file]
		]
		data: try [load file]
		if error? data [								;-- on loading error, report & skip
			print data
			return remove/part s 2
		]
		
		old-path: what-dir
		set [path: name:] split-path file
		if 'Red == :data/1 [							;-- skip the header in case Red word is defined to smth else
			header: construct data/2
			if provides: select header 'provides [append included-scripts provides]
			if depends:  select header 'depends [
				missing: clear []
				foreach token compose [(depends)] [
					unless find/only included-scripts token [append missing token]
				]
				unless empty? missing [
					sfx: either single? missing ["y"]["ies"]
					print rejoin ["^/*** WARNING: File " mold name " requires '" mold/only missing "' dependenc" sfx "^/"]
				]
			]
			data: skip data 2
		]
		
		prelude:  compose [change-dir (path)]			;-- evaluate inside script's path
		postlude: compose [change-dir (old-path)]		;-- restore path after evaluation (unless errors out or halts..)
		if verb? [
			prelude: compose/deep [
				print rejoin [append (indent) " " "processing " (mold file)]
				(prelude)
			]
			postlude: compose/deep [
				(postlude)
				print rejoin [" " remove (indent) "finished " (mold file)]
			]
		]
		
		;@@ dilemma here is that we want to include file as is, exposing all set-words into the context
		;@@ but on the other hand we want to be able to assign the result to a word, and can't have both :(
		change/part s compose/deep [					;-- insert contents
			(to issue! 'do) [change-dir (path)]			;-- preprocess inside script's path
			(prelude)
			(data)
			(postlude)
			(to issue! 'do) [change-dir (old-path)]
		] 2
		; print ["===" file "expands into:^/" mold s]
		append included-scripts file
		s												;-- continue processing from contents itself
	]
]
