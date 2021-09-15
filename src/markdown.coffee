# markdown.coffee

import {strict as assert} from 'assert'
import marked from 'marked'

import {oneline} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {undented} from '@jdeighan/coffee-utils/indent'
import {svelteHtmlEsc} from '@jdeighan/coffee-utils/svelte'

convert = true

# ---------------------------------------------------------------------------

export convertMarkdown = (flag) ->

	convert = flag
	return

# ---------------------------------------------------------------------------

export markdownify = (text) ->

	debug "enter markdownify(#{oneline(text)})"
	if not convert
		debug "return original text from markdownify() - not converting"
		return text
	html = marked(undented(text), {
			grm: true,
			headerIds: false,
			})
	debug "marked returned #{oneline(html)}"
	result = svelteHtmlEsc(html)
	debug "return #{oneline(result)} from markdownify()"
	return result
