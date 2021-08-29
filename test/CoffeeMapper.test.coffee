# CoffeeMapper.test.coffee

import {AvaTester} from '@jdeighan/ava-tester'
import {undef, say, setUnitTesting} from '@jdeighan/coffee-utils'
import {StringInput} from '@jdeighan/string-input'
import {CoffeeMapper} from '@jdeighan/string-input'

# NOTE: In unit tests, CoffeeScript is NOT converted
#       to JavaScript

setUnitTesting(true)

# ---------------------------------------------------------------------------

class CoffeeMapperTester extends AvaTester

	transformValue: (text) ->
		oInput = new CoffeeMapper(text)
		return oInput.get()

tester = new CoffeeMapperTester()

# ---------------------------------------------------------------------------
# --- Test basic mapping

tester.equal 27, """
		x = 23
		if x > 10
			console.log "OK"
		""", """
		x = 23
		"""

# ---------------------------------------------------------------------------
# --- Test live assignment

tester.equal 38, """
		x <== 2 * y
		if x > 10
			console.log "OK"
		""", """
		`$: x = 2 * y`
		"""

# ---------------------------------------------------------------------------
# --- Test live execution

(() ->
	count = undef
	tester.equal 51, """
			<== console.log "Count is \#{count}"
			if x > 10
				console.log "OK"
			""", """
			`$: console.log "Count is \#{count}"`
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test live execution of a block

(() ->
	count = undef
	tester.equal 65, """
			<==
				double = 2 * count
				console.log "Count is \#{count}"
			if x > 10
				console.log "OK"
			""", """
			\`\`\`
			$: {
				double = 2 * count
				console.log "Count is \#{count}"
				}
			\`\`\`
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test live execution of a block when NOT unit testing

(() ->
	setUnitTesting(false)
	count = undef
	tester.equal 85, """
			<==
				double = 2 * count
				console.log "Count is \#{count}"
			if x > 10
				console.log "OK"
			""", """
			```
			$: {
				var double;
				double = 2 * count;
				console.log(`Count is \${count}`);
				}
			```
			"""
	setUnitTesting(true)
	)()

# ---------------------------------------------------------------------------
