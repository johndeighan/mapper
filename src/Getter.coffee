# Getter.coffee

import {strict as assert} from 'assert'
import {undef, pass, croak} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'

# ---------------------------------------------------------------------------
#   class Getter - get(), unget(), peek(), eof()
#   TODO: Currently works with arrays - make it work with any iterable!

export class Getter

	constructor: (@lItems) ->

		@lookahead = undef
		@pos = 0
		@len = @lItems.length
		debug "Construct a Getter"

	get: () ->

		debug "enter get()"
		if @lookahead?
			saved = @lookahead
			@lookahead = undef
			debug "return from get() with lookahead token:", saved
			return saved
		if (@pos == @len)
			return undef
		item = @lItems[@pos]
		@pos += 1
		debug "return from get() with:", item
		return item

	unget: (item) ->

		debug "enter unget(#{item})"
		if @lookahead?
			debug "return FAILURE from unget() - lookahead exists"
			croak "Getter.unget(): lookahead exists"
		@lookahead = item
		debug "return from unget()"
		return

	peek: () ->

		debug 'enter peek():'
		if @lookahead?
			debug "return lookahead token from peek()", @lookahead
			return @lookahead
		item = @get()
		if not item?
			return undef
		@unget(item)
		debug 'return from peek() with:', item
		return item

	skip: () ->

		debug 'enter skip():'
		if @lookahead?
			@lookahead = undef
			debug "return from skip(): clear lookahead token"
			return
		item = @get()
		debug 'return from skip()'
		return

	eof: () ->

		debug "enter eof()"
		atEnd = (@pos == @len) && not @lookahead?
		debug "return #{atEnd} from eof()"
		return atEnd
