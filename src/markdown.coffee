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

convert = true

# ---------------------------------------------------------------------------

export convertMarkdown = (flag) ->

	convert = flag
	return

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
	if ! convert
		debug "return original text from markdownify() - not converting"
		return block
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

	mapItem: (item) ->

		debug "enter mapItem(#{OL(item)})"
		assert defined(item), "item is undef"
		assert isString(item), "item not a string"
		if isEmpty(item) || isHashComment(item)
			debug "return undef from mapItem()"
			return undef   # ignore empty lines and comments
		else if item.match(/^={3,}$/) && defined(@prevLine)
			result = "<h1>#{@prevLine}</h1>"
			debug "set prevLine to undef"
			@prevLine = undef
			debug "return from mapItem()", result
			return result
		else
			result = @prevLine
			debug "set prevLine to #{OL(item)}"
			@prevLine = item
			if defined(result)
				result = "<p>#{result}</p>"
				debug "return from mapItem()", result
				return result
			else
				debug "return undef from mapItem()"
				return undef

	endBlock: () ->

		if defined(@prevLine)
			return "<p>#{@prevLine}</p>"
		else
			return undef
