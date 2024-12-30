Red [title: "Standalone version of the ParSEE backend"]

;; keep includes from spilling out
set [parsee: parse-dump: inspect-dump:]
	reduce bind [:parsee :parse-dump :inspect-dump]
	context [
		#include %include-once.red
		#include %assert.red
		#include %setters.red									;-- `anonymize`
		#include %with.red
		#include %catchers.red
		#include %composite.red
		#include %error-macro.red
		#include %advanced-function.red							;-- `function` (defaults)
		#include %composite.red									;-- interpolation in print/call
		#include %catchers.red									;-- `following`
		#include %stepwise-macro.red
		#include %exponent-of.red
		#include %format-number.red
		#include %timestamp.red									;-- for dump file name
		#include %reactor92.red									;-- for changes tracking
		#include %without-gc.red
		#include %xyloop.red
		#include %tree-hopping.red								;-- for cloning data
		#include %data-store.red								;-- for config load/save
		#include %parsee.red
	]
	