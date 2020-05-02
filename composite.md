# #composite macro

`composite` is an implementation of string interpolation. It's (probably sole) **advantage** over `rejoin` is **readability**. Compare:
```
cmd: #composite {red(flags) -o "(to-local-file exe-file)" "(to-local-file src-file)"}
cmd: rejoin ["red" flags { -o "} to-local-file exe-file {" "} to-local-file src-file {"}]
```

This is a **macro implementation** of it, supporting only paren syntax (like `compose`). I'm using it in the [Red View Test System repo](https://gitlab.com/hiiamboris/red-view-test-system) and I'm satisfied with it.
During macro expansion phase `#composite` macro simply **transforms** a given string **into a rejoin-expression**.

It supports **all string types**, e.g. it's useful for file names, thanks to the double quoted file syntax:
`#composite %"(key)-code.exe"` - the result is of `file!` type

It should also be useful for **tag** composition, but be careful that tags with double quotes inside may become unloadable.

To compose **urls**, we need different syntax than parens, as urls do not support non-encoded parens. So just use `as url! #composite "https://..."` trick.

**Benefits** of macro approach over a function implementation are:
- Huge benefit is that used expressions are **automatically bound** as expected, because macro expansion happens before any `bind` can be executed upon it. This makes it easy and natural to use, contrary to the function version that would have to receive a context (or multiple contexts) to bind it's words to and becomes so ugly that's it's not worth the effort using it.
- Another is repeatable **performance**: expression is expanded only once, so any subsequent evaluations do not pay the expansion cost. And if you compile it, you pay the cost at compile time only.

**Drawbacks** compared to function implementation are:
- You cannot **pass around or build** the template strings at runtime. E.g. if you want to write a simple around `#composite` call, you have to make it a macro wrapper. So, formatting a dataset using a template won't work with a macro.
- Macros **loading is unreliable** right now (see the numerous issues on the tracker)
- If you have a lot of `composite` expressions, most of which are not going to ever be used by the program (like, composite error messages), then it's **only slower** than the function.

### Examples:
```
	stdout: #composite %"(working-dir)stdout-(index).txt"
	pid: call/shell #composite {console-view.exe (to-local-file name) 1>(to-local-file stdout)}
	log-info #composite {Started worker (name) ("(")PID:(pid)(")")}			;) note the natural escape mechanism: ("("), which looks like an ugly parrot
	#composite "Worker build date: (var/date) commit: (var2)^/OS: (system/platform)"
	write/append cfg-file #composite "config: (mold config)"
```

### Design issues:

**Paren syntax** is great in 90% cases, but in some cases I *may forget* about parens special meaning and just put a "(comment)" in. Then get an error when the code gets evaluated ;) Also as examples show, escaping it is problematic (escaping always is). So an optional **alternate syntax** support may help **eliminate the need** for escaping anything, if it's worth it.

What **features** should embedded expressions support? E.g. what about `"(#macros)"` or `"(;-- line comments)"` (latter is especially problematic to implement).

# ERROR macro

`ERROR "my composite (string)"` is simply a shortcut for: `do make error! #composite "my composite (string)"`, which I'm using a lot.

As all macros it is **case-sensitive!** (`error` and `Error` won't be affected).

Why `ERROR` and not `#error`? <br>
Because the preprocessor may easily fail to expand the macro (just look how many issues with it are on the tracker). In this case `#error` will just be skipped silently, propagating errors further, while `ERROR` will likely tell that the word is undefined.

### Examples:
```
	ERROR "Unexpected spec format (mold spc)"
	ERROR "command (mold-part/flat code 30) failed with:^/(form/part output 100)"
	ERROR "Images are expected to be of equal size, got (im1/size) and (im2/size)"
```

