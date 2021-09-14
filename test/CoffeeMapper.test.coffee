# CoffeeMapper.test.coffee

import {strict as assert} from 'assert'
import {undef, setUnitTesting} from '@jdeighan/coffee-utils'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {CoffeeMapper} from '@jdeighan/string-input'

# NOTE: In unit tests, CoffeeScript is NOT converted
#       to JavaScript

setUnitTesting(true)

# ---------------------------------------------------------------------------

class GatherTester extends UnitTester

	transformValue: (oInput) ->
		assert oInput instanceof CoffeeMapper,
			"oInput should be a CoffeeMapper object"
		return oInput.getAllText()

	normalize: (str) ->
		return str

tester = new GatherTester()

# ===========================================================================
# Repeat all SmartInput tests using CoffeeMapper
# They should all pass
# ===========================================================================

# ---------------------------------------------------------------------------
# --- test removing comments and empty lines

tester.equal 35, new CoffeeMapper("""
		abc

		# --- a comment
		def
		"""), """
		abc
		def
		"""

# ---------------------------------------------------------------------------
# --- test overriding handling of comments and empty lines

class CustomInput extends CoffeeMapper

	handleEmptyLine: () ->

		debug "in new handleEmptyLine()"
		return "line #{@lineNum} is empty"

	handleComment: () ->

		debug "in new handleComment()"
		return "line #{@lineNum} is a comment"

tester.equal 60, new CustomInput("""
		abc

		# --- a comment
		def
		"""), """
		abc
		line 2 is empty
		line 3 is a comment
		def
		"""

# ---------------------------------------------------------------------------
# --- test continuation lines

tester.equal 75, new CoffeeMapper("""
		h1 color=blue
				This is
				a title

		# --- a comment
		p the end
		"""), """
		h1 color=blue This is a title
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test HEREDOC

tester.equal 90, new CoffeeMapper("""
		h1 color="<<<"
			magenta

		# --- a comment
		p the end
		"""), """
		h1 color="magenta"
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test HEREDOC with continuation lines

tester.equal 104, new CoffeeMapper("""
		h1 color="<<<"
				This is a title
			magenta

		# --- a comment
		p the end
		"""), """
		h1 color="magenta" This is a title
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test using '.' in a HEREDOC

tester.equal 119, new CoffeeMapper("""
		h1 color="<<<"
			color
			.
			magenta

		# --- a comment
		p the end
		"""), """
		h1 color="color  magenta"
		p the end
		"""

# ===========================================================================
# CoffeeMapper specific tests
# ===========================================================================

setUnitTesting(false)

# ---------------------------------------------------------------------------
# --- Test basic mapping

tester.equal 139, new CoffeeMapper("""
		x = 23
		if x > 10
			console.log "OK"
		"""), """
		x = 23
		if x > 10
		\tconsole.log "OK"
		"""

# ---------------------------------------------------------------------------
# --- Test live assignment

tester.equal 152, new CoffeeMapper("""
		x <== 2 * y
		if x > 10
			console.log "OK"
		"""), """
		`$:`
		x = 2 * y
		if x > 10
		\tconsole.log "OK"
		"""

# ---------------------------------------------------------------------------
# --- Test live execution

(() ->
	count = undef
	tester.equal 168, new CoffeeMapper("""
			<==
				console.log "Count is \#{count}"
			"""), """
			`$:{`
			console.log "Count is \#{count}"
			`}`
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test live execution of a block

(() ->
	count = undef
	tester.equal 183, new CoffeeMapper("""
			<==
				double = 2 * count
				console.log "Count is \#{count}"
			"""), """
			`$:{`
			double = 2 * count
			console.log "Count is \#{count}"
			`}`
			"""
	)()

# ---------------------------------------------------------------------------
# --- Test live execution of a block when NOT unit testing

(() ->
	count = undef
	tester.equal 201, new CoffeeMapper("""
			<==
				double = 2 * count
				console.log "Count is \#{count}"
			"""), """
			`$:{`
			double = 2 * count
			console.log "Count is \#{count}"
			`}`
			"""
	)()

# ---------------------------------------------------------------------------