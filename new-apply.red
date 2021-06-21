Red [
	title:   "APPLY mezzanine"
	purpose: "Experimental APPLY implementation for inclusion into Red runtime"
	author:  @hiiamboris
	license: 'BSD-3
	notes: {
		See https://github.com/greggirwin/red-hof/blob/master/apply.md for some background

		Usage patterns:

		I	apply :function 'local
			apply  funcname 'local

			Set arguments of function to their values from given (by 'local) context and evaluate it.
			Context will typically be a wrapping function.
			Use case: function (or native) extension, when argument names are the same, with maybe minor variations.
			Example:
				my-find: function
					compose [(spec-of :find) /my-ref]
					[
						..handle /my-ref..
						apply find 'local
					]
				my-find/my-ref/same/skip/only series needle n


		II	apply :function [arg-name: expression ref-name: logic ...]
			apply  funcname [arg-name: expression ref-name: logic ...]
			apply/verb :function [arg-name: value ref-name: logic ...]
			apply/verb  funcname [arg-name: value ref-name: logic ...]

			Call func with arguments and refinements from evaluated expressions
			or verbatim values followng the respective set-words.
			These set-words don't interfere with the expressions,
			so `apply .. [arg: arg]` is a valid usage, not requiring a `compose` call.
			Use case: programmatic call construction, esp. when refinements depend on data.
			Example:
				response: apply send-request [
					link:    params/url
					method:  params/method
					with:    yes						;) refinement state is trivially set
					args:    request
					data:    data						;) sets `data` argument to value of `data` word
					content: bin
					raw:     raw
				]

		Notes on 1st argument:
		- it has to support literal function values for they may be unnamed
		- it has to support function names for better informed stack trace
		- `apply name` form is chosen over `apply 'name` because if we make operator out of apply it will look better:
			->: make op! :apply
			find -> [series: s value: v]				;) rather than `'find -> [series: s value: v]`
	}
]


