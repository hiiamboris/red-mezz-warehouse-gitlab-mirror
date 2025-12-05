Red [
	title:    "HTTP API client"
	purpose:  "Automate everything a typical HTTP API client may require"
	author:   @hiiamboris
	license:  BSD-3
	provides: http-client
	depends:  [tree-hopping advanced-function classy-object print error log reshape hide charsets from-latin-1]	;@@ xml json csv
	notes: {
		USAGE
		
		See %http-client.md
		
		DESIGN GOALS
		
		To use any HTTP API declaratively and easily.
		`endpoint/post 'sub/path data` - nothing more needed.
		
		DESIGN REQUIREMENTS
		
		I had to work with a lot of API endpoints, which all have their own standards (or lack of any),
		and it is not easy to produce a one-size-fits-all solution in this space.
		
		The worst in my experience by far is Bybit, which, in addition to going against the web standards,
		can send back a whole circus of success or error indicators, answer with a 'timeout' message(!) 🤦,
		one of unlisted internal errors, or even with an arbitrary malformed chunk of someone else's JSON...
		As a rule of thumb, the bigger the corp the more problematic it is to deal with. 
		
		So far I've identified the following peculiar requirements:
		- add a header with a signature from the finalized request data (binary)
		- add signature to the query string made from the part of the query string preceding it
		- signature function may need access to another header or any other request attribute, date, weather, anything
		- ensure the time set in the request is no further than 5-10 seconds from the server's internal time when it gets it
		  this may get nasty, esp. on mobile, saturated or throttled connections (all common in some countries)
		- some bastards (like Amazon) still send back XML instead of JSON
		  or worse: same endpoint may arbitrarily send XML or JSON on a whim
		  (but this can probably be handled by the user setting the Accept: header)
		- request rate limit per specific endpoint (look up KuCoin API for an extreme example)
		- request rate limit per a group of endpoints
		- request rate limit per IP, not per API key or other UID
		  (esp. problematic as multiple programs may be sharing it - with no way of knowing!)
		- rate limit per different time frames at the same time, e.g. per second and per 10 minutes
		- endpoints may have unique 'weights' towards rate limit
		- (auto?)detect rate limit hit and slow down (can happen due to traffic congestion/release)
		- authorize and rate-limit only private API endpoints, but not the public ones
		- send/receive integers bigger than 32 bits (64 is good enough, but in theory can be arbitrarily long)
		  so for now this has to be some hook/hack around the JSON codec
		- some erroneous responses may be considered successful, e.g. attempt to cancel all orders when none are open
		- some errors may just need a good number of retries to succeed (temporary internal errors usually)
		- timeout 408 is when server actually sends this answer and we receive it (e.g. we're taking too long to upload smth)
		- a network timeout will result in an 'Access Error' instead
		  in fact, all transport errors (timeout, SSL, connection drop) will be thrown as an access error
		  it can happen any time, and we should keep retrying until network restores or up to a certain limit
		  but the requirement to embed time into the request makes it necessary to reassemble it after every timeout
		- GC can cause 4xx errors or the server may send back pure crap (like Bybit does)
		  it should be configurable per endpoint if in such situations requests should be retried
		
		It seems wisest to have a configurable object per website or endpoint, and a thin flexible generic write/info wrapper.
		
		REQUEST WORKFLOW
		
		1. Endpoint is created and configured (e.g. rate and retries limit)
		2. Request is pushed for processing
		   2.1. Request parameters are registered in a map, to ease retries & logging
		   2.2. Rate limit delay is ensured
		   2.3. Registered request pre-processors are run
		   2.4. Request is formed
		   2.5. Registered request post-processors are run (e.g. signing, content length)
		   2.6. Request is sent
		3. Response is received (from the server or timeout from the driver)
		   3.1. Rate limit tables are updated
		   3.2. Response is decoded to the extent possible (helpful even in error logging)
		   3.3. Decoding errors are logged, but do not require an error
		4. If response indicates an error: 
		   4.1. Retriable requests go back to 2.2 until retries limit is hit
		   4.2. Unrecoverable error is extensively logged and then thrown
		5. If response is successful, decoded request (or only data) is returned
		
		RATE LIMITS
		
		Rate limits are represented by a separate object of class rate-limit.
		Each endpoint can include zero or more rate limit objects. E.g.:
		- for IP based limiting limit object may be shared by all endpoints,
		- to apply it to a group of endpoints - shared by that group,
		- or limit object can be unique to an endpoint, affecting only it.
		This provides flexibility enough to satisfy all use cases known to me.

		During async I/O, rate limit may be hit despite careful timing, e.g.:
		- we are allowed a rate of 5 req/s, latency is ~50ms, and we conservatively send only 4 req/s
		- we send requests at: 0, 250, 500, 750, 1000, 1250, 1500... ms delays
		- unknown to us, request 1 gets delayed by 500ms, dragging also requests 2-4 behind
		- server receives a burst, e.g.: 500, 600, 700, 800, 1050, 1300, 1550... ms relative to us
		- all 1-7 requests fit within the 1-second window, causing error 429
		It is ultimately up to user to lower the rate to compensate for bursts,
		but what we can do is let all the affected rate limits cool down.
		One likely cause also may be sharing of the rate limit by multiple programs.
		Other causes: endpoint misconfiguration, changes on the server side, temporary server overload. 
		To avoid being banned in this case, the receiver of 429 may:
		- abort and quit with an error (safest, but most annoying)
		- wait one period (1 sec, 1 min) then resume (may be inefficient)
		- halve the rate for a reasonable amount of time (1-5 minutes), then try to restore it
		  this tactic, if shared by multiple programs, may relatively safely autoscale their rates
		
		Since our I/O model is not async yet, that's a problem for the future.
		For now, we may just mark the response times. Assuming:
		- P = rate period (1sec, 1min)
		- N = rate limit (e.g. 5 req/P)
		- request R was sent at time ST, reached at time T and response received at time RT
		Request R+N then can be safely sent at time RT+P > T+P.
		When latency is high, it will not be affected by this limit.
		It can get a bit suboptimal when rate period is small (e.g. 1 sec), and latency is close to rate.
		E.g. with limit of 5 req/s, latency of 100ms+, we can physically achieve 5 req/s
		but the algorithm will wait after the first RT=200ms (e.g. T=100ms) another second, 
		so the real rate will be 5 req per (1200ms-100ms)=1.1 sec, which is 10% lower - not low enough to bother.
		
		Burst control can be adjusted by changing the rate period. E.g. from 5 req/s to 1 req per 200ms.
		This however will have the negative effect of always adding latency to the period.
		So it is preferable to have a flag for burst control that will still be based on a larger sliding window.
		It'll change condition from (no less than P since N-th last request's receipt)
		to (no less than P/N*M since M-th last request's dispatch, when M < N).
		However this requires more bookkeeping: not only response but also request times; so not supported atm.
		
		To accomodate for the 'weight' of endpoints, we can just duplicate request time in the history.
		
		This all leads to the introduction of the following request 'history' format:
			history: [RT1 RTN2 ... RTN]
		- history is a part of each rate limit object: an endpoint may have to iterate to satisfy all of them
		- each new request receipt time RT is appended (for a request of weight W: W times the same value)
		- history length is kept at maximum of N items, head-truncated after each insertion
		- for a new request of W=1 to be made one of the following must be true:
		  - history is shorter than N (history/:N = none)
		  - history/1 + P <= now
		-  for a new request of W>1 to be made one of the following must be true:
		  - history is no longer than N-W (history/(N - W) = none)
		  - history/:W + P <= now (we'll discard first W items and insert W new items)
		
		STATUS CODES (https://en.wikipedia.org/wiki/List_of_HTTP_status_codes)
		
		1xx-2xx are OK
		3xx are redirects (don't care - handled by 'write' itself)
		4xx are client errors, but 408,409,423,424,425,428,429 may be fixed by a retry
		5xx are server errors, but 500,502,503,504,508,509,520+ may be fixed by a retry
		Special treatment:
		- 429 too many requests - needs a cooldown
		- 4xx can come due to a GC error mangling the request - may be retried after a recycle
		- undecodable server response (server memory corruption) - may be retried for read-only verbs
		It should be configurable per-endpoint what codes we want to retry after. A bitset makes sense.
		
		Transport level errors do not cause a 408, but an 'Access Error': SSL, TCP timeout, broken connection.
		We can reserve 000 for 'Any transport level error' (which aligns with curl's usage of 000).
		Also there's no status code for undecodable server response, so we can reserve 001 for it.
		Using app-level status codes make response handling more uniform and logical, compared to exceptions.
		
		RETRY DELAYS
		
		It makes sense to increase the delay each with each new attempt, but how much?
		Exponent only makes sense for small number of attempts, but delays reach hours+ fast (not useful).
		Power function of mantissa 1.5-2.0 works best: keeps the delay big enough but not astronomical.
		
		CHARSETS
		
		According to https://w3techs.com/technologies/overview/character_encoding UTF-8 already covers 98.8% of the web.
		With ISO-8859-1 taking the other 1.0%, that leaves 0.2% chance of dealing with the other charsets.
		ISO-8859-1 is a subset of Unicode, so the only conversion needed is already provided by `to-char byte`. 
		Does it make sense to support charsets then? Not yet anyway, not for http - but maybe for text files.
	}
]

; #debug set http

;@@ put outside
as-map: function [
	"Create a map with given WORDS and assign values from these words"
	words [block!] (parse words [some [set-word! | word!]])
][
	also map: make map! length? words
	foreach w words [map/:w: get w]
]

;; high-level interface for HTTP(S) works
http: context [

	;; ============================================== ;;
	;;      NECESSARY CONSTANTS, LISTS AND CHECKS     ;;
	;; ============================================== ;;
	
	known-verbs: [GET POST PUT DELETE PATCH HEAD OPTIONS]		;-- sorted by likelyhood of use
	query-verbs: [GET DELETE HEAD]								;-- verbs that pass data in a query, not payload
	data-verbs:  [POST PUT PATCH]								;-- verbs that pass data in a payload, not query

	;; all possible status codes, invalid status, and those that may succeed after a retry:
	;; see header notes on internal codes 000 and 001 and why they should be retriable by default
	valid-codes: charset [0 - 999]
	ok-codes:    charset [200 - 399]
	error-codes: charset [0 - 99 400 - 999]
	retry-codes: charset [0 1 408 409 423 424 425 428 429  500 502 503 504 508 509 520 - 599]
	
	;; known (not necessarily supported) text formats outside of 'text/' content type
	;; they will be force-converted from binary to text
	text-formats: make hash! [
		"application/rtf"
		"application/graphql"
		"application/javascript"
		"application/x-javascript"
		"application/problem+json"
		"application/json"
		"application/xml"
		"application/x-www-form-urlencoded"
	]
	
	mime-formats: #[
		"application/problem+json"	json
		"application/json"			json
		"text/json"					json
		"text/csv"					csv
		"text/tab-separated-values" tsv
		"application/xml"			xml
		"text/xml"					xml
		"application/x-www-form-urlencoded" url
		"application/octet-stream"  binary
		; "multipart/form-data"		;@@ TODO 
		;@@ TODO text/: uri-list rtf html markdown yaml
	]
	
	is-text-format?: function [
		"Check if Content-Type requires binary to text conversion"
		content [map!] "Decoded Content-Type header"
		return: [logic!]
	][
		to logic! any [
			content/type = "text"
			find text-formats content/media-type
		]
	]
		
	normalize-method: function [
		"Uppercase the METHOD name for logging consistency"
		method  [word!]
		return: [word!]
	][
		first find known-verbs method
	]
	
	
	;; ============================================== ;;
	;;                 RETRY MECHANICS                ;;
	;; ============================================== ;;
	
	;; this also determines the max number of attempts: if the last one fails, an error is thrown
	;; by default, up to 25 hours of retrying - good for unattended bots, if they lose network for a while
	retry-delays: map-each i 99 [i ** 1.7 * 0:0:1]
	
	retry?: function [
		"Wait for retry or fail"
		allowed [bitset!]  "Status codes that allow retrying"
		status  [integer!] "Returned status code"
		attempt [integer!] "Attempt number" (attempt > 0)
	][
		either all [
			allowed/:status
			delay: retry-delays/:attempt
		] [
			#debug http [#log "Retrying after (delay)s..."]
			wait delay yes
		] [no]
	]
	retry-always: function [status [integer!] attempt [integer!]] [
		retry? error-codes status attempt
	]
	retry-normal: function [status [integer!] attempt [integer!]] [
		retry? retry-codes status attempt
	]
	
	retry: function [
		"Keep retrying CODE while it returns a retriable status"	;-- exceptions are passed through
		ok-mask [bitset!] "Status codes that are acceptable"
		re-mask [bitset!] "Status codes to retry on"
		code    [block!]  "Must return a response"
		fail    [block!]  "Evaluate on unrecoverable error"
	][
		i: 0 forever [
			response: do code
			case [
				find   ok-mask response/status [return response]
				retry? re-mask response/status i: i + 1 [continue]
				'else [break]
			]
		]
		do fail
	]
	
	;; the purpose of this function is to separate (as strictly as makes sense)
	;; decoding errors from syntax errors coming from the bugs in the http library
	divert: function [
		"Divert errors raised by CODE into a targeted throw"
		code [block!]
	][
		trap/catch code [throw thrown]
	]


	;; ============================================== ;;
	;;             HTTP OBJECT PROTOTYPES             ;;
	;; ============================================== ;;
	
	rate-limit!: declare-class 'rate-limit [					;-- not limited to http, hence no 'http' in the name
		"Single API rate limit constraint"						;-- by default configured for high throughput
		
		rate:    1000		#type [integer!] "Number of requests allowed per single period" (positive? rate) 
		period:  0:0:1		#type [time!]    "Rate enforcement period" (positive? period)
		; burst?:  on			#type [logic!]	 "If true, bursts are allowed"
		history: copy []	#type [block!]   "(internal) previous response timestamps"
	]
	
	api-group!: declare-class 'http-api-group [
		"An HTTP API endpoint group"
		
		base: http://localhost/		#type [url!]    "Base URL for all API endpoints"
		retry-on:    retry-codes	#type [bitset!] "Status codes that allow retrying"
		rate-limits: copy []		#type [block!]  "Rate limits affecting this group"
		
		;; on-form hooks: func [request [object!]], modifications will persist across attempts, but /formed will be replaced
		on-form:     copy []		#type [block!]  "Hooks evaluated before the request is formed"
		;; on-send hooks: func [request [object!]], modifications (except /formed) will persist across attempts
		on-send:     copy []		#type [block!]  "Hooks evaluated before the request is sent"
		;; on-receive hooks: func [request [object!] response [object!]], modify the response (before a retry/return)
		on-receive:  copy []		#type [block!]  "Hooks evaluated once the response is received"
		
		get:     func [path /with data] [send/:data 'GET     self path data]
		delete:  func [path /with data] [send/:data 'DELETE  self path data]
		head:    func [path /with data] [send/:data 'HEAD    self path data]
		options: func [path]            [send       'OPTIONS self path]
		post:    func [path data]       [send/data  'POST    self path data]
		put:     func [path data]       [send/data  'PUT     self path data]
		patch:   func [path data]       [send/data  'PATCH   self path data]
	]
	
	request!: object [
		;; original part:
		group:   none
		method:  none
		url:     none
		headers: none
		data:    none
		weight:  1
		
		;; encoded part:
		formed:  none									;-- #[url method headers data (binary)]
		time:    none									;-- time right before request is sent
	]
	
	response!: object [
		;; original part:
		status:  none									;-- HTTP status code of the response
		headers: none									;-- response headers received
		binary:  none									;-- raw binary data received
		time:    none									;-- time right after response is received
		
		;; decoded part:
		content: none									;-- decoded Content-Type header (map!): type, charset ...
		data:    none									;-- decoded data (unless failed)
		errors:  none									;-- decoding errors (error! objects)
	]
	

	;; ============================================== ;;
	;;           ENDPOINT GROUP CONSTRUCTION          ;;
	;; ============================================== ;;
	
	make-group: function [
		"Make a new HTTP API endpoints group"
		base [url!] "Base URL for this group"
		/stubborn "Retry on all error status codes"
		/limits rate-limits [block!] "List of applicable rate limits (reduced)"
	][
		group: make classy-object! api-group!
		group/base: copy base
		group/retry-on: either stubborn [error-codes][retry-codes]
		if limits [group/rate-limits: reduce rate-limits]
		group
	]
	
	accept: function [
		"Add an Accept header to the endpoints GROUP"
		group [object!]
		value [string!]
	][
		append group/on-form func [request] compose [
			request/headers/Accept: (value)
		]
	]
	
	authenticate: function [
		"Add an authentication header to the endpoints GROUP"
		group [object!]
		type  [word!]
		token [string!]
	][
		append group/on-form func [request] compose [
			request/headers/Auth: (`"(type) (token)"`)
		]
	]
	

	;; ============================================== ;;
	;;                  RATE CONTROL                  ;;
	;; ============================================== ;;
	
	make-rate-limit: function [
		"Define a new rate limit"
		rate   [integer!] "Number of requests allowed per single period" 
		period [time!]    "Rate enforcement period"
	][
		limit: make classy-object! rate-limit!
		limit/rate:   rate
		limit/period: period
		limit
	]
	
	wait-for-rate: function [
		"Pass time until GROUP is ready for a new request of given WEIGHT"
		group  [object!]
		weight [integer!]
	][
		next-retry: 1900/1/1
		foreach limit group/rate-limits [						;-- find the most congested limit ;@@ use 'accumulate'
			if ref: limit/history/:weight [						;-- limit can accept 'weight' yet if 'ref' is none
				next-retry: max next-retry ref + limit/period
			]
		]
		left: difference next-retry now/utc/precise
		if positive? left [wait left]
	]
	
	update-history: function [
		"Add completed request time to all rate limits of the GROUP"
		group  [object!]
		weight [integer!]
	][
		if empty? limits: group/rate-limits [exit]
		time: now/utc/precise
		foreach limit limits [
			remove/part limit/history weight
			append/dup limit/history time weight
		]
	]
	
	;; ============================================== ;;
	;;               REQUEST DISPATCHERS              ;;
	;; ============================================== ;;
	
	send: function [
		"Send METHOD request to the PATH within GROUP's URL"
		method [word!]   "HTTP verb"
		group  [object!] "API endpoint group"
		path   [word! path! string!] "Subpath within the GROUP's base URL"
		/data    "Attach data to the request"
			data'         [map! block! string! binary! none!]
		/headers "Add custom headers to the request"
			headers': #[] [map! none!]
		/weight  "Change request's weight towards rate control limits"
		    weight':  1   [integer!] (weight' > 0)
		return: [object!] "A response! object"
	][
		request: copy request!
		request/group:   group
		request/method:  normalize-method method
		request/weight:  weight'
		request/headers: copy headers'
		request/data:    data'
		request/url:     group/base/(form path)
		retry ok-codes group/retry-on [
			wait-for-rate group weight'
			foreach hook group/on-form [hook request]
			form-request request
			foreach hook group/on-send [hook request]
			response: decode-response dispatch-request request
			foreach hook group/on-receive [hook request response]
			response											;-- retry tests response/code
		][
			;; an unrecoverable error must be extensively logged for further analysis
			#assert [object? response]
			#log "^/************************************************"
			#log "(request/method) request to (request/url) failed with status (response/status):"
			#log "Request was: (mold/part request 4096)"
			#log "Response received: (mold response)"
			; foreach error response/errors [print error]		;-- already printed anyway
			ERROR "(request/method) request to (request/url) failed with status (response/status)"
		]
		response
	]
	
	dispatch-request: function [
		"Dispatch the HTTP REQUEST to its dedicated path"
		request [object!] "A request! object"
		return: [object!] "A response! object"
	][
		#assert [request/formed]
		f: request/formed
		request/time: now/precise
		response: send-raw f/method f/url f/headers f/data
		make response! [
			status:  response/status
			headers: response/headers
			binary:  response/data
			time:    if status > 0 [now/precise]
			errors:  copy []
		]
	]
	
	;; this function can be used without any API group creation whatsoever
	;; and is just a convenience wrapper over the bare write/info
	send-raw: function [
		"Send an HTTP request (lower level wrapper)"
		method 	[word!]   "Supported: GET DELETE HEAD OPTIONS POST PUT PATCH" (find known-verbs method)
		url 	[url!]    "Full resource URL to access"
		headers	[map!]    "Headers to send"
		data	[binary!] "Data to send"
		return:	[map!]    "Response: #[status headers data]"
	][
		method: normalize-method method
		#assert [any [empty? data  find [post put patch] method]  "method doesn't accept data"]
		
		foreach [k v] headers [									;@@ write/info expects strings or crashes
			unless string? :v [headers/:k: form :v]				;@@ use map-each [k v (not string? v)] when fast
		]
		
		#debug http [
			#log "^/Sending (method) to (url) with (length? data) bytes"
			#log "Request headers: (mold headers)"
			#log "Request data: (mold/flat data)"
		]
		
		info: reduce [method to block! headers data]
		trap/catch [response: write/binary/info url info] [
			error: thrown
			either all [error/type = 'access  error/id = 'no-connect] [
				msg: `"Networking failure (\cannot connect to (url))"`
				response: reduce [000 copy #[] msg]				;-- replace exception with status code 000
			] [do thrown]										;-- rethrow all the other errors
		]
		#debug http [#log "Got raw response: (mold response)"]
		
		set [status: headers: data:] response
		#assert [map? headers]
		foreach [k v] headers [if block? v [headers/:k: last v]]	;@@ workaround for #4236
		as-map [status headers data]
	]

	; only-data: function [
		; "Return data of the RESPONSE, raise an error otherwise"
		; response [object!]
		; return:  [default!]
	; ][
		; unless find ok-codes code: response/status [ERROR "Received HTTP status (code)"]
		; response/data
	; ]
	
	
	;; ============================================== ;;
	;;                    ENCODERS                    ;;
	;; ============================================== ;;
	
	;@@ should this be a system codec?
	url-encode: function [
		"Serialize DATA using x-www-form-urlencoded rules"
		data [map!]
	][
		result: copy ""
		foreach [k v] data [append result `"(enhex form k)=(enhex form v)&"`]
		if k [take/last result]
		result
	]
	
	encode-data: function [
		"Encode formed/data into a binary or query, set appropriate content-type"
		formed [map!] "May modify url, headers, data"
	][
		type: type? data: formed/data
		method: formed/method
		#debug http [#log "Encoding data: (mold data)"]
		formed/data: case [
			empty? data [copy #{}]
			all [find/only [#(map!) #(block!)] type  find data-verbs method] [
				formed/headers/Content-Type: copy "application/json"
				to binary! to-json data							;-- block! -> JSON list (though I haven't seen where it's used)
			]
			all [type = map!  find query-verbs method] [
				unless empty? data [repend formed/url ["?" url-encode data]]
				copy #{}
			]
			all [type = string!  find query-verbs method] [
				unless empty? data [repend formed/url ["?" data]]	;-- assumes enhexed and formed query
				copy #{}
			]
			all [type = string!  find data-verbs method] [
				default formed/headers/Content-Type: copy "text/plain; charset=utf-8"
				to binary! data
			]
			all [type = binary!  find data-verbs method] [
				default formed/headers/Content-Type: copy "application/octet-stream"
				data
			]
			'else [ERROR "Method (method) cannot pass (type) data: (mold/part data 60)"]
		]
		formed
	]
	
	form-request: function [
		"Fill in request/formed map"
		request [object!]
		return: [object!] "Same request, modified"
	][
		method:  request/method
		headers: copy request/headers
		url:     copy request/url
		data:    request/data							;-- will be overridden by encode-data
		request/formed: encode-data as-map [url method headers data]
		request
	]
	
	
	;; ============================================== ;;
	;;                    DECODERS                    ;;
	;; ============================================== ;;
	
	url-decode: function [
		"Deserialize STRING using x-www-form-urlencoded rules"
		string [string!]
	][
		result: copy #[]
		foreach line split string #"&" [
			set [k: v:] split line #"="
			k: try-load-key   dehex k
			v: try-load-value dehex v
			result/:k: v
		]
		result
	]
	
	json-walker: make-series-walker/unordered/unsafe [block! map!]
	convertible-value!: make typeset! [integer! tuple! date! time!]
	convertible-key!:   make typeset! [convertible-value! word!]
	
	load-convertible: function [
		"Try loading a STRING as a Red value"
		string  [any-type!]
		types   [typeset!]
		return: [any-type!] "Red value on success, none on failure" 
	][
		all [
			string? :string
			type: scan string							;-- can be 'none'
			find types type
			transcode/one string
		]
	]
	
	load-key:   function [value [any-type!]] [load-convertible value convertible-key!]
	load-value: function [value [any-type!]] [load-convertible value convertible-value!]
	try-load-key:   function [string [string!]] [any [load-key   string string]]
	try-load-value: function [string [string!]] [any [load-value string string]]
	
	json->red: function [
		"Aggressively decode loaded JSON data into Red datatypes"
		json [block! map!]
	][
		foreach-node json json-walker [
			if v: load-value node/:key [node/:key: v]
			if k: load-key key [
				node/:k: node/:key
				remove/key node key
				key: k
			]
			node/:key
		]
		json
	]
	
	decode-content-type: function [
		"Decode the Content-Type header"
		content-type [string!]
		return:      [map!]
	][
		=char=:   [not {"} opt #"\" keep skip]
		=quoted=: [{"} (value: copy {}) collect after value [any =char=] {"} to #";"]
		=media-type=: [
			copy media-type [copy type to #"/" #"/" copy subtype [to #";" | to end]]
			(map: as-map [media-type: type: subtype:])
		] 
		=parameter=: [
			"; " copy attr to #"=" #"=" [=quoted= | copy value [to #";" | to end]]
			(put map (try-load-key attr) value)
		]
		parse content-type [=media-type= any =parameter=] 
		foreach [k v] map [map/:k: try-load-value v]
		map
	]
	
	normalize-line-breaks: function [
		"Convert CRLF and CR into LF"
		text    [string!]
		return: [string!]
	][
		result: clear copy text
		parse/case text [collect after result any [
			keep to #"^M" #"^M" opt #"^/" keep (#"^/")
		|	keep to end
		]]
		result
	]
	
	decode-text: function [
		"Decode BINARY as string of given CHARSET"
		binary  [binary!]
		charset [word! string! none!]
		return: [string!]
	][
		normalize-line-breaks switch/default charset [
			"utf-8" #(none)        [to string!   binary]		;-- assume UTF-8 if unspecified
			"iso-8859-1" "latin-1" [from-latin-1 binary]
		] [cause-error 'access 'no-codec [charset]]
	]
	
	decode-response: function [
		"Try to decode the response and list errors that occurred in it"
		response [object!] "(modified)"
		return:  [object!] "Modified response"
	][
		default response/headers/Content-Type: "application/octet-stream"	;-- default to binary unless specified
		response/content: content: decode-content-type response/headers/Content-Type
		charset: any [content/charset content/encoding]			;-- encoding= is noncompliant but exists; 'none' is okay
		format:  select mime-formats content/media-type
		text:    if is-text-format? content [[decode-text response/binary charset]]
		decoder: compose/deep switch format [
			json	[[ json->red divert [load-json (text)]	]]
			csv		[[ divert [load-csv (text)]				]]	;@@ aggressively load CSV/TSV?
			tsv		[[ divert [load-csv/with (text) #"^-"]	]]
			xml		[[ divert [load-xml (text)]				]]
			url		[[ divert [url-decode (text)]			]]
			binary	[[ response/binary						]]
		]
		response/data: fcatch/handler [error? thrown]
			any [decoder text [response/binary]]
			[													;-- error during decoding is a significant error!
				response/status: 001							;-- flag malformed response with status 001
				append response/errors thrown
				print thrown									;-- log the error but don't re-throw
				copy {Malformed response (data cannot be decoded)}
			]
		response
	]
	
]

