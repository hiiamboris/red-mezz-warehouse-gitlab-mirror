# HTTP Client

[%http-client.red](http-client.red) defines a high-level interface to use any common HTTP API.
Higher level than rebolek's `send-request` which itself is higher level than the native `write/info`.

HTTP client *transparently* ***handles***:
- content **encoding** and **decoding**
- **retries** after timeouts and other temporary failures
- noncritical decoding **errors**
- **rate limit** constraints
- **authorization** layers
- full **logging** of unexpected errors

## Usage

### Typical usage

**3 steps** are needed to work with the majority of API providers:

1. **Include** it into your code:
   ```
   #include %red-common/everything.red
   ```
   Due to over 25 dependencies involved, it is better to include everything from the `common` repo rather than cherry-pick relevant files.
   
2. **Declare** an API endpoint **group**:

   ```
   >> test-api: http/make-group https://httpbin.dev
   == make object! ...
   ```
   It can be inspected now:
   ```
   >> source test-api
   TEST-API is an object of class 'http-api-group':
   
     An HTTP API endpoint group.
   
   ``FIELD```````  DESCRIPTION``````````````````````````````````  EQ  TYPES````  ON-CHANGE 
     base:         Base URL for all API endpoints                     [url!]               
     retry-on:     Status codes that allow retrying                   [bitset!]            
     rate-limits:  Rate limits affecting this group                   [block!]             
     on-form:      Hooks evaluated before the request is formed       [block!]             
     on-send:      Hooks evaluated before the request is sent         [block!]             
     on-receive:   Hooks evaluated once the response is received      [block!]             
   
   ``FUNCTION````  DESCRIPTION  ARGS````` 
     get:                       path      
     delete:                    path      
     head:                      path      
     options:                   path      
     post:                      path data 
     put:                       path data 
     patch:                     path data 
   ```

3. Make requests to that group:

   Syntax is: `group/method 'sub-path data`:
   ```
   >> test-api/get 'get							;) GET https://httpbin.dev/get 
   == ...
   
   >> test-api/put 'put #[test: "value"]		;) PUT https://httpbin.dev/put
   == make object! [
   	status: 200									;) received HTTP status code
   	headers: #[..response headers..]
   	binary: #{..raw received data..}
   	content: #[									;) decoded Content-Type header
   		media-type: "application/json"
   		type: "application"
   		subtype: "json"
   		encoding: "utf-8"
   	]
   	data: #[									;) decoded received data
   		args: #[]
   		headers: #[...]
   		origin: ...
   		url: "https://httpbin.dev/put"
   		method: "PUT"
   		data: {{"test":"value"}}
   		files: none
   		form: none
   		json: #[
   			test: "value"
   		]
   	]
   	errors: []									;) list of errors occurred during decoding
   ]
   ```
   But as good as these (get/put/...) shortcuts may be, `http/send` function gives more control when needed. All shortcuts are just thin wrappers around this central request entry point:
   ```
   >> ? http/send
   USAGE:
        HTTP/SEND method group path
   
   DESCRIPTION: 
        Send METHOD request to the PATH within GROUP's URL. 
        HTTP/SEND is a function! value.
   
   ARGUMENTS:
        method       [word!] "HTTP verb."
        group        [object!] "API endpoint group."
        path         [word! path! string!] "Subpath within the GROUP's base URL."
   
   REFINEMENTS:
        /data        => Attach data to the request.
           data'        [map! block! string! binary! none!] 
        /headers     => Add custom headers to the request.
           headers'     [map! none!] 
        /weight      => Change request's weight towards rate control limits.
           weight'      [integer!] 
   
   RETURNS:
        A response! object.
        [object!]
   ```
   There's also a low-level `send-raw` wrapper around `write/info` that can be used for debugging, but it doesn't provide any of the features of this library:
   ```
   >> ? http/send-raw
   USAGE:
        HTTP/SEND-RAW method url headers data
   
   DESCRIPTION: 
        Send an HTTP request (lower level wrapper). 
        HTTP/SEND-RAW is a function! value.
   
   ARGUMENTS:
        method       [word!] {Supported: GET DELETE HEAD OPTIONS POST PUT PATCH.}
        url          [url!] "Full resource URL to access."
        headers      [map!] "Headers to send."
        data         [binary!] "Data to send."
   
   RETURNS:
        Response: #[status headers data].
        [map!]
   ```   

### Rate control

You can add as many **rate limits** to the group as needed:

```
>> limit1: http/make-rate-limit 100 0:0:30		;) 100 requestes per consecutive 30 seconds
>> limit2: http/make-rate-limit 5 0:0:1			;) 5 requests per second
>> repend test-api/rate-limits [limit1 limit2]
```
All subsequent requests will ensure all limits defined per endpoint group are strictly followed.

Rate limits can be inspected:
```
>> source limit1
LIMIT1 is an object of class 'rate-limit':

  Single API rate limit constraint.

``FIELD```  DESCRIPTION`````````````````````````````````  EQ  TYPES``````````````````````  ON-CHANGE 
  rate:     Number of requests allowed per single period      [integer!] (positive? rate)            
  period:   Rate enforcement period                           [time!] (positive? period)             
  history:  (internal) previous response timestamps           [block!]                               
```
   
### Authentication and Signing

**Static** authentication headers can easily be added to the endpoint group:
```
http/authenticate test-api 'Bearer my-secret-key
```

**Dynamic** authentication header can be injected using one of the hooks:
- `/on-form` - before the request is formed (as `func [request [object!]]`)
- `/on-send` - before the request is sent (as `func [request [object!]]`) *&lt;-- normally here*
- `/on-receive` - after the response is received (as `func [request [object!] response [object!]]`)

E.g. to add a SHA1 signature of the data:
```
append test-api/on-send function [request] [
	request/formed/headers/signature: checksum request/formed/data 'sha1
]
```
If hooks modify the request itself, modification will **persist across retries**, except `request/formed` part which is regenerated before every `on-send` hook. `/formed` is a map: `#[url method headers data]`. Request may be retried or returned after `on-receive` hooks complete, depending on its status code and retry mask.
   
## Error handling

+ Any error thrown during HTTP negotiation is a bug!
+ By design, all IO errors are collected into the `/errors` response block.
+ Response `/status` indicates if it's successful or not:
  - 000 means transport level error (a timeout or an SSL error)
  - 001 means malformed/unexpected/unsupported response format
  - 200-299 success responses from the server
  - 400-599 error responses from the server
  
  `http/error-codes` bitset can be used to check if status code is a success code.
+ Whenever a successful request cannot be made, all of the request data is printed for later inspection before an error is raised. This becomes extremely useful in long running unattended scripts in order to untangle unexpected situations, whether arising due to typically nonsensical API documentation, implementation deficiencies, or remote server errors.

