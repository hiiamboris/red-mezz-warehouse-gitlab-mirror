# `#composite` macro & `composite` mezz

[`composite`](composite.red) is an implementation of string interpolation. It's (probably sole) **advantage** over `rejoin` is **readability**. Compare:
```
cmd: #composite {red(flags) -o "(to-local-file exe-file)" "(to-local-file src-file)"}
cmd: rejoin ["red" flags { -o "} to-local-file exe-file {" "} to-local-file src-file {"}]
```

Like `compose`, `composite` expects expressions to be in parens. 

It supports **all string types**, e.g. it's useful for file names, thanks to the double quoted file syntax:
`#composite %"(key)-code.exe"` - the result is of `file!` type

It should also be useful for **tag** composition, but be careful that tags with double quotes inside may become unloadable.

To compose **urls**, we need different syntax than parens, as urls do not support non-encoded parens. So just use `as url! #composite "https://..."` trick.

## Macro version

I'm using it in the [Red View Test System repo](https://gitlab.com/hiiamboris/red-view-test-system) and I'm satisfied with it.
During macro expansion phase `#composite` macro simply **transforms** a given string **into a rejoin-expression**. 

**Benefits** of macro approach over a function implementation are:
- Huge benefit is that used expressions are **automatically bound** as expected, because macro expansion happens before any `bind` can be executed upon it. This makes it easy and natural to use, contrary to the function version that would have to receive a context (or multiple contexts) to bind it's words to and becomes so ugly that's it's not worth the effort using it.
- Another is runtime **performance**: expression is expanded only once, so any subsequent evaluations do not pay the expansion cost. And if you compile it, you pay the cost at compile time only.

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

## Mezz version

**Benefits**:
- Much **simpler** code.
- Can be used on **dynamically** generated or passed around strings, like any other function.
- No tripping on macro issues.

**Drawbacks**:
- Requires explicit binding info. See [`with` header](https://gitlab.com/hiiamboris/red-mezz-warehouse/-/blob/master/with.red) - usage is the same, and resembles usage of `bind`.
- Slower at runtime due to extra processing.

### Examples:
```
	prints: func [b [block!] s [string!]] [print composite b s]
	prints['msg] "error reading the config file: (mold msg)"			;) often requires duplication of variable name

	play: function [player root vfile afile] [
		...
		cmd: composite['root] get bind either afile ['avcmd]['vcmd] :a+v
		...
	]

	composite[] "system/words size = (length? words-of system/words)"	;) automatically bound to global context
```


## Design issues:

**Paren syntax** is great in 90% cases, but in some cases I *may forget* about parens special meaning and just put a "(comment)" in. Then get an error when the code gets evaluated ;) Also as examples show, escaping it is problematic (escaping always is). So an optional **alternate syntax** support may help **eliminate the need** for escaping anything, if it's worth it. Haven't decided on the escaping syntax though :/

What **features** should embedded expressions support? E.g. what about `"(#macros)"` or `"(;-- line comments)"` (latter is especially problematic to implement).

## ERROR macro

- is based on the `#composite` *macro* (because error strings are almost always immediate values)

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

## Localization

In my opinion, `#composite` will have a **big role to play when localization** work starts. Suppose we write a macro that replaces every string in the script with a local version. It's a piece of cake when `#composite` is used:
`#composite "A (type) message with (this value) and (another value) and more"` can get replaced by the translator as:
`#composite "Localized (another value) and (this value) and more (type) message"` - the order of things depends on the language/culture.

And imagine translator's dizziness when he sees:
```
"A "
" message with "
" and "
" and more"
```
coming from `rejoin ["A " type " message with " this value " and " another value " and more"]`

Not only `rejoin` leaves no option to reword the phrase properly, it also blocks any attempt to get the meaning of the message.

That's why I believe **`#composite` should be a part of Red runtime** and should be used for formatting values in error messages.

