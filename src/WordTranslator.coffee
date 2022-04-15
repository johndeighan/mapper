# WordTranslator.coffee

import {undef} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'

import {slurpTAML} from '@jdeighan/mapper/taml'

# ---------------------------------------------------------------------------

export class WordTranslator

	constructor: (dictPath=undef) ->

		debug "enter WordTranslator()"
		@hDict = {}
		if dictPath
			@load(dictPath)
		debug "return from WordTranslator()"

	# ..........................................................

	translate: (word) ->

		return @hDict[word]

	# ..........................................................

	findWords: (sent) ->
		# --- returns {
		#        lFound: [ [<word>, <trans>, <startPos>, <endPos>], .. ]
		#        newString: <string>
		#        }

		lFound = []

		func = (match, offset) ->
			if trans = @hDict[match.toLowerCase()]
				lFound.push([match, trans, offset, offset + match.length])
				return trans
			else
				return match

		newString = sent.replace(/\w+/g, func)
		return {
			lFound
			newString
			}

	# ..........................................................

	load: (dictPath) ->

		debug "enter load('#{dictPath}')"
		for key,trans of slurpTAML(dictPath)
			pos = key.indexOf('(')
			if pos == -1
				@hDict[key] = trans
			else
				word = key.substring(0, pos)
				@hDict[word] = trans

				epos = key.indexOf(')', pos)

				ext = key.substring(pos+1, epos)
				@hDict[combine(word, ext)] = trans

				pos = key.indexOf('(', epos)
				while pos != -1
					epos = key.indexOf(')', pos)
					ext = key.substring(pos+1, epos)
					@hDict[combine(word, ext)] = trans
					pos = key.indexOf('(', epos)
		nKeys = Object.keys(@hDict).length
		debug "#{nKeys} words loaded"
		debug "return from load()"
		return

# ---------------------------------------------------------------------------

combine = (word, ext) ->

	if ext.indexOf('--') == 0
		len = word.length
		return word.substring(0, len-2) + ext.substring(2)
	else if ext.indexOf('-') == 0
		len = word.length
		return word.substring(0, len-1) + ext.substring(1)
	return word + ext
