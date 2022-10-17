# markdown.coffee

import {marked} from 'marked'

import {LOG, LOGVALUE, assert, croak, debug} from '@jdeighan/exceptions'
import {
	undef, defined, OL, isEmpty, nonEmpty, isString,
	} from '@jdeighan/coffee-utils'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {undented} from '@jdeighan/coffee-utils/indent'
import {svelteHtmlEsc} from '@jdeighan/coffee-utils/svelte'

import {isHashComment} from '@jdeighan/mapper/utils'
import {TreeMapper} from '@jdeighan/mapper/tree'

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

export class SimpleMarkDownMapper extends TreeMapper

	beginLevel: (level) ->

		if (level == 0)
			@prevStr = undef
		return

	# ..........................................................

	visit: (hNode) ->

		debug "enter SimpleMarkDownMapper.visit()", hNode
		{str} = hNode
		if str.match(/^={3,}$/) && defined(@prevStr)
			result = "<h1>#{@prevStr}</h1>"
			debug "set prevStr to undef"
			@prevStr = undef
			debug "return from SimpleMarkDownMapper.visit()", result
			return result
		else if str.match(/^-{3,}$/) && defined(@prevStr)
			result = "<h2>#{@prevStr}</h2>"
			debug "set prevStr to undef"
			@prevStr = undef
			debug "return from SimpleMarkDownMapper.visit()", result
			return result
		else
			result = @prevStr
			debug "set prevStr to #{OL(str)}"
			@prevStr = str
			if defined(result)
				result = "<p>#{result}</p>"
				debug "return from SimpleMarkDownMapper.visit()", result
				return result
			else
				debug "return undef from SimpleMarkDownMapper.visit()"
				return undef

	# ..........................................................

	endLevel: (hUser, level) ->

		if (level == 0) && defined(@prevStr)
			return "<p>#{@prevStr}</p>"
		else
			return undef
