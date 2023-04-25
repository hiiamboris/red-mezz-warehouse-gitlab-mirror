Red [
	title:   "TAB navigation support for View"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {Just include it}
]

unless object? get/any 'tabbing [						;-- avoid multiple inclusion and multiple handler functions

	#include %relativity.red							;-- needs 'window-of'
	
	tabbing: context [
		;; what can be focused by tab key:
		focusables: make hash! [field area button toggle check radio slider text-list drop-list drop-down calendar tab-panel]
		
		list: make hash! 50
		
		list-faces: function [window [object!]] [
			also clear list
			foreach-face/with window [
				if find focusables face/type [append list face]
			] [any [all [face/enabled? face/visible?] continue]]	;-- filters out invisible/disabled tab-panel pages
		]
		
		key-events: make hash! [key key-down key-up]
		
		tab-handler: function [face event] [
			if result: all [
				key-events/(event/type)					;-- consume all tab key events
				event/key = #"^-"
				face/type <> 'area
				'done
			][
				all [
					event/type = 'key-down				;-- only switch on one event type (should be repeatable - key or key-down)
					list:   list-faces window-of face
					found:  any [find/same list face  list]
					offset: pick [-1 1] event/shift?
					index:  (index? found) + offset - 1 // (max 1 length? list) + 1
					set-focus list/:index
				]
			]
			result
		]
	
		unless find/same system/view/handlers :tab-handler [insert-event-func :tab-handler]
	]
]
