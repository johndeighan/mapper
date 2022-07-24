# TreeWalker.coffee

import {
	assert, undef, pass, croak, defined, OL, rtrim, words,
	isString, isNumber, isEmpty, nonEmpty, isArray, isHash, isInteger,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {log, LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {
	splitLine, indentLevel, indented, undented,
	} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Mapper} from '@jdeighan/mapper'
import {lineToParts, mapHereDoc} from '@jdeighan/mapper/heredoc'

# ===========================================================================
#   class TreeWalker
#      - map() returns mapped item (i.e. uobj) or undef
#   to use, override:
#      mapStr(str, srcLevel) - returns user object, default returns str
#      mapCmd(hLine)
#      beginWalk()
#      visit(hNode, hUser, lStack)
#      endVisit(hNode, hUser, lStack)
#      endWalk() -

export class TreeWalker extends Mapper

	constructor: (source=undef, collection=undef, hOptions={}) ->

		super source, collection, hOptions

		@hSpecialVisitTypes = {}

		@registerVisitType 'empty',   @visitEmptyLine, @endVisitEmptyLine
		@registerVisitType 'comment', @visitComment, @endVisitComment
		@registerVisitType 'cmd',     @visitCmd, @endVisitCmd

		@lMinuses = []   # used to adjust level in #ifdef and #ifndef

	# ..........................................................

	registerVisitType: (type, visiter, endVisiter) ->

		@hSpecialVisitTypes[type] = {
			visiter
			endVisiter
			}
		return

	# ..........................................................

	visitSpecial: (type, hNode) ->

		return @hSpecialVisitTypes[type].visiter.bind(this)(hNode)

	# ..........................................................

	endVisitSpecial: (type, hNode) ->

		return @hSpecialVisitTypes[type].endVisiter.bind(this)(hNode)

	# ..........................................................
	# --- Should always return either:
	#        undef
	#        uobj - mapped object
	# --- Will only receive non-special lines
	#     1. add extension lines
	#     2. replace HEREDOCs
	#     3. call mapStr()

	map: (hLine) ->
		# --- NOTE: We allow hLine.line to be a non-string
		#           But, in that case, to get tree functionality,
		#           the objects being iterated should have a level key
		#           If not, the level defaults to 0

		debug "enter TreeWalker.map()", hLine
		if @adjustLevel(hLine)
			debug "hLine adjusted", hLine

		{line, prefix, str, level, srcLevel} = hLine

		if ! isString(line)
			# --- may return undef
			uobj = mapNonStr(line)
			debug "return from TreeWalker.map()", uobj
			return uobj

		# --- from here on, line is a string
		assert nonEmpty(str), "empty string should be special"

		# --- check for extension lines, stop on blank line if found
		debug "check for extension lines"
		lExtLines = @fetchLinesAtLevel(srcLevel+2, {stopOn: ''})
		assert isArray(lExtLines), "lExtLines not an array"
		debug "#{lExtLines.length} extension lines"
		if isEmpty(lExtLines)
			debug "no extension lines"
		else
			@joinExtensionLines(hLine, lExtLines)
			debug "with ext lines", hLine
			{line, prefix, str} = hLine

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (str.indexOf('<<<') >= 0)
			newStr = @handleHereDocsInLine(str, srcLevel)
			if (newStr != str)
				str = newStr
				debug "=> #{OL(str)}"
		else
			debug "no HEREDOCs"

		# --- NOTE: mapStr() may return undef, meaning to ignore
		#     We must pass srcLevel since mapStr() may use fetch()
		uobj = @mapStr(str, srcLevel)
		debug "return from TreeWalker.map()", uobj
		return uobj

	# ..........................................................
	# --- designed to override

	mapStr: (str, srcLevel) ->

		return str

	# ..........................................................
	# --- designed to override

	mapNonStr: (item) ->

		return item

	# ..........................................................
	# --- can override to change how lines are joined

	joinExtensionLines: (hLine, lExtLines) ->
		# --- modifies keys line & str

		# --- There might be empty lines in lExtLines
		#     but we'll skip them here
		for hContLine in lExtLines
			if nonEmpty(hContLine.str)
				hLine.line += ' ' + hContLine.str
				hLine.str  += ' ' + hContLine.str
		return

	# ..........................................................

	handleHereDocsInLine: (line, srcLevel) ->
		# --- Indentation has been removed from line
		# --- Find each '<<<' and replace with result of mapHereDoc()

		debug "enter handleHereDocsInLine()", line
		assert isString(line), "not a string"
		lParts = lineToParts(line)
		debug 'lParts', lParts
		lNewParts = []    # to be joined to form new line
		for part in lParts
			if part == '<<<'
				debug "get HEREDOC lines at level #{srcLevel+1}"
				hOptions = {
					stopOn: ''
					discard: true    # discard the terminating empty line
					}

				# --- block will be undented
				block = @fetchBlockAtLevel(srcLevel+1, hOptions)
				debug 'block', block

				expr = mapHereDoc(block)
				assert defined(expr), "mapHereDoc returned undef"
				debug 'mapped block', expr

				str = @handleHereDoc(expr, block)
				assert defined(str), "handleHereDoc returned undef"
				lNewParts.push str
			else
				lNewParts.push part    # keep as is

		result = lNewParts.join('')
		debug "return from handleHereDocsInLine", result
		return result

	# ..........................................................

	handleHereDoc: (expr, block) ->

		return expr

	# ..........................................................

	extSep: (str, nextStr) ->

		return ' '

	# ..........................................................

	isEmptyHereDocLine: (str) ->

		return (str == '.')

	# ..........................................................

	mapComment: (hLine) ->

		debug "enter TreeWalker.mapComment()", hLine
		if @adjustLevel(hLine)
			debug "hLine adjusted", hLine

		{line, prefix, level, srcLevel} = hLine
		debug "srcLevel = #{srcLevel}"

		debug "return from TreeWalker.mapComment()", line
		return line

	# ..........................................................
	# --- We define commands 'ifdef' and 'ifndef'

	mapCmd: (hLine) ->

		debug "enter TreeWalker.mapCmd()", hLine
		if @adjustLevel(hLine)
			debug "hLine adjusted", hLine

		{cmd, argstr, prefix, srcLevel} = hLine
		debug "srcLevel = #{srcLevel}"

		# --- Handle our commands, returning if found
		switch cmd
			when 'ifdef', 'ifndef'
				[name, value, isEnv] = @splitDef(argstr)
				assert defined(name), "Invalid #{cmd}, argstr=#{OL(argstr)}"
				ok = @isDefined(name, value, isEnv)
				debug "ok = #{OL(ok)}"
				keep = if (cmd == 'ifdef') then ok else ! ok
				debug "keep = #{OL(keep)}"
				if keep
					debug "add #{srcLevel} to lMinuses"
					@lMinuses.push srcLevel
				else
					lSkipLines = @fetchLinesAtLevel(srcLevel+1)
					debug "Skip #{lSkipLines.length} lines"
				debug "return undef from TreeWalker.mapCmd()"
				return undef

		debug "call super"
		item = super(hLine)

		debug "return from TreeWalker.mapCmd()", item
		return item

	# ..........................................................

	adjustLevel: (hLine) ->

		debug "enter adjustLevel()", hLine
		if defined(hLine.level)
			hLine.srcLevel = srcLevel = hLine.level
			assert isInteger(srcLevel), "level is #{OL(srcLevel)}"
		else
			# --- if we're iterating non-strings, there won't be a level
			hLine.srcLevel = srcLevel = 0

		# --- Calculate the needed adjustment and new level
		lNewMinuses = []
		adjust = 0
		for i in @lMinuses
			if (srcLevel > i)
				adjust += 1
				lNewMinuses.push i
		@lMinuses = lNewMinuses
		debug 'lMinuses', @lMinuses

		if (adjust == 0)
			debug "return false from adjustLevel()"
			return false

		assert (srcLevel >= adjust), "srcLevel=#{srcLevel}, adjust=#{adjust}"
		newLevel = srcLevel - adjust

		# --- Make adjustments to hLine
		hLine.level = newLevel
		if isString(hLine.line)
			hLine.line = undented(hLine.line, adjust)
			hLine.prefix = undented(hLine.prefix, adjust)

		debug "level adjusted #{srcLevel} => #{newLevel}"
		debug "return true from adjustLevel()"
		return true

	# ..........................................................

	splitDef: (argstr) ->

		lMatches = argstr.match(///^
				(env \.)?
				([A-Za-z_][A-Za-z0-9_]*)
				\s*
				(.*)
				$///)
		if lMatches
			[_, env, name, value] = lMatches
			isEnv = if nonEmpty(env) then true else false
			if isEmpty(value)
				value = undef
			return [name, value, isEnv]
		else
			return [undef, undef, undef]

	# ..........................................................

	fetchLinesAtLevel: (atLevel, hOptions={}) ->
		# --- Does NOT remove any indentation
		#     Valid options:
		#        discard - discard ending line

		debug "enter TreeWalker.fetchLinesAtLevel()", atLevel, hOptions
		assert (atLevel > 0), "atLevel is #{atLevel}"

		discardStopLine = hOptions.discard || false
		stopOn = hOptions.stopOn
		if defined(stopOn)
			assert isString(stopOn), "stopOn is #{OL(stopOn)}"

		lLines = []
		while defined(hLine = @fetch()) \
				&& debug('hLine', hLine) \
				&& isString(hLine.line) \
				&& ((stopOn == undef) || (hLine.line != stopOn)) \
				&& (isEmpty(hLine.line) || (hLine.level >= atLevel))

			debug "add to lLines", hLine
			lLines.push hLine

		# --- Cases:                            unfetch?
		#        1. line is undef                 NO
		#        2. line not a string             YES
		#        3. line == stopOn (& defined)    NO
		#        4. line nonEmpty and undented    YES

		if defined(hLine)
			if discardStopLine && (hLine.line == stopOn)
				debug "discard stop line #{OL(stopOn)}"
			else
				debug "unfetch last line", hLine
				@unfetch hLine

		debug "return from TreeWalker.fetchLinesAtLevel()", lLines
		return lLines

	# ..........................................................

	fetchBlockAtLevel: (atLevel, hOptions={}) ->

		debug "enter TreeWalker.fetchBlockAtLevel()", atLevel, hOptions
		lLines = @fetchLinesAtLevel(atLevel, hOptions)
		debug 'lLines', lLines

		lRawLines = for hLine in lLines
			hLine.line
		debug 'lRawLines', lRawLines

		lUndentedLines = undented(lRawLines, atLevel)
		debug "undented lLines", lUndentedLines
		result = arrayToBlock(lUndentedLines)
		debug "return from TreeWalker.fetchBlockAtLevel()", result
		return result

	# ========================================================================
	# --- override these for tree walking

	beginWalk: () ->

		return undef

	# ..........................................................

	visit: (hNode, hUser, lStack) ->

		debug "enter visit()", hNode, hUser, lStack
		{uobj, level} = hNode
		assert isString(uobj), "uobj not a string"
		result = indented(uobj, level)
		debug "return from visit()", result
		return result

	# ..........................................................

	endVisit:  (hNode, hUser, lStack) ->

		debug "enter endVisit()", hNode, hUser, lStack
		debug "return undef from endVisit()"
		return undef

	# ..........................................................

	visitEmptyLine: (hNode) ->

		return undef

	# ..........................................................

	endVisitEmptyLine: (hNode) ->

		return undef

	# ..........................................................

	visitComment: (hNode) ->

		return undef

	# ..........................................................

	endVisitComment: (hNode) ->

		return undef

	# ..........................................................

	visitCmd: (hNode) ->

		return undef

	# ..........................................................

	endVisitCmd: (hNode) ->

		return undef

	# ..........................................................

	endWalk: () ->

		return undef

	# ..........................................................
	# ..........................................................

	isDefined: (name, value, isEnv) ->

		if isEnv
			if defined(value)
				return (process.env[name] == value)
			else
				return defined(process.env[name])
		else
			if defined(value)
				return (@getConst(name) == value)
			else
				return defined(@getConst(name))
		return true

	# ..........................................................

	whichCmd: (uobj) ->

		if isHash(uobj) && uobj.hasOwnProperty('cmd')
			return uobj.cmd
		return undef

	# ..........................................................

	addText: (text) ->

		debug "enter addText()", text
		assert defined(text), "text is undef"
		if isArray(text)
			debug "text is an array"
			@lLines.push text...
		else
			@lLines.push text
		debug "return from addText()"
		return

	# ..........................................................

	walk: (hOptions={}) ->
		# --- Valid options: logNodes

		debug "enter walk()"

		# --- lStack is stack of node = {
		#        hNode: {line, type, level, uobj}
		#        hUser: {}
		#        }
		@lLines = []  # --- resulting lines - added via @addText()
		lStack = []

		debug "begin walk"
		if defined(text = @beginWalk())
			@addText(text)

		debug "getting lines"
		i = 0
		for hNode from @allMapped()
			if hOptions.logNodes
				log "hNode[#{i}]", hNode
			else
				debug "hNode[#{i}]", hNode
			i += 1

			{level} = hNode
			while (lStack.length > level)
				node = lStack.pop()
				debug "popped node", node
				{hNode: hNode2, hUser: hUser2} = node
				assert defined(hNode2), "hNode2 is undef"
				if defined(text = @endVisit(hNode2, hUser2, lStack))
					@addText text

			# --- Create a user hash that the user can add to/modify
			#     and will see again at endVisit
			hUser = {}
			if defined(text = @visit(hNode, hUser, lStack))
				@addText text
			lStack.push {hNode, hUser}

		while (lStack.length > 0)
			node = lStack.pop()
			{hNode: hNode3, hUser: hUser3} = node
			assert defined(hNode3), "hNode3 is undef"
			if defined(text = @endVisit(hNode3, hUser3, lStack))
				@addText text

		if defined(text = @endWalk())
			@addText text
		result = arrayToBlock(@lLines)

		debug "return from walk()", result
		return result

	# ..........................................................

	getBlock: (hOptions={}) ->
		# --- Valid options: logNodes

		debug "enter getBlock()"
		block = @walk(hOptions)
		debug 'block', block
		result = @finalizeBlock(block)
		debug "return from getBlock()", result
		return result
