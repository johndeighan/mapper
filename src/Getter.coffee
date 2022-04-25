# Getter.coffee

import {
	assert, undef, pass, croak, isFunction,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'

# ---------------------------------------------------------------------------
#   class Getter - get(), unget(), peek(), eof()

export class Getter

	constructor: (obj) ->

		debug "enter Getter()"
		@iterator = obj[Symbol.iterator]()
		assert @iterator.next?, "Getter(): Not an iterator"
		assert isFunction(@iterator.next), "Getter(): next not a function"
		@lLookAhead = []
		debug "return from Getter()"

	# ..........................................................

	hasLookAhead: () ->

		return @lLookAhead.length > 0

	# ..........................................................

	lookahead: () ->

		if @hasLookAhead()
			return @lLookAhead[@lLookAhead.length - 1]
		else
			return undef

	# ..........................................................

	get: () ->

		debug "enter Getter.get()"
		if @hasLookAhead()
			item = @lLookAhead.shift()
			debug "return from Getter.get() with lookahead:", item
			return item
		{value, done} = @iterator.next()
		if done
			debug "return undef from Getter.get() - done == true"
			return undef
		debug "return from Getter.get()", value
		return value

	# ..........................................................

	unget: (value) ->

		debug "enter Getter.unget()", value
		assert value?, "unget(): value must be defined"
		@lLookAhead.unshift value
		debug "return from Getter.unget()"
		return

	# ..........................................................

	peek: () ->

		debug 'enter Getter.peek():'
		if @hasLookAhead()
			value = @lookahead()
			debug 'lLookAhead', @lLookAhead
			debug "return lookahead from Getter.peek()", value
			return value
		debug "no lookahead"
		{value, done} = @iterator.next()
		debug "from next()", {value, done}
		if done
			debug 'lLookAhead', @lLookAhead
			debug "return undef from Getter.peek()"
			return undef
		@unget(value)
		debug 'lLookAhead', @lLookAhead
		debug 'return from Getter.peek()', value
		return value

	# ..........................................................

	skip: () ->

		debug 'enter Getter.skip():'
		if @hasLookAhead()
			@lLookAhead.shift()
			debug "return from Getter.skip(): clear lookahead"
			return
		@iterator.next()
		debug 'return from Getter.skip()'
		return

	# ..........................................................

	eof: () ->

		debug "enter Getter.eof()"
		if @hasLookAhead()
			debug "return false from Getter.eof() - lookahead exists"
			return false
		{value, done} = @iterator.next()
		debug "from next()", {value, done}
		if done
			debug "return true from Getter.eof()"
			return true
		@unget value
		debug "return false from Getter.eof()"
		return false
