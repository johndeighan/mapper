# Getter.coffee

import {strict as assert} from 'assert'
import {undef, say, pass, error} from '@jdeighan/coffee-utils'
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
			debug "return with lookahead token #{saved}"
			return saved
		if (@pos == @len)
			return undef
		item = @lItems[@pos]
		@pos += 1
		debug "return #{item} from get()"
		return item

	unget: (item) ->

		debug "enter unget(#{item})"
		if @lookahead?
			debug "return FAILURE from unget() - lookahead exists"
			error "Getter.unget(): lookahead exists"
		@lookahead = item
		debug "return from unget()"
		return

	peek: () ->

		debug 'enter peek():'
		if @lookahead?
			debug "return lookahead token"
			return @lookahead
		item = @get()
		if not item?
			return undef
		@unget(item)
		debug item, 'return with:'
		return item

	skip: () ->

		debug 'enter skip():'
		if @lookahead?
			@lookahead = undef
			debug "return: clear lookahead token"
			return
		item = @get()
		debug 'return from skip()'
		return

	eof: () ->

		debug "enter eof()"
		atEnd = (@pos == @len) && not @lookahead?
		debug "return #{atEnd}"
		return atEnd
