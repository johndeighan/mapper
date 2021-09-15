# sass.coffee

import {strict as assert} from 'assert'
import sass from 'sass'

import {undef, isComment} from '@jdeighan/coffee-utils'
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
	if not convert
		return newtext
	result = sass.renderSync({
			data: newtext,
			indentedSyntax: true,
			indentType: "tab",
			})
	return result.css.toString()
