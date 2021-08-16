# pll.test.coffee

import {strict as assert} from 'assert'

import {AvaTester} from '@jdeighan/ava-tester'
import {say, undef, error, taml, warn, rtrim} from '@jdeighan/coffee-utils'
import {PLLInput} from '@jdeighan/string-input/pll'

tester = new AvaTester()

# ---------------------------------------------------------------------------
# --- test using identity mapper

(() ->

	contents = """
			development = yes
			if development
				color = red
				if usemoods
					mood = somber
			if not development
				color = blue
				if usemoods
					mood = happy
			"""

	oInput = new PLLInput(contents)
	tree = oInput.getTree()

	tester.equal 30, tree, taml("""
		---
		-
			lineNum: 1
			node: development = yes
		-
			lineNum: 2
			node: if development
			body:
				-
					lineNum: 3
					node: color = red
				-
					lineNum: 4
					node: if usemoods
					body:
						-
							lineNum: 5
							node: mood = somber
		-
			lineNum: 6
			node: if not development
			body:
				-
					lineNum: 7
					node: color = blue
				-
					lineNum: 8
					node: if usemoods
					body:
						-
							lineNum: 9
							node: mood = happy
			""")
	)()

# ---------------------------------------------------------------------------

(() ->

	class NewInput extends PLLInput

		mapString: (str) ->

			if lMatches = str.match(///^
					([A-Za-z_]+)      # identifier
					\s*
					=
					\s*
					(.*)
					$///)
				[_, key, value] = lMatches
				return 'assign'
			else if lMatches = str.match(///^
					if
					\s+
					(?:
						(not)
						\s+
						)?
					([A-Za-z_]+)      # identifier
					$///)
				[_, neg, key] = lMatches
				if neg
					return 'if_falsy'
				else
					return 'if_truthy'
			else if lMatches = str.match(///^
					if
					\s+
					([A-Za-z_]+)      # identifier (key)
					\s*
					(
						  ==           # comparison operator
						| !=
						| >
						| >=
						| <
						| <=
						)
					\s*
					(?:
						  ([A-Za-z_]+)      # identifier
						| ([0-9]+)          # number
						| ' ([^']*) '       # single quoted string
						| " ([^"]*) "       # double quoted string
						)
					$///)
				[_, key, op, ident, number, sqstr, dqstr] = lMatches
				if ident
					return 'compare_ident'
				else if number
					return 'compare_number'
				else if sqstr || dqstr
					return 'compare_string'
				else
					error "Invalid line: '#{str}'"
			else
				error "Invalid line: '#{str}'"

	content = """
			if development
				color = red
				if debug > 2
					mood = somber
			if not development
				color = blue
				if debug >= 3
					mood = happy
			"""

	oInput = new NewInput(content)
	tree = oInput.getTree()

	tester.equal 139, tree, taml("""
			---
			-
				node: if_truthy
				lineNum: 1
				body:
					-
						node: assign
						lineNum: 2
					-
						node: compare_number
						lineNum: 3
						body:
							-
								node: assign
								lineNum: 4
			-
				node: if_falsy
				lineNum: 5
				body:
					-
						node: assign
						lineNum: 6
					-
						node: compare_number
						lineNum: 7
						body:
							-
								node: assign
								lineNum: 8
			""")

	)()
