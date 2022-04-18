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
		@lFound = undef
		debug "return from Translator()", @hDict

	# ..........................................................

	translate: (word) ->

		return @hDict[word.toLowerCase()]

	# ..........................................................

	found: (str, trans, pos, end) ->

		@lFound.push([str, trans, pos, end])
		return

	# ..........................................................

	findWords: (sent, lPhrases=[]) ->
		# --- lPhrases should have list of {en, zh, pinyin}
		# --- returns [ [<word>, <trans>, <startPos>, <endPos>], .. ]

		debug "enter findWords()", sent
		if nonEmpty(lPhrases)
			debug "lPhrases", lPhrases
		@lFound = []

		for h in lPhrases
			phrase = h.en
			start = sent.indexOf(phrase)
			if start > -1
				end = start + phrase.length
				@found phrase, "#{h.zh} #{h.pinyin}", start, end

		# --- We need to use a "fat arrow" function here
		#     to prevent 'this' being replaced
		func = (match, start) =>
			end = start + match.length
			if trans = @translate(match)
				# --- Don't add if it overlaps with other entry in @lFound
				if ! @hasOverlap(start, end)
					@found match, trans, start, end
			return match

		# --- This will find all matches - it doesn't actually replace
		newString = sent.replace(/\w+/g, func)
		lFound = @lFound
		@lFound = undef
		debug "return from findWords()", lFound
		return lFound

	# ..........................................................

	hasOverlap: (start, end) ->

		assert start <= end, "hasOverlap(): Bad positions"
		for lInfo in @lFound
			[_, _, pStart, pEnd] = lInfo
			assert pStart <= pEnd, "hasOverlap(): Bad phrase positions"
			if (start <= pEnd) && (end >= pStart)
				return true
		return false

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
