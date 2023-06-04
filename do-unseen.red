Red [
	title:   "DO-UNSEEN mezzanine"
	purpose: "Disable View redraws from triggering during given code evaluation"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		I'm using this in a *lot* of places, so it finally deserves a mezz status.

		Purpose is optimization. E.g. you wanna update 100 faces at once.
		Would you render the layout 100 times, or only once? DO-UNSEEN ensures the latter.
		After updating everything, call SHOW on the parent face that contains all updated faces and you're good.

		You cannot use non-local control flow within it, e.g. break from an outer loop
		(otherwise it would leave `auto-sync?` in a changed state)
	}
]

if object? :system/view [								;-- CLI programs skip this
	do-unseen: func [
		"Evaluate CODE with view/auto-sync?: off"
		code [block!]
		/local r e old
	][
	    old: system/view/auto-sync?
	    system/view/auto-sync?: no
		e: try/all [set/any 'r do code  'ok]
	    system/view/auto-sync?: old
	    if error? e [do :e]								;-- rethrow the error AFTER restoring auto-sync
		:r
	]
]