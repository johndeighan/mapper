# getter.test.coffee

import assert from 'assert'

import {UnitTester} from '@jdeighan/unit-tester'
import {
	undef, error, warn, rtrim,
	} from '@jdeighan/coffee-utils'
import {Getter} from '@jdeighan/string-input/get'

simple = new UnitTester()

# ---------------------------------------------------------------------------

(() ->

	getter = new Getter([1, 2, 3])

	simple.equal 20, getter.peek(), 1
	simple.equal 21, getter.peek(), 1
	simple.falsy 22, getter.eof()
	simple.equal 23, getter.get(), 1
	simple.equal 24, getter.get(), 2

	simple.falsy 26, getter.eof()
	simple.succeeds 27, () -> getter.unget(5)
	simple.fails 28, () -> getter.unget(5)
	simple.equal 29, getter.get(), 5
	simple.falsy 30, getter.eof()

	simple.equal 32, getter.get(), 3
	simple.truthy 33, getter.eof()
	simple.succeeds 34, () -> getter.unget(13)
	simple.falsy 35, getter.eof()
	simple.equal 36, getter.get(), 13
	simple.truthy 37, getter.eof()
	)()

# ---------------------------------------------------------------------------
