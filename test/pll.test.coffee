# pll.test.coffee

import {strict as assert} from 'assert'

import {AvaTester} from '@jdeighan/ava-tester'
import {
	say, undef, error, isTAML, taml, warn, rtrim,
	} from '@jdeighan/coffee-utils'
import {PLLParser} from '@jdeighan/string-input/pll'

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

	oInput = new PLLParser(contents)
	tree = oInput.getTree()

	tester.equal 33, tree, taml("""
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

	class NewInput extends PLLParser

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

	tester.equal 147, tree, taml("""
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

# ---------------------------------------------------------------------------
# --- test HEREDOC handling

(() ->

	contents = """
			development = <<<
				yes

			if development
				color <<<
					=
					red

				if usemoods
					<<<
						mood
						=
						somber

			if not development
				color = blue
				if usemoods
					mood = happy
			"""

	oInput = new PLLParser(contents)
	tree = oInput.getTree()

	tester.equal 211, tree, taml("""
		---
		-
			lineNum: 1
			node: development = yes
		-
			lineNum: 4
			node: if development
			body:
				-
					lineNum: 5
					node: color = red
				-
					lineNum: 9
					node: if usemoods
					body:
						-
							lineNum: 10
							node: mood = somber
		-
			lineNum: 15
			node: if not development
			body:
				-
					lineNum: 16
					node: color = blue
				-
					lineNum: 17
					node: if usemoods
					body:
						-
							lineNum: 18
							node: mood = happy
			""")
	)()

# ---------------------------------------------------------------------------

(() ->

	class JSParser extends PLLParser

		heredocStr: (str) ->

			if isTAML(str)
				return taml(str)
			else
				return JSON.stringify(str)

	content = """
			x = 23
			str = <<<
				this is a
				long string
				of text

			console.log str
			"""

	oInput = new JSParser(content)
	tree = oInput.getTree()

	tester.equal 271, tree, [
		{
			lineNum: 1
			node: 'x = 23'
			},
		{
			lineNum: 2
			node: "str = \"this is a\\nlong string\\nof text\""
			},
		{
			lineNum: 7
			node: 'console.log str'
			},
		]

	)()
