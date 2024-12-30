Red [
	title:    "General purpose timers"
	purpose:  "Provide an efficient and decoupled from View timer implementation"
	author:   @hiiamboris
	license:  BSD-3
	provides: timers
	depends:  advanced-function
	notes: {

		Rationale:
			Timers scheduling can be done in time proportional to:
			- total number of timers in the system
			- number of active timers in the system
			- number of actual timer evaluations
			
			This implementation orchestrates timers in a way to achieve the latter.
			So, 10K slow timers should not put a significant load on it.
			With some tuning (higher timetable, less resolution), even 100K may be handled in a fraction of CPU time.
			
			It was initially designed for Spaces, but was plugged out for being an orthogonal design.
			

		Performance:
			The default configuration here aims at the most common situation:
			- resolution up to 1ms is achievable (common on Linux and on Windows desktop PCs)
			- majority of timers run faster than once per second
			
			With this config, on my Windows laptop where OS timer runs every 16ms (a typical condition):
			- 100K of 1min timers (never fired) are handled in 10% of CPU time
			- 10K of 250ms timers are handled in 20% of CPU time
			- 1K  of 250ms timers are handled in 2.5% of CPU time
			- 1K  of 20ms  timers are handled in 15% of CPU time
			For comparison, here are native View-based timers performance on the same laptop:
			- 100 of 20ms  timers are handled in 15% of CPU time (10x slower)
			- 1K  of 250ms timers are handled in 15% of CPU time (7x slower)
			
			The lesson is: timers are expensive and should be used sparingly.
		

		Implementation:
			To avoid interaction with the timers that are not going to fire right now, this design uses a timetable.
			Timetable is a sequence of slots, by default 1000 slots each corresponding to 1ms.
			Once a timer is scheduled or rescheduled it is put into a corresponding slot ahead.
			A slot is just a list (block!) of timers to evaluate inside this particular 1ms interval.
			
			To properly handle slow timers (>1sec) each timer stores a moment of its next planned evaluation.
			It is checked against the current time to verify if the timer is ready or not.
			
			Periods when no timer was active are automatically skipped using the internal active timer counter.
			
			An alternative design was considered where instead of putting timer into a map, a unique ID is used.
			Besides being less straighforward and ugly in code due to constant /same/only/skip 2 suffix, it's 50-200% slower.
			
			
		Real rate:
			It's possible to clog the pipeline if timer's rate is higher than it's evaluation speed.
			That is, when next timer's scheduled time comes before it finishes to evaluate itself.
			To avoid this, timer is rescheduled not from its starting time but from its ending time.
			Thus, real rate of a single timer is 1.0 / (timer/period + timer-evaluation-time)
			which gets dominated by the evaluation time when it becomes big.
			For an ensemble of timers it's trickier: one slow timer will delay all the others.
			

		Usage:
			One can create any number of timers, then they must be armed to become active.
			After that, `fire` function must be called in some loop to evaluate the timers.
			
			Example:
				timers/arm my-timer: timers/create 10 [print now/precise]
				limit: now/precise + 0:0:3
				while [now/precise < limit] [wait 0.001  timers/fire]

			Should output the current time a little less than 30 times (see 'Real rate' on why)


		API:			
			TIMERS context exposes the following public functionality:
			
			timers/create <rate> <code> -> <timer>
				Returns a new timer (map!) with given rate and code block to evaluate.
				map! is chosen as being much lighter than the object (RAM-wise).
				
				An existing timer should not be modified by the user.
				The timer is created inactive (needs arming).
				Inactive timers do not affect performance and can exist in any quantities.
				
			timers/arm <timer>
				Enables an existing timer (result of /create) to be evaluated.
				Timer will be scheduled to run at a time (now + timer/period).
				
				This first fire time is important e.g. in Spaces,
				where a click and hold of a scrollbar's button must produce events every 250ms from the click time.
				Without it, it would randomly fire anywhere within the next 250ms regardless of the click time.
				 
			timers/disarm <timer>
				Disables evaluation of an existing timer until next /arm.
				This is necessary to remove no longer needed timers from the timetable.
				
			timers/fire
				Evaluates all timers that are ready at this moment in time.
				To be run in a loop, similarly to do-events/no-wait.
				MUST NOT be called from within timer code!
				
			timers/fast-forward
				Skips all pending timer events until current moment.
				Called internally when first timer is activated, to skip time when no timers were active.
			
			timers/config/slots
				An integer! number of slots in the timetable (default: 1000).
				
				Each slot corresponds to a delay equalling to timers/config/resolution.
				More slots leads to more CPU time to loop over them.
				Less slots leads to slow timers being iterated over more than once.
				
			timers/config/resolution
				A time! value indicating a period each timetable slots corresponds to (default: 1ms).
				
				No timer can run at resolution higher than this global setting.
				A day (24 hours) must be wholly divisible by (resolution * slots) value.
				(resolution * slots) should ideally be bigger than the most commonly used timer period. 
				
			Tip: to get a delay of current timer's evaluation in % of its period, use:
				100% * ((difference timers/time timer/planned) / timer/period)	;) should always be >= 0% (an ideal value)
				
				timers/time is set to now/utc/precise before the timer's evaluation,
				so you don't have to call `now` again (it's quite slow on this scale).
	}
]


; #include %assert.red
; #include %advanced-function.red


timers: context [
	;; scheduling data:
	timetable:  []												;-- contains all scheduled timers
	fired:		0.0												;-- (in-day offset) when the timers were last processed
	
	;; optimization primitives:
	numbers:    []												;-- integers sequence, covering timetable twice
	spare: copy []												;-- spare block for use during fire-timers
	dayspan:	1.0												;-- how many times 'resolution' fits into 24 hours (computed later)
	count:		0												;-- number of active timers (to auto-skip periods of inactivity)
	time:		now/utc/precise									;-- last known time (can be used from the timers code instead of slow 'now')
	
	;; exposed for user's fine-tuning when needed:
	;; ideally a day should be divisible by resolution * slots, else there may be a slight glitch at midnight
	;; no timer may run more often than the config/resolution!
	config: reactor [
		resolution:	0:0:0.001									;-- minimum recognized delay (1ms by default)
		slots:		1000										;-- number of resolution-wide delays to fit in the timetable
	]
	
	reconfigure: function ["Disarm all timers and rebuild the timetable"] [
		clear numbers
		repeat i config/slots [append numbers i]				;@@ use map-each 
		append numbers numbers 
		self/timetable: copy/deep append/only/dup clear timetable [] config/slots	;@@ use map-each
		self/dayspan:   24:00 / config/resolution
		#assert [24:00 % (config/resolution * config/slots) = 0:0:0]
		#assert [2 * config/slots = length? numbers]
	]
	react [config/slots reconfigure]							;-- rebuild it when the number of slots changes

	time->slot: function [
		"Convert a moment in time into a corresponding slot in the timetable"
		time    [date!]
		return: [integer!]
	][
		(to integer! time/time / config/resolution) % config/slots + 1
	]
	
	;; inlined, because function call itself slows it down
	; time->offset: function [
		; "Convert a moment in time into a zero-based in-day offset (as float!)"
		; time    [date!]
		; return: [float!]
	; ][
		; round/floor time/time / config/resolution
	; ]
	
	;; public API

	create: function [
		"Create and return a new timer"
		rate    [time! integer! float!] "Rate (number) or period (time)" (positive? rate)
		code    [block!] "Expression that will be evaluated"	;@@ maybe expression itself is the timer? can it be unique?
		return: [map!]   "Returned timer is read-only"
	][
		timer:  make map! 3
		period: either time? rate [rate][0:0:1 / rate]
		timer/period:  period
		timer/code:    code
		timer/planned: none										;-- next run date; created inactive
		timer
	]
	
	arm: function [
		"Activate the timer (if inactive) so it fires a period from now and on"
		timer   [map!]
		/now    "Make it fire ASAP (if inactive only)"
		return: [map!]
		/extern count
	][
		unless timer/planned [
			#assert [timer/period >= config/resolution]			;-- faster timers are not supported (will run at resolution anyway)
			time: system/words/now/utc/precise
			timer/period:  max timer/period config/resolution	;@@ this won't be restored if resolution gets better
			timer/planned: time + either now [0][timer/period]
			slot: time->slot timer/planned
			append timetable/:slot timer
			if count = 0 [fast-forward/until time]				;-- provide 'time' to ensure it doesn't fast-forward over the current timer
			count: count + 1
			#assert [any [not now  slot > (fired % config/slots)]]	;-- /now should not be skipped
		]
		timer													;-- for chaining: `my-timer: arm create ...`
	]
	
	disarm: function [
		"Deactivate the timer (if active), stopping it from further evaluation"
		timer   [map!]
		return: [map!]
		/extern count
	][
		if timer/planned [
			slot: time->slot timer/planned
			remove find/same timetable/:slot timer				;@@ use O(1) removal or pointless?
			timer/planned: none
			count: count - 1
			#assert [count >= 0]
		]
		timer													;-- for symmetry with `arm`
	]
	
	fast-forward: function [
		"Skip all pending timer events"
		/until time: now/utc/precise [time!] "Manually provide the moment to skip to"
	][
		self/fired: round/floor time/time / config/resolution
	]

	;@@ should it check for (UTC) time monotony?
	fire: function ["Evaluate all pending timers" /extern spare fired time] [
		time:   now/utc/precise
		offset: round/floor time/time / config/resolution		;-- if time is monotonic, /floor ensures arm/now success
		if offset = fired [return false]
		; ?? offset ?? fired ?? dayspan
		
		indices: skip numbers to integer! fired % config/slots
		repeat i n: offset - fired // dayspan [					;-- this assumes that timer runs more often than once a day
			i: any [
				indices/:i										;-- optimization for the most common case
				to integer! fired + i - 1 % config/slots + 1	;-- fallback for correct handling of big (> 1 sec) delays
			]
			; unless timetable/:i [?? i ?? timetable]
			if tail? timetable/:i [continue]
			
			queue: timetable/:i									;@@ use swap when available in runtime
			timetable/:i: spare									;-- queue is needed in case timers will be rescheduled into the same slot
			
			foreach timer queue [
				case/all [										;-- `case` is faster than a chain of `if`s
					time < timer/planned [						;-- slow timers may skip multiple periods
						append timetable/:i timer				;-- reschedule the timer into the same slot
						continue
					]
				
					error: try/all [							;@@ try/all/keep ? ;@@ use try/catch when it gets supported
						do timer/code							;-- run the timer
						time: now/utc/precise
						none
					] [
						print ["*** Error in timer" mold/flat/part timer/code 50]
						print error
						time: now/utc/precise
						;@@ disarm erroneous timer instead of rescheduling to avoid too much spam?
					]
					
					timer/planned [								;-- could have been disarmed during evaluation
						i': time->slot timer/planned: time + timer/period	;-- 'time' instead of 'timer/planned' to prevent deadlocks
						append timetable/:i' timer
					]
				]
			]
			spare: clear queue
		]
		fired: offset
		true
	]
]


comment [
; do [
	; count: 0
	; t1: timers/create 10 [print now/precise count: count + 1]
	; timers/arm t1
	; end: (start: now/precise) + 0:0:3
	; while [now/precise < end] [timers/fire wait 0.001]
	; elapsed: difference now/precise start
	; ?? count ?? elapsed

	; ;; check of a lot of timers firing
	; count: 0
	; end: (start: now/precise) + 0:0:10
	; ts: repeat i 1000 [
		; append [] timers/arm timers/create 0:0:7 compose/deep [
			; print [(i) tab now/precise]
			; count: count + 1
		; ]
	; ]
	; waste: 0:0
	; while [now/precise < end] [waste: waste + dt [timers/fire] wait 0.01]
	; elapsed: difference now/precise start
	; waste: 100% * (waste / elapsed)
	; ?? count ?? elapsed ?? waste

	;; estimation of CPU waste on a loooot of slow timers (never firing)
	count: 0
	end: (start: now/precise) + 0:0:10
	ts: repeat i 1000 [
		; append [] timers/arm timers/create 0:1:0 []
		; append [] timers/arm timers/create 0:0:0.25 []
		append [] timers/arm timers/create 50 []
	]
	waste: 0:0
	while [now/precise < end] [waste: waste + dt [timers/fire] wait 0.001]
	elapsed: difference now/precise start
	waste: 100% * (waste / elapsed)
	?? count ?? elapsed ?? waste

	; ;; when timer is slower than it's requested rate - it should not deadlock
	; count: 0
	; end: (start: now/precise) + 0:0:5
	; ts: repeat i 10 [
		; append [] timers/arm timers/create 0:0:0.1 compose/deep [
			; print [(i) tab now/precise]
			; count: count + 1
			; wait 0.1
		; ]
	; ]
	; while [now/precise < end] [timers/fire wait 0.01]
	; elapsed: difference now/precise start
	; ?? count ?? elapsed
]