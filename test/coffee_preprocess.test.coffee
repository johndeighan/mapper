# coffee_preprocess.test.coffee

import {UnitTester, UnitTesterNorm, simple} from '@jdeighan/unit-tester'
import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, rtrim, replaceVars,
	} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {setDebugging} from '@jdeighan/coffee-utils/debug'

import {doMap} from '@jdeighan/mapper'
import {CoffeePreProcessor} from '@jdeighan/mapper/coffee'

# ---------------------------------------------------------------------------

class MyTester extends UnitTester

	transformValue: (block) ->

		return doMap(CoffeePreProcessor, import.meta.url, block)

# ..........................................................

tester = new MyTester()

setDebugging 'map'

tester.equal 29, """
		x = 3
		debug "word is $word"
		""", """
		x = 3
		debug "word is \#{OL(word)}"
		"""

tester.equal 37, """
		x = 3
		debug "word is $word, not $this"
		""", """
		x = 3
		debug "word is \#{OL(word)}, not \#{OL(this)}"
		"""
