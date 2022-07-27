# markdown.coffee

import {marked} from 'marked'

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, defined, OL, isEmpty, nonEmpty, isString,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {undented} from '@jdeighan/coffee-utils/indent'
import {svelteHtmlEsc} from '@jdeighan/coffee-utils/svelte'

import {isHashComment} from '@jdeighan/mapper/utils'
import {Mapper} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------

stripComments = (block) ->

	lLines = []
	for line in blockToArray(block)
		if nonEmpty(line) && ! isHashComment(line)
			lLines.push line
	return lLines.join("\n")

# ---------------------------------------------------------------------------

export markdownify = (block) ->

	debug "enter markdownify()", block
	assert isString(block), "block is not a string"
	html = marked.parse(undented(stripComments(block)), {
		grm: true,
		headerIds: false,
		})
	debug "marked returned", html
	result = svelteHtmlEsc(html)
	debug "return from markdownify()", result
	return result

# ---------------------------------------------------------------------------
# --- Does not use marked!!!
#     just simulates markdown processing

export class SimpleMarkDownMapper extends Mapper

	init: () ->

		@prevStr = undef
		return

	# ..........................................................

	mapNonSpecial: (hLine) ->

		debug "enter SimpleMarkDownMapper.map()", hLine
		assert defined(hLine), "hLine is undef"
		{str} = hLine
		assert isString(str), "str not a string"
		if str.match(/^={3,}$/) && defined(@prevStr)
			result = "<h1>#{@prevStr}</h1>"
			debug "set prevStr to undef"
			@prevStr = undef
			debug "return from SimpleMarkDownMapper.map()", result
			return result
		else
			result = @prevStr
			debug "set prevStr to #{OL(str)}"
			@prevStr = str
			if defined(result)
				result = "<p>#{result}</p>"
				debug "return from SimpleMarkDownMapper.map()", result
				return result
			else
				debug "return undef from SimpleMarkDownMapper.map()"
				return undef

	# ..........................................................

	endBlock: () ->

		if defined(@prevStr)
			return "<p>#{@prevStr}</p>"
		else
			return undef
