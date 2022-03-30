# domap.test.coffee

import assert from 'assert'

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'

import {SmartInput, doMap} from '@jdeighan/string-input'

simple = new UnitTester()

# ---------------------------------------------------------------------------
# By default, a SmartInput:
#    1. removes blank lines
#    2. handles #include
#    3. joins continuation lines
#    4. sets variables via #define
#    5. replaces variables: DIR, FILE and LINE & others
#    6. stops on __END__
#    7. handles HEREDOCs
# ---------------------------------------------------------------------------

class MapTester extends UnitTesterNoNorm

	transformValue: ([myClass, text]) ->
		return doMap(myClass, text)

tester = new MapTester()

# ---------------------------------------------------------------------------
# --- by default, DO NOT remove comments

class MyInput extends SmartInput

	mapString: (line, level) ->
		return line.toUpperCase()

tester.equal 33, [MyInput, """
		# --- a comment
		abc

		def
		"""], """
		# --- a comment
		ABC
		DEF
		"""

# ---------------------------------------------------------------------------
# --- DO remove comments

class MyInput extends SmartInput

	mapString: (line, level) ->
		return line.toUpperCase()

	handleComment: (level) ->
		return undef

tester.equal 55, [MyInput, """
		# --- a comment
		abc

		def
		"""], """
		ABC
		DEF
		"""

# ---------------------------------------------------------------------------
# Retain empty lines

class MyInput extends SmartInput

	mapString: (line, level) ->
		return line.toUpperCase()

	handleEmptyLine: (level) ->
		return ''

tester.equal 76, [MyInput, """
		# --- a comment
		abc

		def
		"""], """
		# --- a comment
		ABC

		DEF
		"""

# ---------------------------------------------------------------------------
# Join continuation lines

class MyInput extends SmartInput

	mapString: (line, level) ->
		return line.toUpperCase()

	handleEmptyLine: (level) ->
		return ''

tester.equal 99, [MyInput, """
		# --- a comment
		abc
				def
		"""], """
		# --- a comment
		ABC DEF
		"""
