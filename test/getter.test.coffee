# getter.test.coffee

import {strict as assert} from 'assert'

import {
	say, undef, error, warn, rtrim,
	} from '@jdeighan/coffee-utils'
import {isTAML, taml} from '@jdeighan/string-input/convert'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {Getter} from '@jdeighan/string-input/get'

simple = new UnitTester()

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
