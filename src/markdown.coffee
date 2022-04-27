# markdown.coffee

import {marked} from 'marked'

import {
	assert, OL, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {blockToArray} from '@jdeighan/coffee-utils/block'
import {undented} from '@jdeighan/coffee-utils/indent'
import {svelteHtmlEsc} from '@jdeighan/coffee-utils/svelte'

import {isComment} from '@jdeighan/mapper/utils'

convert = true

# ---------------------------------------------------------------------------

export convertMarkdown = (flag) ->

	convert = flag
	return

# ---------------------------------------------------------------------------

stripComments = (block) ->

	lLines = []
	for line in blockToArray(block)
		if nonEmpty(line) && ! isComment(line)
			lLines.push line
	return lLines.join("\n")

# ---------------------------------------------------------------------------

export markdownify = (block) ->

	debug "enter markdownify()", block
	assert block?, "markdownify(): block is undef"
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
