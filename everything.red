Red [
	title:   "Mezz hub"
	purpose: "Include every script in the repo"
	author:  @hiiamboris
]

#include %include-once.red
; #do [verbose-inclusion?: yes]

#process off											;-- this disables the retarded #include right here, so the other one kicks in
do/expand [												;-- without this trick, inclusion of this file from another file is gonna fail

#include %assert.red									;-- including it first will expand embedded assertions in the other scripts
; #assert off												;-- optionally uncomment this to disable assertions 
#include %debug.red

#include %with.red
#include %catchers.red
#include %composite.red
#include %error-macro.red
#include %print-macro.red
#include %hide-macro.red
#include %load-anything.red
#include %scoping.red
#include %embed-image.red
#include %stepwise-macro.red

#include %charsets.red
#include %setters.red
#include %bind-only.red
#include %without-gc.red
#include %median.red
#include %step.red	
#include %clip.red	
#include %extrema.red
#include %count.red
#include %modulo.red
#include %keep-type.red
#include %tabs.red
#include %split.red
#include %reshape.red
#include %match.red
#include %interleave.red
#include %quantize.red
#include %collect-set-words.red

#include %in-out-func.red	
#include %advanced-function.red
#include %typecheck.red
#include %classy-object.red
#include %reactor92.red
#include %search.red

#include %selective-catch.red
#include %forparse.red
#include %mapparse.red
#include %bind-only.red
#include %new-each.red
#include %sift-locate.red
#include %xyloop.red
#include %bulk.red	

#include %do-atomic.red
#include %do-unseen.red
#include %do-queued-events.red

#include %tree-hopping.red
#include %glob.red
#include %data-store.red
#include %relativity.red
#include %tabbing.red

#include %exponent-of.red
#include %format-number.red
#include %format-readable.red
#include %timestamp.red
#include %color-models.red
#include %contrast-with.red

#include %shallow-trace.red
#include %show-trace.red
#include %stepwise-func.red

#include %trace-deep.red
#include %expect.red
#include %show-deep-trace.red

#include %timers.red	
#include %leak-check.red
#include %prettify.red
#include %parsee.red
#include %profiling.red
#include %explore.red

]
#process on

