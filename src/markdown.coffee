# markdown.coffee

import {marked} from 'marked'

import {
	undef, defined, OL, isEmpty, nonEmpty, isString, toArray,
	isHashComment,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {undented} from '@jdeighan/coffee-utils/indent'
import {svelteHtmlEsc} from '@jdeighan/coffee-utils/svelte'

import {TreeMapper} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------

stripComments = (block) ->

	lLines = []
	for line in toArray(block)
		if nonEmpty(line) && ! isHashComment(line)
			lLines.push line
	return lLines.join("\n")

# ---------------------------------------------------------------------------

export markdownify = (block) ->

	dbgEnter "markdownify", block
	assert isString(block), "block is not a string"
	html = marked.parse(undented(stripComments(block)), {
		grm: true,
		headerIds: false,
		})
	dbg "marked returned", html
	result = svelteHtmlEsc(html)
	dbgReturn "markdownify", result
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

		dbgEnter "SimpleMarkDownMapper.visit", hNode
		{str} = hNode
		if str.match(/^={3,}$/) && defined(@prevStr)
			result = "<h1>#{@prevStr}</h1>"
			dbg "set prevStr to undef"
			@prevStr = undef
			dbgReturn "SimpleMarkDownMapper.visit", result
			return result
		else if str.match(/^-{3,}$/) && defined(@prevStr)
			result = "<h2>#{@prevStr}</h2>"
			dbg "set prevStr to undef"
			@prevStr = undef
			dbgReturn "SimpleMarkDownMapper.visit", result
			return result
		else
			result = @prevStr
			dbg "set prevStr to #{OL(str)}"
			@prevStr = str
			if defined(result)
				result = "<p>#{result}</p>"
				dbgReturn "SimpleMarkDownMapper.visit", result
				return result
			else
				dbgReturn "SimpleMarkDownMapper.visit", undef
				return undef

	# ..........................................................

	endLevel: (hUser, level) ->

		if (level == 0) && defined(@prevStr)
			return "<p>#{@prevStr}</p>"
		else
			return undef
