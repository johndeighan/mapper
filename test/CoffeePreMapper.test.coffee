# CoffeePreMapper.test.coffee

import assert from 'assert'

import {UnitTester} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {StarbucksPreMapper} from '@jdeighan/string-input/coffee'
import {convertCoffee} from '@jdeighan/string-input/coffee'

convertCoffee false

# ---------------------------------------------------------------------------

class GatherTester extends UnitTester

	transformValue: (oInput) ->
		assert oInput instanceof StarbucksPreMapper,
			"oInput should be a StarbucksPreMapper object"
		return oInput.getAllText()

	# --- disable normalizing so we can check for proper indentation
	normalize: (str) ->
		return str

tester = new GatherTester()

# ===========================================================================
# Repeat all SmartInput tests using StarbucksPreMapper
# They should all pass
# ===========================================================================

# ---------------------------------------------------------------------------
# --- test removing comments and empty lines

tester.equal 35, new StarbucksPreMapper("""
		abc

		# --- a comment
		def
		"""), """
		abc
		def
		"""

# ---------------------------------------------------------------------------
# --- test overriding handling of comments and empty lines

class CustomInput extends StarbucksPreMapper

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

tester.equal 75, new StarbucksPreMapper("""
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

tester.equal 90, new StarbucksPreMapper("""
		h1 color=<<<
			magenta

		# --- a comment
		p the end
		"""), """
		h1 color="magenta"
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test HEREDOC with continuation lines

tester.equal 104, new StarbucksPreMapper("""
		h1 color=<<<
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

tester.equal 119, new StarbucksPreMapper("""
		h1 color=<<<
			color
			.
			magenta

		# --- a comment
		p the end
		"""), """
		h1 color="color\\n\\nmagenta"
		p the end
		"""

# ---------------------------------------------------------------------------
# --- test using '.' in a HEREDOC

tester.equal 135, new StarbucksPreMapper("""
		h1 color=<<<
			...color
			.
			magenta

		# --- a comment
		p the end
		"""), """
		h1 color="color magenta"
		p the end
		"""

# ===========================================================================
# StarbucksPreMapper specific tests
# ===========================================================================

# ---------------------------------------------------------------------------
# --- Test basic mapping

tester.equal 139, new StarbucksPreMapper("""
		x = 23
		if x > 10
			console.log "OK"
		"""), """
		x = 23
		if x > 10
			console.log "OK"
		"""

# ---------------------------------------------------------------------------
# --- Test live assignment

tester.equal 152, new StarbucksPreMapper("""
		x <== 2 * y
		if x > 10
			console.log "OK"
		"""), """
		`$:`
		x = 2 * y
		if x > 10
			console.log "OK"
		"""

# ---------------------------------------------------------------------------
# --- Test live execution

(() ->
	count = undef
	tester.equal 168, new StarbucksPreMapper("""
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
	tester.equal 183, new StarbucksPreMapper("""
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
	tester.equal 200, new StarbucksPreMapper("""
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
