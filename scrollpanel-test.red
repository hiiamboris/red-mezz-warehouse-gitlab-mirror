Red [
	title:   "SCROLLPANEL style demo"
	purpose: "Shows how to use the style"
	author:  @hiiamboris
	license: BSD-3
	needs:   view
]

#include %assert.red
#include %scrollpanel.red

view [
	s: scrollpanel 600x600 tight [space 0x0 below
		;; due to #5683 it's safer not to use a single big base
		base 1000x2500 draw [translate 0x0     fill-pen linear cyan 0.0 gold 0.5 magenta 1.0 0x0 500x500 reflect box 0x0 1000x10000]
		base 1000x2500 draw [translate 0x-2500 fill-pen linear cyan 0.0 gold 0.5 magenta 1.0 0x0 500x500 reflect box 0x0 1000x10000]
		base 1000x2500 draw [translate 0x-5000 fill-pen linear cyan 0.0 gold 0.5 magenta 1.0 0x0 500x500 reflect box 0x0 1000x10000]
		base 1000x2500 draw [translate 0x-7500 fill-pen linear cyan 0.0 gold 0.5 magenta 1.0 0x0 500x500 reflect box 0x0 1000x10000]
	]
]
