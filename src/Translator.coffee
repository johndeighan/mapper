# Translator.coffee

import {undef, assert, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'

import {slurpTAML} from '@jdeighan/mapper/taml'

# ---------------------------------------------------------------------------

export class Translator

	constructor: (dictPath=undef) ->

		debug "enter Translator()"
		@hDict = {}
		if dictPath
			@load(dictPath)
		debug "return from Translator()", @hDict

	# ..........................................................

	translate: (word) ->

		return @hDict[word.toLowerCase()]

	# ..........................................................

	findWords: (sent, lPhrases=[]) ->
		# --- lPhrases should have list of [<string>, <translation> ]
		# --- returns [ [<word>, <trans>, <startPos>, <endPos>], .. ]

		debug "enter findWords()", sent
		if nonEmpty(lPhrases)
			debug "lPhrases", lPhrases
		lFound = []

		for [phrase, trans] in lPhrases
			pos = sent.indexOf(phrase)
			if pos > -1
				lFound.push([phrase, trans, pos, pos + phrase.length])

		self = this
		doTrans = @translate
		func = (match, start) ->
			end = start + match.length
			if trans = doTrans.call(self, match)
				# --- Don't add if it overlaps with other entry in lFound
				if ! hasOverlap(start, end, lFound)
					lFound.push([match, trans, start, end])
			return match

		newString = sent.replace(/\w+/g, func)
		debug "return from findWords()", lFound
		return lFound

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

hasOverlap = (start, end, lFound) ->

	assert start <= end, "hasOverlap(): Bad positions"
	for lInfo in lFound
		[_, _, pStart, pEnd] = lInfo
		assert pStart <= pEnd, "hasOverlap(): Bad phrase positions"
		if (start <= pEnd) && (end >= pStart)
			return true
	return false

# ---------------------------------------------------------------------------

combine = (word, ext) ->

	if ext.indexOf('--') == 0
		len = word.length
		return word.substring(0, len-2) + ext.substring(2)
	else if ext.indexOf('-') == 0
		len = word.length
		return word.substring(0, len-1) + ext.substring(1)
	return word + ext
