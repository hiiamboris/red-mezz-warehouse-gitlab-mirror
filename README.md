---
gitea: none
include_toc: true
---

Official URL of this project: [https://codeberg.org/hiiamboris/red-common](https://codeberg.org/hiiamboris/red-common)

# A collection of my Red mezzanines & macros

Some of these are trivial. Some may look simple in code, but are a result long design process. Some are only emerging experiments. **See headers** of each file for usage, info, design info!

Notes:
- I try to keep dependencies at minimum for simpler inclusion, until it stops making sense  
- mostly untested for compileability so far; optimized for the interpreted use
- use `#include %everything.red` to include all the scripts at once and play

## By category

### General purpose
| Source file                                | Description |
| ---                                        | --- |
| [setters](setters.red)                     | Contains ONCE, DEFAULT, MAYBE, QUIETLY, ANONYMIZE value assignment wrappers, and GLOBAL/EXPORT to expose some object's words globally |
| [with](with.red)                           | A convenient/readable BIND variant |
| [#hide macro](hide-macro.red)              | Automatic set-word and loop counter hiding |
| [stepwise-macro](stepwise-macro.red) and [stepwise-func](stepwise-func.red) | Allows you write long compound expressions as a sequence of steps |
| [trace](trace.red)                         | Step-by-step evaluation of a block of expressions with a callback |
| [trace-deep](trace-deep.red)               | Step-by-step evaluation of each sub-expression with a callback |
| [selective-catch](selective-catch.red)     | Catch `break`/`continue`/etc. - for use in building custom loops |
| [reshape](reshape.red)                     | Advanced code construction dialect to replace `compose` and `build`. [Read more](reshape.md) |
| [without-GC](without-gc.red)               | Evaluate code with GC temporarily turned off (brings massive speedup when used wisely) |
| [scoping](scoping.red)                     | Primitive experimental support for scope-based resource lifetime management |
| [timers](timers.red)                       | Fast general-purpose timers (independent from View) |

### Design extensions and fixes
| Source file                                | Description |
| ---                                        | --- |
| [#include macro](include-once.red)         | Smart replacement for #include directive that includes every file only once |
| [\#\# macro](load-anything.red)            | Macro for arbitrary load-time evaluation, to be able to save and load any kind of value |
| [bind-only](bind-only.red)                 | Selectively bind a word or a few only |
| [catchers](catchers.red)                   | TRAP - enhanced TRY, FCATCH - Filtered catch, PCATCH - Pattern-matched catch, FOLLOWING - guaranteed cleanup |
| [classy object](classy-object.red)         | Object 'class' support that adds type checks and per-word on-change functions to objects |
| [typed object](typed-object.red)           | Simple per-object type checks support |
| [advanced function](advanced-function.red) | Support for value checks and defaults in FUNCTION's spec argument |

### Math
| Source file                                | Description |
| ---                                        | --- |
| [step](step.red)                           | Increment & decrement function useful for code readability |
| [clip](clip.red)                           | Contain a value within given range |
| [exponent-of](exponent-of.red)             | Compute exponent of a number (i.e. how many digits it has) |
| [quantize](quantize.red)                   | Quantize a float sequence into rounded bits (e.g. to get an integer vector) |
| [extrema](extrema.red)                     | Find minimum and maximum points over a series |
| [median](median.red)                       | Find median value of a sample |
| [count](count.red)                         | Count occurences of an item in the series |
| [modulo](modulo.red)                       | Working modulo implementation with tests |
| [timestamp](timestamp.red)                 | Ready-to-use and simple timestamp formatter for naming files |

### Series-related
| Source file                                | Description |
| ---                                        | --- |
| [split](split.red)                         | Generalized series splitter |
| [join](join.red)                           | Join a list as a string |
| [delimit](delimit.red)                     | Insert a delimiter between all list items or interleave two lists |
| [match](match.red)                         | Mask based pattern matching for strings (used by GLOB) |
| [keep-type](keep-type.red)                 | Filter list using accepted type or typeset |
| [sift & locate](sift-locate.red)           | High level dialected series filter and finder [Read more](sift-locate.md) |
| [collect-set-words](collect-set-words.red) | Deeply collect set-words from a block of code |
| [morph](morph.red)                         | Dialect for persistent local series mapping. [Read more](morph.md) |

### Loops
| Source file                                | Description |
| ---                                        | --- |
| [xyloop](xyloop.red)                       | Iterate over 2D area - image or just size |
| [forparse](forparse.red)                   | Leverage parse power to iterate over series |
| [mapparse](mapparse.red)                   | FORPARSE-based mapping over series |
| [for-each](new-each.red)                   | Powerful version of FOREACH, covering most use cases |
| [map-each](new-each.red)                   | Map one series into another, leveraging FOR-EACH power |
| [remove-each](new-each.red)                | Extends native REMOVE-EACH with FOR-EACH syntax and fixes its bugs |
| [bulk](bulk.red)                           | Bulk evaluation syntax support. [Read more](https://github.com/greggirwin/red-hof/tree/master/code-analysis#bulk-syntax) |
| [search](search.red)                       | Find root of a function with better than linear complexity. Supports [binary / bisection](https://en.wikipedia.org/wiki/Binary_search_algorithm), [interpolation / false position](https://en.wikipedia.org/wiki/Interpolation_search) and [jump](https://en.wikipedia.org/wiki/Jump_search) search. |
| [foreach-node](tree-hopping.red)           | Tree visitor pattern support (for building all kinds of tree iterators) |

### Debugging

These functions mainly help one follow design-by-contract guidelines in one's code.

| Source file                            | Description |
| ---                                    | --- |
| [debug](debug.red)                     | Simple macro to include some debug-mode-only code/data |
| [assert](assert.red)                   | Allow embedding sanity checks into the code, to limit error propagation and simplify debugging. [Read more](assert.md) |
| [typecheck](typecheck.red)             | Mini-DSL for type checking and constraint validity insurance |
| [expect](expect.red)                   | Test a condition, showing full backtrace when it fails |
| [show-trace](show-trace.red)           | Example TRACE wrapper that just prints the evaluation log to console |
| [show-deep-trace](show-deep-trace.red) | Example TRACE-DEEP wrapper that just prints the evaluation log to console |
| [shallow-trace](shallow-trace.red)     | Basic step by step expression evaluator |
| [parsee](parsee.red)                   | Parse visual debugger. [Read more](https://codeberg.org/hiiamboris/red-spaces/src/branch/master/programs/README.md#parsee-parsing-flow-visual-analysis-tool-parsee-tool-red) |

### Profiling
| Source file                  | Description |
| ---                          | --- |
| [profiling](profiling.red)   | Inline profiling macros and functions (documented in the header) |

### Formatting
| Source file                            | Description |
| ---                                    | --- |
| [entab & detab](tabs.red)              | Tabs to spaces conversion and back |
| [format-number](format-number.red)     | Simple number formatter with the ability to control integer & fractional parts size |
| [format-readable](format-readable.red) | Experimental advanced number formatter targeted at human reader (used by the profiler). For a better design see the [Format module](https://github.com/red/red/pull/5069) |
| [prettify](prettify.red)               | Automatically fill some (possibly flat) code with new-line markers for readability |

### String interpolation
| Source file                        | Description |
| ---                                | --- |
| [composite macro & mezz](composite.red) | String interpolation both at run-time and load-time. [Read more](composite.md) |
| [ERROR macro](error-macro.red)     | Shortcut for raising an error using string interpolation for the message. [Read more](https://gitlab.com/hiiamboris/red-mezz-warehouse/-/blob/master/composite.md#error-macro) |
| [#print macro](print-macro.red)    | Shortcut for `print #composite` |

### Filesystem related
| Source file                          | Description |
| ---                                  | --- |
| [glob](glob.red)                     | Allows you to recursively list files. [Read more](glob.md). [Run tests](glob-test.red) |
| [data-store context](data-store.red) | Standardized zero-fuss loading and saving of data, config and other state (documented in the header) |

### Graphics & Reactivity
| Source file                              | Description |
| ---                                      | --- |
| [relativity](relativity.red)             | Face coordinate systems translation mezzanines |
| [color-models](color-models.red)         | Reliable statistically neutral conversion between common color models |
| [contrast-with](contrast-with.red)       | Pick a color that would contrast with the given one |
| [is-face?](is-face.red)                  | Reliable replacement for FACE? which doesn't work on user-defined faces |
| [do-queued-events](do-queued-events.red) | Flush the View event queue |
| [do-atomic](do-atomic.red)               | Atomically execute a piece of code that triggers reactions |
| [do-unseen](do-unseen.red)               | Disable View redraws from triggering during given code evaluation |
| [reactor92](reactor92.red)               | A higher level `on-deep-change*` replacement based on [REP 92](https://github.com/red/REP/issues/92) |
| [embed-image](embed-image.red)           | Macro to compile images into exe |
| [explore & image-explorer style](explore.red) | Show UI to explore an image in detail (TODO: support any Red value) |
| [scrollpanel style](scrollpanel.red)     | Automatic scrolling capability to a panel, until such is available out of the box. [Read more](scrollpanel.md) |
| [tabbing support](tabbing.red)           | Simpler and extensible replacement for native tabbing support (extended when using [Spaces](https://codeberg.org/hiiamboris/red-spaces/)) |

### Utilities
| Source file                              | Description |
| ---                                      | --- |
| [leak-check](leak-check.red)             | Find words leaking from complex code |
| [bmatch](bmatch.red)                     | Bracket matching for Red sources (see [CLI implementation](https://codeberg.org/hiiamboris/red-cli/src/branch/master/mockups/bmatch)) |

### Implementations not yet incorporated into the whole
| Source file                            | Description |
| ---                                    | --- |
| [map, fold, scan, sum, partition (external)](https://github.com/greggirwin/red-hof/tree/master/mapfold) | Fast FP-like HOFs, as alternative to dialected \*each (routines, require compilation) |
| [new replace](new-replace.red)         | Based on the new apply, but awaits team consensus on design (see [REP 146](https://github.com/red/REP/issues/146)) |

