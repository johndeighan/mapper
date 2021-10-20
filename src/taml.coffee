# taml.coffee

import assert from 'assert'
import yaml from 'js-yaml'

import {
	undef, oneline, isString,
	} from '@jdeighan/coffee-utils'
import {untabify, tabify} from '@jdeighan/coffee-utils/indent'
import {log, tamlStringify} from '@jdeighan/coffee-utils/log'
import {slurp} from '@jdeighan/coffee-utils/fs'
import {debug} from '@jdeighan/coffee-utils/debug'
import {firstLine} from '@jdeighan/coffee-utils/block'

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
#   slurpTAML - read TAML from a file

export slurpTAML = (filepath) ->

	contents = slurp(filepath)
	return taml(contents)
