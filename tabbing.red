Red [
	title:   "TAB navigation support for View"
	author:  @hiiamboris
	license: 'BSD-3
	usage:   {Just include it}
]

if object? :system/view [								;-- CLI programs skip this
unless object? get/any 'tabbing [						;-- avoid multiple inclusion and multiple handler functions

	#include %tree-hopping.red
	
	tabbing: context [
		
		window-walker: make batched-walker! [
			next-face: function [face [object!]] [
				any [
					select face/options 'next
					if face/pane [face/pane/1]
					also no while [all [parent: face/parent face/type <> 'window]] [
						if sibling: select/same parent/pane face [return sibling]
						face: parent
					]
					if face/type = 'window [face/pane/1]
				]
			]
			bottom: function [face [object!]] [
				while [not empty? face/pane] [face: last face/pane]
				face
			]
			prev-face: function [face [object!]] [
				parent: face/parent
				pane: find/same parent/pane face
				any [
					select face/options 'prev
					if pane/-1 [bottom pane/-1]
					if parent/type <> 'window [parent]
					bottom parent
				]
			]
		
			forward?: yes
			
			;; iterates over all other faces within the window
			branch: function [face [object!]] [
				fetch: either forward? [:next-face][:prev-face]
				start: face
				while [all [
					face: fetch face
					not same? face start
				]] [repend/only plan ['visit face/parent face]]
			]
		]

		enabled?: func [face] [
			while [face] [
				unless all [face/enabled? face/visible?] [return no]
				face: face/parent
			]
			yes
		]
		focusable?: func [face] [
			any [
				face/flags = 'focusable
				find face/flags 'focusable
			]
		]
		
		tab-handler: function [face event] [
			all [
				event/key = #"^-"
				not event/ctrl?							;-- let area and tab-panel handle ctrl-tab
				result: 'stop							;-- stop to avoid area inserting Tab char
				event/type = 'key-down					;-- only react to one event type (should be repeatable - key or key-down)
				(
					window-walker/forward?: not event/shift?
					foreach-node face window-walker [
						if all [focusable? key enabled? key] [ 
							set-focus key
							break
						]
					]
				) 
			]
			result
		]
	
		remove-event-func 'tab							;-- disable native tabbing handler
		unless find/same system/view/handlers :tab-handler [insert-event-func 'tabbing :tab-handler]
	]
];unless object? get/any 'tabbing [
];if object? :system/view [
