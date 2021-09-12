# markdown.coffee

import {strict as assert} from 'assert'
import marked from 'marked'

import {unitTesting, oneline} from '@jdeighan/coffee-utils'
import {debug} from '@jdeighan/coffee-utils/debug'
import {undented} from '@jdeighan/coffee-utils/indent'
import {svelteHtmlEsc} from '@jdeighan/coffee-utils/svelte'

# ---------------------------------------------------------------------------

export markdownify = (text) ->

	debug "enter markdownify(#{oneline(text)})"
	if unitTesting
		debug "return original text - in unit test"
		return text
	html = marked(undented(text), {
			grm: true,
			headerIds: false,
			})
	debug "marked returned #{oneline(html)}"
	result = svelteHtmlEsc(html)
	debug "return #{oneline(result)}"
	return result
