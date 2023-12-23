Red [
	title:   "Data and state file management"
	purpose: {Standardized zero-fuss loading and saving of data, config and other state}
	author:  @hiiamboris
	license: 'BSD-3
	usage: {
		DATA-STORE context is initialized at boot time and contains /PATHS map with platform-specific paths.
		There are five data types: data, config, state, cache, runtime (see 'design' section).
		All files are stored in <home-path-for-given-type>/<script-name>/ directory.
		
		/SCRIPT-NAME contains an automatically inferred at compile-time name of the main program.
		It can be replaced at run-time to a more relevant value (string!).
		
		Functions /MAKE-PATH and /FIND-FILE are there to create a file name for writing into, or find a file to read from.
		On reading, fallback paths may be used, while writing is always done into specific location.
		
		/READ-FILE, /WRITE-FILE, /LOAD-FILE and /SAVE-FILE are generic wrappers around /MAKE-PATH and /FIND-FILE.
		
		/LOAD-CONFIG, /SAVE-CONFIG, /LOAD-STATE and /SAVE-STATE are most commonly used wrappers around /LOAD-FILE and /SAVE-FILE.
		Use /LOAD-CONFIG to load user- or system-provided configuration (in Red key/value format by default).
		Use /SAVE-CONFIG to when you want to store configuration set by user via GUI means into a user-local config file.
		Use /LOAD-STATE and /SAVE-STATE to store all state you want to restore on the next run.
		
		/PORTABLE? flag, when set, works inside the directory of the binary instead of /PATHS. 
		
			Note: modules using this file should not try to load their files during boot phase,
			because /portable? flag will get initialized by the user at the CLI argument processing time.
			Instead, they should either delay data loading until accessed, or expose explicit init function.
	
			Proper workflow:
				main: function [args... /portable] [
					if portable [data-store/portable?: on]
					...init and use modules...
				]
				cli/process-into main
	}
	design: {
		Sources:
		- AI: https://www.phind.com/search?cache=j1uk0jquj951oyl7g7fair9k
		      https://www.perplexity.ai/search/List-EXAMPLES-of-ksxPyQIVSw.c7U5B4WG6uw
		  Q was: List EXAMPLES of what types of data should be stored in
		         XDG_CONFIG_HOME, XDG_STATE_HOME, XDG_CACHE_HOME, XDG_DATA_HOME and XDG_RUNTIME_DIR.
		- https://specifications.freedesktop.org/basedir-spec/basedir-spec-0.8.html
		- https://wiki.archlinux.org/title/XDG_Base_Directory
		- https://stackoverflow.com/a/52749090 (usage of XDG on Mac is encouraged for scripts)
		
		So we have the following data TYPES:
		- DATA (read-only: app resources; multiple dirs)
		  linux:   $XDG_DATA_HOME($HOME/.local/share) then $XDG_DATA_DIRS(/usr/local/share/:/usr/share/)
		  windows: %LOCALAPPDATA% then %ALLUSERSPROFILE%
		- CONFIG (read-only: modified by the user; multiple dirs)
		  linux:   $XDG_CONFIG_HOME($HOME/.config) then $XDG_CONFIG_DIRS(/etc/xdg)
		  windows: %APPDATA% then %ALLUSERSPROFILE% 
		- STATE (persistent: bookmarks, history, journal, logs, UI, game saves, ...)
		  linux:   $XDG_STATE_HOME($HOME/.local/state)
		  windows: %APPDATA%
		- CACHE (persistent: stuff for speedup, can be regenerated without info loss)
		  linux:   $XDG_CACHE_HOME($HOME/.cache)
		  windows: %TEMP% or %TMP%
		- RUNTIME (not persistent: locks, pipes, per-instance data, temporary disposable files)
		  linux:   $XDG_RUNTIME_DIR(/run/user/$UID but UID is not an exported envvar so can't fall back to it)
		  windows: %TEMP% or %TMP%
		
		Considerations:
		- State & config may be synced across multiple access devices of the user. For other types it makes little sense.
		- All paths may point to a single location (esp. in portable mode), so file names used by the program must never clash.
		- Multiple modules in the same program may need access to their own state and require unique file names
		  (this sets minimal naming scheme to user-state-home/program/module.ext, with module='state' reserved for the main program).
		- Different users may be using different versions of the program, so sharing resources isn't always a win.
		- While all data is per-user, some may also be per-instance of the same program (when multiple copies are run at once).
		  Such data is not persistent, and either relies on generation of unique filenames, or usage of lock files to disable concurrency.

		Portable mode:
			All file types are stored in data-store/paths/script.
			Means either whole directory is dedicated to this program, or it has very little state. 
		Approaches to achieve it:
		- '--portable' or similar runtime option sets 'data-store/portable?' (chosen approach)
		  requires CLI lib; some modules may try to read data from the wrong place before CLI manages to process arguments
		- '.portable' file stored together with the binary
		  inelegant, inflexible, not outright obvious to the user
		- program-specific envvar set to point to data storage location
		  even less elegant
		- '#do [portable?: on]' flag set during compilation
		  does not allow to use single binary in both portable and normal modes
	}
]

#local [

;; #BYOS [linux+mac-code][windows-code] local helper macro
#macro [#BYOS 2 block!] func [[manual] s e /local chosen] [		;-- choose proper code from 2 variants
	chosen: pick next s
		select [Linux 1 MacOS 1 Windows 2]
		either Rebol [red/job/OS][system/platform]
	insert remove/part s 3 chosen
	s
]

data-store: context [
	portable?: off												;-- can be set by the CLI user (read 'usage' section)
	
	from-env: function [
		"Get value of an environment variable, or its default, as a file"
		var [string!]
	][
		if var: any [get-env var  paths/defaults/:var] [
			to-red-file var
		]
	]

	join-paths: function [										;@@ #5446 - I wish '/' just worked instead
		"Construct absolute path by going into PATH from ROOT"
		root [file!] path [file!]
	][
		either #"/" = first path [path][clean-path rejoin [dirize root path]]
	]
	
	group-env: function [
		"Fetch and group multiple environment variables"
		spec [block!]
	][
		parse spec [collect any [
			set group opt '* set name string! keep pick (
				if value: from-env name [
					if group [value: split value #":"]			;-- XDG groups are delimited by colon
				]
				any [value []]									;@@ use `only`
			)
		]]
	]
	
	paths: context [
		;; script path is where the compiled binary is (system/options/path + system/options/boot)
		;; it is to be used in portable mode instead of all the other paths
		;; for interpreted script there's no way to find it (at best - location of this config.red file)
		;; so path to red.exe (also /path + /boot) is used for consistency in this case
		;@@ that doesn't work on linux because we don't have an absolute path for /boot; leads to this source file path
		script: first split-path join-paths
			to-red-file system/options/path
			to-red-file system/options/boot
		home: to-red-file #BYOS
			[any [get-env "HOME" %~]]
			[get-env "USERPROFILE"]
		defaults: make map! compose [#BYOS [
			"XDG_DATA_HOME"		(home/.local/share)
			"XDG_DATA_DIRS"		("/usr/local/share/:/usr/share/")
			"XDG_CONFIG_HOME"	(home/.config)
			"XDG_CONFIG_DIRS"	(%/etc/xdg)
			"XDG_STATE_HOME"	(home/.local/state)
			"XDG_CACHE_HOME"	(home/.cache)
			"XDG_RUNTIME_DIR"	(home/.cache)					;@@ an insecure fallback, but what's a better alternative?
		][
			;; Windows specifies no defaults
		]]
	]
	paths: make paths [											;-- these use 'from-env' which requires 'defaults'
		temp:   any [
			from-env "TEMP"
			from-env "TMP"
			from-env "TMPDIR"
			#BYOS [%/tmp][%.]									;@@ /tmp is probably inaccessible dir? what's better?
		]
		data:   group-env #BYOS
			[["XDG_DATA_HOME" *"XDG_DATA_DIRS"]]
			[["LOCALAPPDATA" "ALLUSERSPROFILE"]]
		config: group-env #BYOS
			[["XDG_CONFIG_HOME" *"XDG_CONFIG_DIRS"]]
			[["APPDATA" "ALLUSERSPROFILE"]] 
		state:   #BYOS [from-env "XDG_STATE_HOME" ][from-env "APPDATA"]
		cache:   #BYOS [from-env "XDG_CACHE_HOME" ][temp]
		runtime: #BYOS [from-env "XDG_RUNTIME_DIR"][temp]
	]
	
	;; script name is hardcoded during compilation, so not affected by binary renames
	script-name: #do keep [										;-- extract the basename only, don't store full path in the exe
		;@@ to work around #4422 this must only be set once, otherwise it'll become 'data-store'
		if unset? get/any 'red-main-script-name [
			red-main-script-name: last split-path either rebol [
				red/script-name
			][
				to-red-file any [
					system/options/script
					system/options/boot
				]
			]
			clear find/last red-main-script-name "."			;@@ reminder: cannot use #"." (char!) - #2870
		]
		to string! red-main-script-name
	]
	
	make-path: function [
		"Construct full path to the data file of given type"
		type    [word!] "One of: [data config state cache runtime]"
		subpath [file!] "File name or path unique within the program"
		/create "Prepare the directory structure"
	][
		#assert [find [data config state cache runtime] type]
		if portable? [type: 'script]
		if block? path: paths/:type [path: path/1]
		unless portable? [path: path/(script-name)]				;@@ affected by #5450
		#assert [file? path]
		path: path/:subpath
		if create [make-dir/deep dir: first split-path path]
		path
	]

	find-file: function [
		"Find data file of given type; none if not found"
		type    [word!] "One of: [data config state cache runtime]"
		subpath [file!] "File name or path unique within the program"
	][
		#assert [find [data config state cache runtime] type]
		if portable? [type: 'script]
		unless block? alts: paths/:type [alts: reduce [alts]]
		foreach path alts [
			unless portable? [path: path/(script-name)]			;@@ affected by #5450
			if exists? file: path/:subpath [return file]
		]
		none
	]
	
	read-file: function [
		"Read data file of given type; none if not found"
		type    [word!] "One of: [data config state cache runtime]"
		subpath [file!] "File name or path unique within the program"
		/binary "Preserves contents exactly"
		/lines  "Convert to block of strings"
	][
		if file: find-file type subpath [read/:binary/:lines file]
	]
	
	load-file: function [
		"Load data file of given type; none if not found"
		type    [word!] "One of: [data config state cache runtime]"
		subpath [file!] "File name or path unique within the program"
		/as "Specify the format of data; use NONE to load as code."
			format [word! none!] "E.g. bmp, gif, jpeg, png, redbin, json, csv."
	][
		if file: find-file type subpath [load/all/:as file format]	;-- make no sense without /all for files
	]
	
	write-file: function [
		"Write data file of given type"
		type    [word!] "One of: [data config state cache runtime]"
		subpath [file!] "File name or path unique within the program"
		text    [string! binary! block!]
		/binary "Preserves contents exactly"
		/lines  "Convert to block of strings"
	][
		file: make-path/create type subpath
		write/:binary/:lines file text
	]
	
	save-file: function [
		"Save data file of given type"
		type    [word!] "One of: [data config state cache runtime]"
		subpath [file!] "File name or path unique within the program"
		data    [any-type!] "Value(s) to save"
		/all "Save in serialized format"
		/as  "Specify the format of data; use NONE to save as plain text."
			format [word! none!] "E.g. bmp, gif, jpeg, png, redbin, json, csv."
	][
		file: make-path/create type subpath
		save/:all/:as file :data format
	]
	
	;; most common shortcuts:
	
	load-config: function [
		"Load program configuration"
		/defaults defaults' [map!] "Provide defaults for unspecified fields"
		/name "Provide custom config filename"
			name' [file!] "Defaults to <script-name>.config"
	][
		unless name' [name': rejoin [as file! script-name ".config"]]	;@@ use advanced-function or default
		data: any [load-file 'config name'  make map! 16]		;-- silently allow absence of config
		if block? :data [data: make map! data]
		if defaults'    [data: extend defaults' data]
		data
	]
	
	save-config: function [
		"Save program configuration as key-value dictionary (WARNING: this may overwrite user-provided config file)"
		config [map!]
		/name "Provide custom config filename"
			name' [file!] "Defaults to <script-name>.config"
	][
		unless name' [name': rejoin [as file! script-name ".config"]]	;@@ use advanced-function or default
		unless find [%.redbin %.json] suffix? name' [			;-- remove #() decoration from Red files
			config: to block! config
		]
		save-file 'config name' config
	]
	
	load-state: function [
		"Load program state"
		/defaults defaults' [map!] "Provide defaults for unspecified fields"
		/name "Provide custom state filename"
			name' [file!] "Defaults to <script-name>.state"
	][
		unless name' [name': rejoin [as file! script-name ".state"]]	;@@ use advanced-function or default
		data: make map! any [load-file 'state name'  16]		;-- silently allow absence of state
		if defaults' [data: extend defaults' data]
		data
	]
	
	save-state: function [
		"Save program state"
		state [map!]
		/name "Provide custom state filename"
			name' [file!] "Defaults to <script-name>.state"
	][
		unless name' [name': rejoin [as file! script-name ".state"]]	;@@ use advanced-function or default
		unless find [%.redbin %.json] suffix? name' [			;-- remove #() decoration from Red files
			state: to block! state
		]
		save-file/all 'state name' state
	]
	
];data-store: context [
];#local [

; data-store/portable?: on
; ?? data-store/paths	
; ?? data-store/script-name	
; probe data-store/find-file 'data %pic.jpg
; probe data-store/make-path 'data %pic.jpg
; probe data-store/make-path 'config %program.conf
; probe data-store/make-path 'state %.lock
