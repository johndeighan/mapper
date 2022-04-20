# taml.coffee

import yaml from 'js-yaml'

import {
	assert, undef, oneline, isString,
	} from '@jdeighan/coffee-utils'
import {
	untabify, tabify, splitLine,
	} from '@jdeighan/coffee-utils/indent'
import {log, tamlStringify} from '@jdeighan/coffee-utils/log'
import {slurp, forEachLineInFile} from '@jdeighan/coffee-utils/fs'
import {debug} from '@jdeighan/coffee-utils/debug'
import {firstLine, blockToArray} from '@jdeighan/coffee-utils/block'

import {Mapper, doMap} from '@jdeighan/mapper'

# ---------------------------------------------------------------------------
#   isTAML - is the string valid TAML?

export isTAML = (text) ->

	return isString(text) && (firstLine(text).indexOf('---') == 0)

# ---------------------------------------------------------------------------
#   taml - convert valid TAML string to a JavaScript value

export taml = (text, hOptions={}) ->
	# --- Valid options:
	#        premapper - a subclass of Mapper

	debug "enter taml(#{oneline(text)})"
	if ! text?
		debug "return undef from taml() - text is not defined"
		return undef

	# --- If a premapper is provided, use it to map the text
	if hOptions.premapper
		assert hOptions.source, "taml(): premapper without source"
		text = doMap(hOptions.premapper, text, hOptions.source)

	assert isTAML(text), "taml(): string #{oneline(text)} isn't TAML"
	debug "return from taml()"
	return yaml.load(untabify(text), {skipInvalid: true})

# ---------------------------------------------------------------------------
#   slurpTAML - read TAML from a file

export slurpTAML = (filepath) ->

	contents = slurp(filepath)
	return taml(contents)

# ---------------------------------------------------------------------------
# --- Plugin for a TAML HEREDOC type

export class TAMLHereDoc

	myName: () ->
		return 'taml'

	isMyHereDoc: (block) ->
		return isTAML(block)

	map: (block) ->
		obj = taml(block)
		return {
			obj
			str: JSON.stringify(obj)
			}
# ---------------------------------------------------------------------------
# A Mapper useful for stories

export class StoryMapper extends Mapper

	mapLine: (line, level) ->
		if lMatches = line.match(///
				([A-Za-z_][A-Za-z0-9_]*)  # identifier
				\:                        # colon
				\s*                       # optional whitespace
				(.+)                      # a non-empty string
				$///)
			[_, ident, str] = lMatches

			if str.match(///
					\d+
					(?:
						\.
						\d*
						)?
					$///)
				return line
			else
				# --- surround with single quotes, double internal single quotes
				str = "'" + str.replace(/\'/g, "''") + "'"
				return "#{ident}: #{str}"
		else
			return line
