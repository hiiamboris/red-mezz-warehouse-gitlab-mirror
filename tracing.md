# Debugging your code with enhanced TRACE function

With [new instrumentation](https://github.com/red/docs/blob/master/en/interp-events.adoc) it became possible to dive into blocks of code evaluated by control flow constructs, opening way for evaluation tracing.

Enhanced [trace function](https://gitlab.com/hiiamboris/red-mezz-warehouse/-/blob/master/better-trace.red) prints user-friendly evaluation log, helping nail down errors and figure out how our code really behaves, where it's behavior is different from our expectations.

## Examples

### Tracing whole expressions with `trace/here`

`/here` is the most concise of tracing modes, which only traces the *visible* code.

Scenarios:
- error happened at some line of code, need to know which one
- final result is wrong in some [huge function](https://github.com/hiiamboris/red-formatting/blob/a0e4fdb3c1498a1ccdafae342e2818bfda660033/format-number-with-mask.red#L586) and you want to see all intermediate computations line by line to find out where the error originates from
- you're #including a bunch of files, each of which also includes a bunch of files, leading to a huge cascade, and an error just says *"hey, `do` errored out with some `none` thing somewhere"*

Example test code, contains an obvious error in the last line (in real code it's usually not that obvious ;):
```
my-func: func [x] [
	print "print from my-func"
	if 1 < x [
		uppercase pick "xy" random true
	]
]

trace/here [
	op: make op! func [:x :y][:y]
	do op 1 + 2
	if 1 + 1 < add 2 + 3 4 [add 5 6]
	b: [x y z]
	j: 1 + 1
	to-integer "123"
	if 1 < 2 [3]
	do [
		j: (1 + 1 * 1)
		select b b/:j
	]
	my-func 1 + 2
	this-is-an-error!
]
```

`trace/here` will output every expression and it's result:

<pre>
    op: make op! func [:x :y] [:y]  => make op! func [:x :y][:y]            
    do op 1 + 2                     => 3                                    
  ````IF 1 + 1 < add 2 + 3 4 [add 5 6]``````````````````````````````````````
      add 5 6                       => 11                                   
  ``````````````````````````````````````````````````````````````````````````
    if 1 + 1 < add 2 + 3 4 [add ... => 11                                   
    b: [x y z]                      => [x y z]                              
    j: 1 + 1                        => 2                                    
    to-integer "123"                => 123                                  
  ````IF 1 < 2 [3]``````````````````````````````````````````````````````````
      3                             => 3                                    
  ``````````````````````````````````````````````````````````````````````````
    if 1 < 2 [3]                    => 3                                    
  ````DO [j: (1 + 1 * 1) select b b/:j]`````````````````````````````````````
      j: (1 + 1 * 1)                => 2                                    
      select b b/:j                 => z                                    
  ``````````````````````````````````````````````````````````````````````````
    do [j: (1 + 1 * 1) select b ... => z                                    
print from my-func
    my-func 1 + 2                   => #"X"                                 
    this-is-an-error!               => make error! [code: 300 type: 's...]  
*** Script Error: this-is-an-error! has no value
*** Where: do
*** Stack: 
</pre>

<code>``````</code> lines show:
- path of called functions so far
- expression that resulted in reaching the current current scope

Other lines are expressions and their results.

`???` macro can be used instead of wrapping code into `trace/here [..]`. It's easy to insert anywhere. Example (using the same `my-func` definition):
```
do [
	op: make op! func [:x :y][:y]
	do op 1 + 2
	if 1 + 1 < add 2 + 3 4 [add 5 6]
	b: [x y z]
	j: 1 + 1
	to-integer "123"
	if 1 < 2 [3]
	???							;) tracing starts here
	do [
		j: (1 + 1 * 1)
		select b b/:j
	]
	my-func 1 + 2
	this-is-an-error!
]
```

Output:
<pre>
  ````DO [j: (1 + 1 * 1) select b b/:j]`````````````````````````````````````
      j: (1 + 1 * 1)                => 2                                    
      select b b/:j                 => z                                    
  ``````````````````````````````````````````````````````````````````````````
    do [j: (1 + 1 * 1) select b ... => z                                    
print from my-func
    my-func 1 + 2                   => #"X"                                 
    this-is-an-error!               => make error! [code: 300 type: 's...]  
*** Script Error: this-is-an-error! has no value
*** Where: do
*** Stack: 
</pre>

### Deeply tracing expressions with `trace/deep`

Sometimes it may be useful to get the whole picture at the expense of more verbose logging. Some line fails, but leads to a function, and you also wanna know why that function failed.

`/deep` is like `/here` but will descend into all called functions and print their expressions as well. Using the previous example:
```
my-func: func [x] [
	print "print from my-func"
	if 1 < x [
		uppercase pick "xy" random true
	]
]

trace/deep [
	op: make op! func [:x :y][:y]
	do op 1 + 2
	if 1 + 1 < add 2 + 3 4 [add 5 6]
	b: [x y z]
	j: 1 + 1
	to-integer "123"
	if 1 < 2 [3]
	do [
		j: (1 + 1 * 1)
		select b b/:j
	]
	my-func 1 + 2
	this-is-an-error!
]
```

The output now contains everything from inside `my-func`:

<pre>
    op: make op! func [:x :y] [:y]  => make op! func [:x :y][:y]            
  ````OP do op 1````````````````````````````````````````````````````````````
      :y                            => 1                                    
  ``````````````````````````````````````````````````````````````````````````
    do op 1 + 2                     => 3                                    
  ````IF 1 + 1 < add 2 + 3 4 [add 5 6]``````````````````````````````````````
      add 5 6                       => 11                                   
  ``````````````````````````````````````````````````````````````````````````
    if 1 + 1 < add 2 + 3 4 [add ... => 11                                   
    b: [x y z]                      => [x y z]                              
    j: 1 + 1                        => 2                                    
    to-integer "123"                => 123                                  
  ````IF 1 < 2 [3]``````````````````````````````````````````````````````````
      3                             => 3                                    
  ``````````````````````````````````````````````````````````````````````````
    if 1 < 2 [3]                    => 3                                    
  ````DO [j: (1 + 1 * 1) select b b/:j]`````````````````````````````````````
      j: (1 + 1 * 1)                => 2                                    
      select b b/:j                 => z                                    
  ``````````````````````````````````````````````````````````````````````````
    do [j: (1 + 1 * 1) select b ... => z                                    
print from my-func
  ````MY-FUNC 1 + 2`````````````````````````````````````````````````````````
      print "print from my-func"    => unset                                
  ``````MY-FUNC/IF 1 < x [uppercase pick "xy" random true]``````````````````
        uppercase pick "xy" rand... => #"X"                                 
  ````MY-FUNC 1 + 2`````````````````````````````````````````````````````````
      if 1 < x [uppercase pick "... => #"X"                                 
  ``````````````````````````````````````````````````````````````````````````
    my-func 1 + 2                   => #"X"                                 
    this-is-an-error!               => make error! [code: 300 type: 's...]  
*** Script Error: this-is-an-error! has no value
*** Where: do
*** Stack: 
</pre>

<code>``````</code> lines become irreplaceable in such logs as they help connect expressions with their context.

### Tracing sub-expressions with `trace/all`

Typical scenarios:
- `#assert` test fails, but contains at what point exactly is not known
- code contains a complex expression which fails as a whole, but will take some time to find out

Example: a convoluted Caesar's cipher function that contains a non-obvious bug: 
```
buggy-caesar: function [s k] [
    a: charset [#"a" - #"z" #"A" - #"Z"]
    forall s [if find a s/1 [s/1: (x: s/1 % 32) + k + 25 % 26 + 1 + (s/1 - x)]] s
]
```
Trying it in console shows that it doesn't always work:
```
>> buggy-caesar "abc" 1
== "bcd"
>> buggy-caesar "abc" -1
== "zab"
>> buggy-caesar "abc" 25
== "zab"
>> buggy-caesar "abc" -25
*** Math Error: math or number overflow
*** Where: +
*** Stack: buggy-caesar  

>> buggy-caesar "a" -25
*** Math Error: math or number overflow
*** Where: +
*** Stack: buggy-caesar  
```
The error doesn't tell us much. There are multiple `+` operators. To find the bug you would normally have to insert `probe` before each intermediate result, adding parens as necessary, leading to something like:
`if find a s/1 [s/1: (probe (probe (probe (probe (probe x: s/1 % 32) + (probe k)) + 25) % 26) + 1) + (probe s/1 - x)]`

And then trying to map the printed results back to each expression.

`trace/all` can do all that for you:
```
buggy-caesar: function [s k] [
    a: charset [#"a" - #"z" #"A" - #"Z"]
    trace/all [
	    forall s [if find a s/1 [s/1: (x: s/1 % 32) + k + 25 % 26 + 1 + (s/1 - x)]] s
    ]
]
```
Outputs:
```
      a                             => make bitset! #{00000000000000007...  
        s                           => "a"                                  
      find a s/1                    => true                                 
            s                       => "a"                                  
          x: % s/1 32               => #"^A"                                
        k                           => -25                                  
        + (x: s/1 % 32) k           => make error! [code: 401 type: 'm...]  
*** Math Error: math or number overflow
*** Where: +
*** Stack: 
```

Now we can see that `x: % s/1 32` is `#"^A"` (which is integer 1), and we're adding `k` to it, which is `-25`, and `-24` is just out of the allowed range for `char!` type. We can easily fix it by swapping `+ k` and `+ 25`:
```
caesar: function [s k] [
    a: charset [#"a" - #"z" #"A" - #"Z"]
    forall s [if find a s/1 [s/1: (x: s/1 % 32) + 25 + k % 26 + 1 + (s/1 - x)]] s
]
```
Trying again:
```
>> caesar "abc" -1
== "zab"
>> caesar "abc" -25
== "bcd"
>> caesar caesar "abc" 25 -25
== "abc"
```
It works!
 