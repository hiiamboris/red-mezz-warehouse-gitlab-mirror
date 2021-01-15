Red [
	title:   "WITH function - a convenient/readable BIND variant"
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		USAGE
		;; omit the path to an object, but work inside it's context:

			do with face/parent/pane/1 [
				color: red
				text: mold color
				visible?: yes
			]
			
			if true with system/view/fonts [print [serif size]]

			f: func [/- /+ /*] [		;-- redefines important globals locally
				(do something with local flags)
				foreach x [set..] with system/words [
					(do something with global * + -)
				]
			]

		;; create static storage for functions where existing literal forms don't allow you to:

			factorial: func [x] with [cache: make hash! [0 1]] [
				any [
					select/skip cache x 2
					put cache x x * factorial x - 1
				]
			]

		;; anonymize words used during initialization of the program:

			do with [x: 1 y: 2] [
				z: x * y
				... other code that uses x or y ...
			]
	}
	notes: {
		Design question here is - if we allow block! for `ctx`, how should we treat it?
		- convert it to a context? `ctx: context ctx` - that shortens the `with context [locals...] [code]` idiom
		- list multiple contexts in a block as a sequence and bind to each one? - that shortens `with this with that [code]` idiom
		Personally, I've used the 1st at least a few times, but 2nd - never.
	}
]

with: func [
	"Bind CODE to a given context CTX"
	ctx [any-object! any-function! any-word! block!] "If block is given, converted into a context"
	code [block!]
][
	bind code either block? :ctx [context ctx][:ctx]
]
