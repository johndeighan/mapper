# symbols.test.coffee

import {undef} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {getNeededSymbols} from '@jdeighan/string-input/coffee'

simple = new UnitTester()

# ---------------------------------------------------------------------------

code = """
		x = 23
		y = x \
		+ 5
		"""
simple.equal 12, getNeededSymbols(code), []
