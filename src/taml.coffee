# taml.coffee

import {strict as assert} from 'assert'
import yaml from 'js-yaml'

import {
	undef, firstLine, oneline, isString,
	} from '@jdeighan/coffee-utils'
import {untabify, tabify} from '@jdeighan/coffee-utils/indent'
import {slurp} from '@jdeighan/coffee-utils/fs'
import {debug} from '@jdeighan/coffee-utils/debug'

# ---------------------------------------------------------------------------
#   isTAML - is the string valid TAML?

export isTAML = (text) ->

	return isString(text) && (firstLine(text).indexOf('---') == 0)

# ---------------------------------------------------------------------------
#   taml - convert valid TAML string to a JavaScript value

export taml = (text) ->

	debug "enter taml(#{oneline(text)})"
	if not text?
		debug "return undef from taml() - text is not defined"
		return undef
	assert isTAML(text), "taml(): string #{oneline(text)} isn't TAML"
	return yaml.load(untabify(text, 1))

# ---------------------------------------------------------------------------
#   tamlStringify - convert a data structure into a valid TAML string

export tamlStringify = (obj) ->

	if not obj?
		return 'undef'
	str = yaml.dump(obj, {
			skipInvalid: true
			indent: 1
			sortKeys: false
			lineWidth: -1
			})
	return "---\n" + tabify(str)

# ---------------------------------------------------------------------------
#   slurpTAML - read TAML from a file

export slurpTAML = (filepath) ->

	contents = slurp(filepath)
	return taml(contents)
