# sass.coffee

import {strict as assert} from 'assert'
import sass from 'sass'

import {undef, unitTesting} from '@jdeighan/coffee-utils'
import {SassMapper} from '@jdeighan/string-input'

# ---------------------------------------------------------------------------

export sassify = (text) ->

	oInput = new SassMapper(text)
	newtext = oInput.getAllText()
	if unitTesting
		return newtext
	result = sass.renderSync({
			data: newtext,
			indentedSyntax: true,
			indentType: "tab",
			})
	return result.css.toString()
