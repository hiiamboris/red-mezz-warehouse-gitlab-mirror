Red [
	title:    "## macro"
	purpose:  "Load any value using load-time evaluation"
	author:   @hiiamboris
	license:  BSD-3
	provides: load-anything
	notes: {
		I often need to MOLD a draw block so I can both visually inspect it
		and draw it on a separate image (to isolate the influence of a bigger codebase).
		
		And every time this meant editing a ~100k file manually.
		No more.
		Spaces' MOLD/ALL now can output values that are loadable using this macro.
		
		Format:
			##[..arbitrary code..]
		Which gets replaced by the evaluation result.
		
		Note: cannot be used inside literal maps, since they are not expanded by the preprocessor!
		Use ##[make map! [...]] format. 
	}
]

;; let compiler and inline tool keep the macro for runtime so it keeps working while expanding loaded data
;@@ ugly because includes workarounds for #5462,3
#if rebol [
	expand-directives [#do keep [load {
		#macro [## block!] func [[manual] s e] [
			change/only remove s do expand-directives s/1
		]
	}]]
]
#if all [value? 'inlining? get 'inlining?] [
	;; this needs to skip #macro while inlining, but use it when compiling
	expand-directives [#do keep [[#do keep]] [load {
		#macro [## block!] func [[manual] s e] [
			change/only remove s do expand-directives s/1
		]
	}]]
]

#macro [## block!] func [[manual] s e] [
	change/only remove s do expand-directives s/1
]

...: none												;-- try to avoid errors from loading molded cyclic data
