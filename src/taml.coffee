# taml.coffee

import yaml from 'js-yaml'

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, defined, notdefined, OL, isString,
	} from '@jdeighan/coffee-utils'
import {
	untabify, tabify, splitLine,
	} from '@jdeighan/coffee-utils/indent'
import {LOG, log, tamlStringify} from '@jdeighan/coffee-utils/log'
import {slurp, forEachLineInFile} from '@jdeighan/coffee-utils/fs'
import {debug} from '@jdeighan/coffee-utils/debug'
import {firstLine, blockToArray} from '@jdeighan/coffee-utils/block'

import {Mapper, map} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------
#   isTAML - is the string valid TAML?

export isTAML = (text) ->

	return isString(text) && (firstLine(text).indexOf('---') == 0)

# ---------------------------------------------------------------------------
#   taml - convert valid TAML string to a JavaScript value

export taml = (text, hOptions={}) ->
	# --- Valid options:
	#        premapper - a subclass of Mapper

	debug "enter taml(#{OL(text)})"
	if ! text?
		debug "return undef from taml() - text is not defined"
		return undef

	# --- If a premapper is provided, use it to map the text
	if defined(hOptions.premapper)
		premapper = hOptions.premapper

		# --- THIS FAILS and I don't know why???
#		assert (premapper instanceof Mapper),
#				"not a Mapper subclass: #{OL(premapper)}"

		assert hOptions.source, "taml(): premapper without source"
		text = map(premapper, hOptions.source, text)

	assert isTAML(text), "taml(): string #{OL(text)} isn't TAML"
	result = yaml.load(untabify(text), {skipInvalid: true})
	debug "return from taml()", result
	return result

# ---------------------------------------------------------------------------
#   slurpTAML - read TAML from a file

export slurpTAML = (filepath, hOptions=undef) ->

	text = slurp(filepath)
	return taml(text, hOptions)

