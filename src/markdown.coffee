# markdown.coffee

import {marked} from 'marked'

import {
	assert, undef, defined, OL, isEmpty, nonEmpty, isString,
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

export class SimpleMarkDownMapper extends Mapper

	init: () ->

		@prevLine = undef
		return

	# ..........................................................

	mapEmptyLine: (hLine) ->

		return undef

	# ..........................................................

	mapComment: (hLine) ->

		return undef

	# ..........................................................

	map: (hLine) ->

		debug "enter SimpleMarkDownMapper.map()", hLine
		assert defined(hLine), "hLine is undef"
		{line} = hLine
		assert isString(line), "line not a string"
		if line.match(/^={3,}$/) && defined(@prevLine)
			result = "<h1>#{@prevLine}</h1>"
			debug "set prevLine to undef"
			@prevLine = undef
			debug "return from SimpleMarkDownMapper.map()", result
			return result
		else
			result = @prevLine
			debug "set prevLine to #{OL(line)}"
			@prevLine = line
			if defined(result)
				result = "<p>#{result}</p>"
				debug "return from SimpleMarkDownMapper.map()", result
				return result
			else
				debug "return undef from SimpleMarkDownMapper.map()"
				return undef

	# ..........................................................

	endBlock: () ->

		if defined(@prevLine)
			return "<p>#{@prevLine}</p>"
		else
			return undef
