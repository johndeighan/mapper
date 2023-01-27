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
	result = html \
		.replace(/\{/g, '&lbrace;') \
		.replace(/\}/g, '&rbrace;') \
		.replace(/\$/g, '&dollar;')
	dbgReturn "markdownify", result
	return result
