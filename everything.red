Red [
	title:   "Mezz hub"
	purpose: "Include every script in the repo"
	author:  @hiiamboris
]

#include %include-once.red
#include %assert.red									;-- including it first will expand embedded assertions in the other scripts
; #assert off												;-- optionally uncomment this to disable assertions 
#include %debug.red

#include %with.red
#include %setters.red
#include %catchers.red
#include %extremi.red
#include %prettify.red
#include %reshape.red
#include %morph.red
#include %leak-check.red

#include %count.red
#include %collect-set-words.red
; #include %apply.red									;-- new-apply included by forparse.red
; #include %keep-type.red								;-- included by typecheck.red
#include %typecheck.red

; #include %selective-catch.red							;-- included by forparse.red
#include %forparse.red
; #include %composite.red								;-- included by error-macro.red
; #include %error-macro.red								;-- included by for-each.red
; #include %bind-only.red								;-- included by for-each.red
; #include %for-each.red								;-- included by map-each.red
#include %map-each.red
#include %xyloop.red									;-- included by explore.red
#include %relativity.red								;-- included by explore.red
; #include %explore.red									;@@ temporary

#include %clock.red
; #include %shallow-trace.red							;-- included by clock-each.red & show-trace.red & stepwise-func.red
#include %clock-each.red
; #include %show-trace.red								;-- unlikely needed given now available trace mezz
#include %stepwise-func.red

; #include %trace-deep.red								;-- included by expect.red & show-deep-trace.red
#include %expect.red
; #include %show-deep-trace.red							;-- unlikely needed given now available trace mezz

; #include %format-number.red							;-- included by timestamp.red
; #include %stepwise-macro.red							;-- included by timestamp.red
#include %timestamp.red
#include %tabs.red
#include %modulo.red
#include %print-macro.red

#include %glob.red

#include %do-atomic.red
#include %do-queued-events.red
#include %contrast-with.red
#include %is-face.red

