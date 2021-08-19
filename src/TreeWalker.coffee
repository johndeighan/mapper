# TreeWalker.coffee

import {
	say, pass, undef, error, warn, isString,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {indentStr} from '@jdeighan/coffee-utils/indent'
import {Getter} from '@jdeighan/string-input/get'

# ---------------------------------------------------------------------------

export class TreeWalker

	walk: (tree) ->

		debug "enter walk()"
		getter = new Getter(tree)
		@procNodes getter, 0
		debug "return from walk()"
		return

	procNodes: (getter, level=0) ->

		debug "enter procNodes()"
		while hNode = getter.get()
			{lineNum, node, body} = hNode
			@visit node, body, lineNum, getter, level
		debug "return from procNodes()"
		return

	visit: (node, body, lineNum, getter, level) ->

		return

# ---------------------------------------------------------------------------

export class TreePrinter extends TreeWalker

	constructor: () ->

		super()
		@lLines = []

	visit: (node, body, lineNum, getter, level) ->

		assert isString(node), "TreePrinter: node is not a string"
		@lLines.push indentStr(node, level)
		return

	get: () ->

		return @lLines.join('\n')
