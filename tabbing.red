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
		
		window-walker: make walker! [
			;; abstraction functions that can be overridden
			window?:     function [face [object!]] [face/type = 'window]
			next-linked: function [face [object!]] [select face/options 'next]
			prev-linked: function [face [object!]] [select face/options 'prev]
			first-child: function [face [object!]] [if face/pane [face/pane/1]]
			last-child:  function [face [object!]] [if face/pane [last face/pane]]
			has-child?:  function [face [object!]] [not empty? face/pane]
			next-child:  function [parent [object!] child [object!]] [
				select/same parent/pane child
			]
			prev-child:  function [parent [object!] child [object!]] [
				if found: find/same parent/pane child [found/-1]
			]
			parent-of:   function [child [object!]] [
				all [
					parent: child/parent
					parent/type <> 'screen				;-- window is the last allowed parent
					parent
				]
			]
			
			;; tree iteration logic
			next-face: function [face [object!]] [
				any [
					next-linked face
					first-child face
					(
						while [parent: parent-of face] [
							if sibling: next-child parent face [return sibling]
							face: parent
						]
						first-child face				;-- 'face' is different now (usually a window)
					)
				]
			]
			bottom: function [face [object!]] [
				while [has-child? face] [face: last-child face]
				face
			]
			prev-face: function [face [object!]] [
				any [
					prev-linked face
					unless parent: parent-of face [bottom face]
					if sibling: prev-child parent face [bottom sibling]
					if window? parent [bottom parent]
					parent
				]
			]
		
			;; chooses iteration direction
			forward?: yes
			
			;; entry point - iterates over all other faces within the window
			branch: function [face [object!]] [
				fetch: either forward? [:next-face][:prev-face]
				start: unless window? face [face]		;-- window will never be visited again, so avoid deadlock
				while [all [face: fetch face  not same? face start]] [
					repend/only plan ['visit parent-of face face]
					start: any [start face]
				]
			]
		]

		enabled?: function [face [object!]] [
			while [face] [
				unless all [face/enabled? face/visible?] [return no]
				face: face/parent
			]
			yes
		]
		focusable?: function [face [object!]] [
			any [
				face/flags = 'focusable
				all [
					block? face/flags
					find face/flags 'focusable
				]
			]
		]
		
		visitor: function [parent [object! none!] child [object!]] [
			if all [focusable? child enabled? child] [ 
				set-focus child
				break
			]
		]
							
		tab-handler: function [face event] [
			all [
				event/key = #"^-"								;-- this automatically covers all key- events
				not event/ctrl?									;-- let area and tab-panel handle ctrl-tab
				any [focusable? face face/type = 'window]		;-- don't disable tab-completion in console and other custom faces
				result: 'stop									;-- stop to avoid area inserting Tab char
				if event/type = 'key-down [						;-- only react to one event type (should be repeatable - key or key-down)
					window-walker/forward?: not event/shift?
					foreach-node face window-walker :visitor
				]
			]
			result
		]
	
		remove-event-func 'tab							;-- disable native tabbing handler
		unless find/same system/view/handlers :tab-handler [insert-event-func 'tabbing :tab-handler]
	]
];unless object? get/any 'tabbing [
];if object? :system/view [
