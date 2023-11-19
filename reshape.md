# [RESHAPE](reshape.red)

This mezz was made to counter the limitations of COMPOSE.<br>
Inspired also by [Ladislav Mecir's BUILD](https://gist.github.com/rebolek/edb7ba63bbaddde099cb3b1fd95c2d2c)

**Examples**

The following 3 snippets create a string for program identification, e.g. `"Program-name 1.2.3 long description by Author"`, omitting Description and Author parts when those are not specified:

| method | code |
|:-|-|
| reshape | <pre>form reshape [<br>	@(pname) @(ver)	@(desc)<br>	"by" @(author)	/if author<br>	#"^/"<br>]</pre> |
| compose | <pre>form compose [<br>	(pname) (ver)<br>	(any [desc ()])<br>	(either author [rejoin ["by "author]][()])<br>	#"^/"<br>]</pre> |
| build | <pre>form build/with [<br>	!pname !ver ?desc ?author #"^/"<br>][<br>	!pname: pname<br>	!ver: ver<br>	?desc: any [any [desc ()]<br>	?author: either author [rejoin ["by "author]][()]<br>]</pre> |

These snippets create Draw code for a box with given parameters (pens, thickness, radius), resulting in smth like `fill-pen blue box 1x1 99x49 5`:

| method | code |
|:-|-|
| reshape | <pre>reshape [<br>	push [<br>		pen      @(pen)				/if pen<br>		fill-pen @(fill-pen)		/if fill-pen<br>		line-width @(line)<br>		box @(mrg) @(size - mrg) @(radius)<br>	]<br>]</pre> |
| compose | <pre>compose/deep [<br>	push [<br>		(either pen      [compose [pen      (pen)]     ]] [[]])<br>		(either fill-pen [compose [fill-pen (fill-pen)]]] [[]])<br>		line-width (line)<br>		box (mrg) (size - mrg) (radius)<br>	]<br>]</pre> |
| build | <pre>build/with [<br>	push [<br>		?pen<br>		?fill-pen<br>		line-width !line<br>		box !mrg !size-mrg !radius<br>	]<br>][<br>	?pen:      either pen      [build [pen ins pen]] [[]]<br>	?fill-pen: either fill-pen [build [fill-pen ins fill-pen] [[]]<br>	!line:     line<br>	!mrg:      mrg<br>	!size-mrg: size - mrg<br>	!radius:   radius<br>]</pre> |

These snippets create Draw code for a tooltip with an arrow, based on the `make-box` code from examples above. `matrix` is used to flip the arrow vertically if tooltip is displayed above the content. Arrow is disabled if tooltip was moved due to lack of space in the window to display it where requested:

| method | code |
|:-|-|
| reshape | <pre>reshape [<br>	@(make-box/round/margin box/size 1 none none 3 1x1 + m)<br>	push [<br>		matrix [1 0 0 -1 0 @(box/size/y)]			/if o <> 0x0<br>		shape [move @(m + 4x1) line 0x0 @(m + 1x4)]<br>	]												/if o: box/origin	;-- or no arrow<br>	@[drawn]<br>]</pre> |
| compose | <pre>o: box/origin<br>?matrix: either o <> 0x0 [compose/deep [matrix [1 0 0 -1 0 (box/size/y)]]] [[]]<br>?arrow: either o [<br>	compose/deep [<br>		push [<br>			?matrix<br>			shape [move @(m + 4x1) line 0x0 @(m + 1x4)]<br>		]<br>	] [[]]<br>]<br>compose/deep [<br>	@(make-box/round/margin box/size 1 none none 3 1x1 + m)<br>	?arrow<br>	@[drawn]<br>]</pre> |
| build | <pre>;) maybe I'm just not proficient enough with this function?<br>o: box/origin<br>build/with [<br>	!box<br>	?arrow<br>	!drawn<br>][<br>	!box: make-box/round/margin box/size 1 none none 3 1x1 + m<br>	!drawn: drawn<br>	matrix: either o <> 0x0 [build [matrix [1 0 0 -1 0 ins box/size/y]]] [[]]<br>	?arrow: either o [<br>		build [<br>			push [<br>				ins matrix<br>				shape [move ins (m + 4x1) line 0x0 ins (m + 1x4)]<br>			]<br>		] [[]]<br>	]<br>]</pre> |

And these snippets build a test function used in old implementation of [FOR-EACH](for-each.red) that checks if values ahead conform to the constraints in the spec. <br>Spec may have type & value constraints, or none of these. <br> Result will look like `unless ..checks.. [continue]` if checks are required, and empty `[]` otherwise:

| method | code |
|:-|-|
| reshape | <pre>test: []<br>if filtered? [<br>	test: reshape [<br>		types-match?  old types                             /if use-types?<br>		values-match? old values values-mask :val-cmp-op    /if use-values?<br>	]<br>	test: reshape [<br>		unless<br>			all @[test]                                     /if both?: all [use-types? use-values?]<br>			@(test)                                         /if not both?<br>		[continue]<br>	]<br>]<br></pre> |
| compose | <pre>test: []<br>if filtered? [<br>	type-check:   [types-match?  old types]<br>	values-check: [values-match? old values values-mask :val-cmp-op]<br>	test: compose [<br>		(pick [type-check   []] use-types?)<br>		(pick [values-check []] use-values?)<br>	]<br>	if all [use-types? use-values?] [<br>		test: compose/deep [all [(test)]]<br>	]<br>	test: compose [unless (test) [continue]]<br>]<br></pre> |
| build | <pre>test: []<br>if filtered? [<br>	test: build/with [<br>		unless :!test [continue]<br>	][<br>		!test: build/with [<br>			:!type-check :!values-check<br>		][<br>			!type-check: pick [<br>				[types-match?  old types]<br>				[]<br>			] use-types?<br>			!values-check: pick [<br>				[values-match? old values values-mask :val-cmp-op]<br>				[]<br>			] use-values?<br>		]<br>		if all [use-types? use-values?] [<br>			!test: build [all only !test]<br>		]<br>	]<br>]<br></pre> |

As can be seen, RESHAPE shows the intent behind the code more clearly in complex scenarios.

## Syntax

`reshape` is **newline-aware** dialect.
 
`reshape` has only **two grammar tokens**, used in 4 variants:

| rule | grammar | description | example | result |
|-|-|-|-|-|
| insertion | `@[expression...]` | Evaluated and always inserted as a single value | `@[append [1] 2]` | `[1 2]` |
| splicing | `@(expression...)` | Evaluated and spliced, except when result is none! or unset! | `@(append [1] 2)` | `1 2` | 
| line exclusion | `content... /if expression` | All content on the line is included/excluded if the result of `expression` evaluation is true/false | `1 @(2 + 3) /if word? 'x` | `1 5` |
| section exclusion | (at the line start) `/if expression` | Everything after this line and up to next single `/if` on the line (or up to the end) is included/excluded if the result of `expression` evaluation is true/false | <pre>/if word? 'x<br>1 @(2 + 3)<br>/if false<br>@(4 + 5)</pre> | `1 5` |

Grammar may be altered using `/with` refinement, e.g.: `reshape/with [@substitute @include] [...data...]`. Note that the argument to `/with` in this case comes before the data to process.

Implementation notes:
- `reshape` processing is **always deep** (descends into `any-list!` values). Lists following the `@` token are an exception - they are just evaluated, not reshaped (for performance reasons mainly).
- line exclusion and section **exclusion may be used together**: a line is excluded if either of the exclusion conditions are met
- excluded sections are completely skipped, so all expressions in them remain unevaluated, while expressions on excluded lines are still evaluated and may produce side effects (a performance tradeoff that should not be relied upon)
- expressions on the line are evaluated before the `/if` that follows the line (also a performance tradeoff that should not be relied upon), and this includes reshaping of the nested lists
- newline markers between `@` and next list, as well as between `/if` and the end of its expression do not matter to reshape, so `@` and `/if` may appear on their own lines
- no other tokens should appear after `/if expression` - it's invalid to have them, though it's not verified currently (for performance reasons)
- performance of `reshape` is about 10% of `compose/deep` as it's written in pure Red, but still may be significanly improved with [REP #133](https://github.com/red/REP/issues/133)


## An overview of the previous designs

**Let's start with COMPOSE limitations:**
- **Expressions** used in it are often **long** and they make the code very messy. It becomes **hard to tell** how the result will **look like**.<br>
  E.g. `compose [x (either flag? [[+ y]][]) + z]` -- go figure it will look like `[x + z]` or `[x + y + z]` in the end<br>
  This can be circumvented by making preparations, although the number of words grows fast:
  ```
    ?+y: either flag? [[+ y]][[]]
    compose [x (?+y) + z]
  ```
- It uses parens, so if one wants to also **use parens** in the code, code gets **uglified**.<br>
  E.g. `parse compose [skip p: if ([((index? p) = i)])]` -- seeing this immediately induces headache ;)<br>
  Plus it's a **source of bugs** when one forgets to uglify a paren, especially in big code nested with blocks.
- There's no way to **conditionally include/exclude** whole blocks of code without an inner COMPOSE call<br>
  E.g. `compose [some code (either flag? [compose [include (this code) too]][])]` -- `compose/deep` won't help here<br>
  Also sometimes when one conditionally includes the code, one may want to prepare some values for it:<br>
  E.g. `compose [some code (either flag? [my-val: prepare a block  compose [include (my-val) too]][])]` -- this totally destroys readability (and not always can be taken out of `compose` expression easily, when there's a lot of conditions depending one on the other)
- Sometimes there's a need to **compose** the code used in **conditions** (not the included code itself!) before evaluating them.<br>
  E.g. `compose [some code (do compose [either (this) (or that) [..][..]])]` -- top-level `compose/deep` won't help again

**What I like about COMPOSE is:**
- Parens visually outline both **start and end points** of substitution: very are **easy to tell apart** from the unchanging code.
- Parens are very **minimalistic**, which also helps **readability** in easy cases. And it's also easy to implement.

**Ladislav's BUILD has some advantages over it:**
- One can **freely use parens** as they have no special meaning, and their content will be **deeply expanded** as well.
- With preparation code moved into the /with block, **expression** itself can be **even cleaner** than it's COMPOSE variant:<br>
    `build/with [x :?+y + z] [?+y: either flag? [[+ y]][]]`

**But it also has it's drawbacks:**
- Extensibility of it is not any better than defining global helpers for `compose`
- **/with block** in practice becomes **bigger** than it's COMPOSE variant's preparation code. This happens because /with builds an object out of the block, and object constructor does **not collect words deeply**, so they have to be declared at top level first:
  ```
    build/with [...][
        x: y: none
        either flag? [x: 1 y: 2][x: 2 y: 3]
    ]
  ```
  Another reason for the bloat, is because BUILD **can't substitute words not declared** in the object without `ins` or `only` (which are way less readable).<br>
  E.g. one has to **duplicate** already set values in the object:
  ```
    x: my-value
    build/with [... !x ...] [!x: :x]
  ```
  So while it keeps the build-expression readable, it does not reduce the overall complexity. It just **moves complexity from the expression into the /with block**.
- Apart from simple words, there's **no visual hint** where each substitution **starts or ends**.<br>
  E.g. `build [ins copy/part find block value back tail series then some code]` -- tip: `ins` eats it up to `then`, but you have to count arity in your mind to know that ;)
- `ins` and `only` (or any other user-defined transformation functions) are **incompatible with operators**<br>
  E.g. `build [x + ins pick [y y'] flag? + z]` -- will try to evaluate `flag? + z` and will fail. One can write `build [x + (ins pick [y y'] flag?) + z]` instead, but when building tight loops code, or frequently used function bodies, an extra paren matters. Besides that will only work for inserting a single value, not whole slices of code.

---
*The purpose of RESHAPE is to address all these limitations.*

## Key design principles of RESHAPE

- It's code consists of **2 columns:** *expressions* to the left and *conditions* to the right. This separation helps keep track of both the expression under construction, and conditions, and be able to connect both easily. For that to work without extra separators tokens, I had to make it **new-line aware**.<br>
  E.g.:
  ```
    this code is always included
    this code is included          /if flag?: this condition succeeds
    this is an alternate code      /if not flag?    ;) included if the last condition failed
  ```
- Unlikely coding patterns are used to **minimize the need to escape** anything:
  `@[...]` `@(...)` `/if ...` -- fat chance you will encounter these in normal Red.\
  `@` substitution marker is chosen because it visually stands out, which is important in bigger blocks.\
  `[]` indicates that block is inserted as a block (aligns with common /only meaning), `()` indicates splicing.
- **User-defined grammar** allows to nest `reshape` calls - useful when inner code must be reshaped sometime later
- Expressions to be substituted are wrapped in parens/block so their **limits are clearly visible** and contrast with the rest.<br>
  E.g. `@(copy/part find block value back tail series) then some code` -- can be used pretty much like `compose` and stay readable.
- `/if` controls what lines to include or not, **eliminating the need for preparation code**, at least in straighforward scenarios.
- There's **section-level** and **line-level** exclusion conditions so one can control inclusion on both levels.
- **Deep processing** of input, so that no extra calls to `reshape` are needed to expand nested blocks/parens (nested calls are rather ugly).
- Input is always copied deeply, so one can use static blocks.
