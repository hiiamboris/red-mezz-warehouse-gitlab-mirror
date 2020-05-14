# A collection of my Red mezzanines & macros

Some of these are trivial. Some may look simple in code, but are a result long design process. Some are only emerging experiments. See headers of each file for usage, info, design info!

Notes:
- most scripts are standalone, I tried to keep dependencies at minimum
- mostly untested for compileability so far; optimized for the interpreted use
- use `#include %everything.red` to include all the scripts at once and play

**Navigate by category:**
* [General purpose](#general-purpose)
* [Series-related](#series-related)
* [Loops](#loops)
* [Debugging](#debugging)
* [Profiling](#profiling)
* [Formatting](#formatting)
* [String interpolation](#string-interpolation)
* [Filesystem scanning](#filesystem-scanning)
* [Graphics & Reactivity](#graphics-reactivity)


## By category:

### General purpose
| Source file                            | Description |
| ---                                    | --- |
| [setters](setters.red)                 | Contains ONCE, DEFAULT, MAYBE value assignment wrappers, and IMPORT to expose some object's words globally |
| [with](with.red)                       | A convenient/readable BIND variant |
| [bind-only](bind-only.red)             | Selectively bind a word or a few only |
| [apply](apply.red)                     | Call a function with arguments specified as key-value pairs |
| [timestamp](timestamp.red)             | Ready-to-use and simple timestamp formatter for naming files |
| [stepwise-macro](stepwise-macro.red) and [stepwise-func](stepwise-func.red) | Allows you write long compound expressions as a sequence of steps |
| [trace](trace.red)                     | Step-by-step evaluation of a block of expressions with a callback |
| [trace-deep](trace-deep.red)           | Step-by-step evaluation of each sub-expression with a callback |
| [selective-catch](selective-catch.red) | Catch `break`/`continue`/etc. - for use in building custom loops |
| [prettify](prettify.red)               | Automatically fill some (possibly flat) code with new-line markers for readability |
| [reshape](reshape.red)                 | Advanced code construction dialect to replace `compose` and `build`. [Read more](reshape.md) |

### Series-related
| Source file                                | Description |
| ---                                        | --- |
| [extremi](extremi.red)                     | Find minimum and maximum points over a series |
| [count](count.red)                         | Count occurences of an item in the series |
| [keep-type](keep-type.red)                 | Filter list using accepted type or typeset |
| [collect-set-words](collect-set-words.red) | Deeply collect set-words from a block of code |

### Loops
| Source file                                | Description |
| ---                                        | --- |
| [xyloop](xyloop.red)                       | Iterate over 2D area - image or just size |
| [forparse](forparse.red)                   | Leverage parse power to filter series |
| [for-each](for-each.red)                   | Experimental design of an extended FOREACH |
| [map-each](map-each.red)                   | Map one series into another, leveraging FOR-EACH power |

Interestingly, `for-each` and `map-each` code showcases how limited `compose` is when building complex nested code with a lot of special cases.
It works, but uglifies it so much that a question constantly arises: can we do something better than `compose`?
These two functions will serve as a great playground for such an experiment.

### Debugging
| Source file                            | Description |
| ---                                    | --- |
| [debug](debug.red)                     | Simple macro to include some debug-mode-only code/data |
| [assert](assert.red)                   | Allow embedding sanity checks into the code, to limit error propagation and simplify debugging |
| [expect](expect.red)                   | Test a condition, showing full backtrace when it fails |
| [show-trace](show-trace.red)           | Example TRACE wrapper that just prints the evaluation log to console |
| [show-deep-trace](show-deep-trace.red) | Example TRACE-DEEP wrapper that just prints the evaluation log to console |

### Profiling
| Source file                  | Description |
| ---                          | --- |
| [clock](clock.red)           | Simple, even minimal, mezz for timing code execution |
| [clock-each](clock-each.red) | Allows you to profile each expression in a block of code |

### Formatting
| Source file                        | Description |
| ---                                | --- |
| [format-number](format-number.red) | Simple number formatter with the ability to control integer & fractional parts size |

### String interpolation
| Source file                        | Description |
| ---                                | --- |
| [composite](composite.red)         | String interpolation using the preprocessor. [Read more](composite.md) |
| [error-macro](error-macro.red)     | Shortcut for raising an error using string interpolation for the message |

### Filesystem scanning
| Source file                  | Description |
| ---                          | --- |
| [glob](glob.red)             | Allows you to recursively list files. [Read more](glob.md). [Run tests](glob-test.red) |

### Graphics & Reactivity
| Source file                              | Description |
| ---                                      | --- |
| [relativity](relativity.red)             | Face coordinate systems translation mezzanines |
| [contrast-with](contrast-with.red)       | Pick a color that would contrast with the given one |
| [do-queued-events](do-queued-events.red) | Flush the View event queue |
| [do-atomic](do-atomic.red)               | Atomically execute a piece of code that triggers reactions |
| [explore](explore.red)                   | Show UI to explore an image in detail (TODO: support any Red value) |
