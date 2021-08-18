# pll.test.coffee

import {strict as assert} from 'assert'

import {AvaTester} from '@jdeighan/ava-tester'
import {
	say, undef, error, taml, warn, rtrim,
	} from '@jdeighan/coffee-utils'
import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {patch} from '@jdeighan/coffee-utils/heredoc'
import {Getter} from '@jdeighan/string-input/get'

simple = new AvaTester()

# ---------------------------------------------------------------------------

(() ->

	getter = new Getter([1, 2, 3])

	simple.equal 21, getter.peek(), 1
	simple.equal 22, getter.peek(), 1
	simple.falsy 23, getter.eof()
	simple.equal 24, getter.get(), 1
	simple.equal 25, getter.get(), 2

	simple.falsy 27, getter.eof()
	simple.succeeds 28, () -> getter.unget(5)
	simple.fails 29, () -> getter.unget(5)
	simple.equal 30, getter.get(), 5
	simple.falsy 31, getter.eof()

	simple.equal 33, getter.get(), 3
	simple.truthy 34, getter.eof()
	simple.succeeds 35, () -> getter.unget(13)
	simple.falsy 36, getter.eof()
	simple.equal 37, getter.get(), 13
	simple.truthy 38, getter.eof()
	)()

# ---------------------------------------------------------------------------
