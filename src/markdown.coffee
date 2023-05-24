# markdown.coffee

import {marked} from 'marked'
import sanitizeHtml from 'sanitize-html'

import {
	undef, defined, notdefined, OL, isEmpty, nonEmpty, isString,
	toArray, toBlock, isHashComment,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG, LOGVALUE} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {undented} from '@jdeighan/coffee-utils/indent'

import {TreeMapper} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------

export markdownify = (block) ->

	dbgEnter "markdownify", block
	assert isString(block), "block is not a string"

	# --- Remove leading zero-width characters
	block = block.replace(/^[\u200B\u200C\u200D\u200E\u200F\uFEFF]/, '')

	# --- get array of lines
	lLines = toArray(block)

	# --- remove hash comments
	lLines = lLines.filter((line) => ! isHashComment(line));

	# --- unindent
	lLines = undented(lLines)

	html = marked.parse(toBlock(lLines), {headerIds: false, mangle: false})
	html = sanitizeHtml(html, {
		allowedAttributes: {
			'*': [ 'class']
			}
		})
	dbg "marked returned", html
	result = html \
		.replace(/\{/g, '&lbrace;') \
		.replace(/\}/g, '&rbrace;') \
		.replace(/\$/g, '&dollar;')
	dbgReturn "markdownify", result
	return result
