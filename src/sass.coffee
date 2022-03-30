# sass.coffee

import sass from 'sass'

import {assert, undef, isComment} from '@jdeighan/coffee-utils'

import {StringInput} from '@jdeighan/string-input'

convert = true

# ---------------------------------------------------------------------------

export convertSASS = (flag) ->

	convert = flag
	return

# ---------------------------------------------------------------------------

export class SassMapper extends StringInput
	# --- only removes comments

	mapLine: (line, level) ->

		if isComment(line)
			return undef
		else
			return line

# ---------------------------------------------------------------------------

export sassify = (text) ->

	oInput = new SassMapper(text)
	newtext = oInput.getAllText()
	if ! convert
		return newtext
	result = sass.renderSync({
		data: newtext,
		indentedSyntax: true,
		indentType: "tab",
		})
	return result.css.toString()
