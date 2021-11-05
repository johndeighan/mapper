# markdown.coffee

import {marked} from 'marked'

import {assert, OL} from '@jdeighan/coffee-utils'
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

	debug "enter markdownify(#{OL(text)})"
	assert text?, "markdownify(): text is undef"
	if ! convert
		debug "return original text from markdownify() - not converting"
		return text
	html = marked.parse(undented(text), {
		grm: true,
		headerIds: false,
		})
	debug "marked returned #{OL(html)}"
	result = svelteHtmlEsc(html)
	debug "return #{OL(result)} from markdownify()"
	return result
