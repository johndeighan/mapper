# TreeWalker.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, defined, notdefined, OL, rtrim, words,
	isString, isNumber, isFunction, isArray, isHash, isInteger,
	isEmpty, nonEmpty,
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
#      - mapNonSpecial() returns mapped item (i.e. uobj) or undef
#   to use, override:
#      map(hNode) - returns user object, def: returns hNode.str
#      mapCmd(hNode)
#      beginWalk()
#      visit(hNode, hUser, lStack)
#      endVisit(hNode, hUser, lStack)
#      endWalk() -

export class TreeWalker extends Mapper

	constructor: (source=undef, collection=undef, hOptions={}) ->

		super source, collection, hOptions

		@hSpecialVisitTypes = {}

		@registerVisitType 'empty',   @visitEmptyLine, @endVisitEmptyLine
		@registerVisitType 'comment', @visitComment,   @endVisitComment
		@registerVisitType 'cmd',     @visitCmd,       @endVisitCmd

		@lMinuses = []   # used to adjust level in #ifdef and #ifndef

	# ..........................................................

	registerVisitType: (type, visiter, endVisiter) ->

		@hSpecialVisitTypes[type] = {
			visiter
			endVisiter
			}
		return

	# ..........................................................

	mapNode: (hNode) ->

		debug "enter TreeWalker.mapNode()", hNode
		if @adjustLevel(hNode)
			debug "hNode.level adjusted", hNode
		else
			debug "no adjustment"
		uobj = super(hNode)
		debug "return from TreeWalker.mapNode()", uobj
		return uobj

	# ..........................................................
	# --- Should always return either:
	#        undef
	#        uobj - mapped object
	# --- Will only receive non-special lines
	#     1. add extension lines
	#     2. replace HEREDOCs
	#     3. call map()

	mapNonSpecial: (hNode) ->

		debug "enter TreeWalker.mapNonSpecial()", hNode
		assert notdefined(hNode.type), "hNode is #{OL(hNode)}"

		{str, level, srcLevel} = hNode

		# --- from here on, str is a non-empty string
		assert nonEmpty(str), "hNode is #{OL(hNode)}"
		assert isInteger(srcLevel, {min: 0}), "hNode is #{OL(hNode)}"

		# --- check for extension lines, stop on blank line if found
		debug "check for extension lines"
		lExtLines = @fetchLinesAtLevel(srcLevel+2, {stopOn: ''})
		assert isArray(lExtLines), "lExtLines not an array"
		debug "#{lExtLines.length} extension lines"
		if ! isEmpty(lExtLines)
			@joinExtensionLines(hNode, lExtLines)
			debug "with ext lines", hNode
			{str} = hNode

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (str.indexOf('<<<') >= 0)
			newStr = @handleHereDocsInLine(str, srcLevel)
			str = newStr
			debug "=> #{OL(str)}"
		else
			debug "no HEREDOCs"

		hNode.str = str

		# --- NOTE: map() may return undef, meaning to ignore
		#     We must pass srcLevel since map() may use fetch()
		uobj = @map(hNode)
		debug "return from TreeWalker.mapNonSpecial()", uobj
		return uobj

	# ..........................................................
	# --- designed to override

	map: (hNode) ->

		return hNode.str

	# ..........................................................
	# --- can override to change how lines are joined

	joinExtensionLines: (hNode, lExtLines) ->
		# --- modifies key str

		# --- There might be empty lines in lExtLines
		#     but we'll skip them here
		str = hNode.str
		for hContLine in lExtLines
			nextStr = hContLine.str
			if nonEmpty(nextStr)
				str += @extSep(str, nextStr) + nextStr
		hNode.str = str
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
	# --- We define commands 'ifdef' and 'ifndef'

	mapCmd: (hNode) ->

		debug "enter TreeWalker.mapCmd()", hNode

		{cmd, argstr, prefix, srcLevel} = hNode
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
		item = super(hNode)

		debug "return from TreeWalker.mapCmd()", item
		return item

	# ..........................................................

	adjustLevel: (hNode) ->

		debug "enter adjustLevel()", hNode

		srcLevel = hNode.srcLevel
		debug "srcLevel", srcLevel
		assert isInteger(srcLevel, {min: 0}), "level is #{OL(srcLevel)}"

		# --- Calculate the needed adjustment and new level
		debug "lMinuses", @lMinuses
		lNewMinuses = []
		adjust = 0
		for i in @lMinuses
			if (srcLevel > i)
				adjust += 1
				lNewMinuses.push i
		@lMinuses = lNewMinuses
		debug 'new lMinuses', @lMinuses

		if (adjust == 0)
			debug "return false from adjustLevel() - zero adjustment"
			return false

		assert (srcLevel >= adjust), "srcLevel=#{srcLevel}, adjust=#{adjust}"
		newLevel = srcLevel - adjust

		# --- Make adjustments to hNode
		hNode.level = newLevel

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
		#     Valid options:
		#        discard - discard ending line

		debug "enter TreeWalker.fetchLinesAtLevel()", atLevel, hOptions
		assert (atLevel > 0), "atLevel is #{OL(atLevel)}"

		discardStopLine = hOptions.discard || false
		stopOn = hOptions.stopOn
		if defined(stopOn)
			assert isString(stopOn), "stopOn is #{OL(stopOn)}"

		lLines = []
		while defined(hNode = @fetch()) \
				&& debug('hNode from fetch()', hNode) \
				&& ((stopOn == undef) || (hNode.str != stopOn)) \
				&& (isEmpty(hNode.str) || (hNode.level >= atLevel))

			debug "add to lLines", hNode
			lLines.push hNode

		# --- Cases:                            unfetch?
		#        1. line is undef                 NO
		#        2. line not a string             YES
		#        3. line == stopOn (& defined)    NO
		#        4. line nonEmpty and undented    YES

		if defined(hNode)
			if discardStopLine && (hNode.str == stopOn)
				debug "discard stop line #{OL(stopOn)}"
			else
				debug "unfetch last line", hNode
				@unfetch hNode

		debug "return from TreeWalker.fetchLinesAtLevel()", lLines
		return lLines

	# ..........................................................

	fetchBlockAtLevel: (atLevel, hOptions={}) ->

		debug "enter TreeWalker.fetchBlockAtLevel()", atLevel, hOptions
		lLines = @fetchLinesAtLevel(atLevel, hOptions)
		debug 'lLines', lLines

		lRawLines = for hNode in lLines
			hNode.getLine(@oneIndent)
		debug 'lRawLines', lRawLines

		lUndentedLines = undented(lRawLines, atLevel)
		debug "undented lLines", lUndentedLines
		result = arrayToBlock(lUndentedLines)
		debug "return from TreeWalker.fetchBlockAtLevel()", result
		return result

	# ========================================================================
	# --- override these for tree walking

	beginWalk: (lStack) ->

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

	visitEmptyLine: (hNode, hUser, lStack) ->

		debug "in TreeWalker.visitEmptyLine()"
		return undef

	# ..........................................................

	endVisitEmptyLine: (hNode, hUser, lStack) ->

		debug "in TreeWalker.endVisitEmptyLine()"
		return undef

	# ..........................................................

	visitComment: (hNode, hUser, lStack) ->

		debug "in TreeWalker.visitComment()"
		return undef

	# ..........................................................

	endVisitComment: (hNode, hUser, lStack) ->

		debug "in TreeWalker.endVisitComment()"
		return undef

	# ..........................................................

	visitCmd: (hNode, hUser, lStack) ->

		debug "in TreeWalker.visitCmd()"
		return undef

	# ..........................................................

	endVisitCmd: (hNode, hUser, lStack) ->

		debug "in TreeWalker.endVisitCmd()"
		return undef

	# ..........................................................

	endWalk: (lStack) ->

		debug "in TreeWalker.endVisitCmd()"
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
			debug "add text #{OL(text)}"
			@lLines.push text
		debug "return from addText()"
		return

	# ..........................................................

	walk: (hOptions={}) ->
		# --- Valid options: logNodes

		debug "enter walk()"

		# --- lStack is stack of:
		#        hNode: Node object
		#        hUser: {}
		#        }
		@lLines = []  # --- resulting lines - added via @addText()
		lStack = []

		debug "begin walk"
		if defined(text = @beginWalk(lStack))
			@addText(text)

		debug "getting lines"
		i = 0
		for hNode from @allMapped()
			if hOptions.logNodes
				LOG "hNode[#{i}]", hNode
			else
				debug "hNode[#{i}]", hNode
			i += 1

			{level} = hNode
			while (lStack.length > level)
				@endVisitNode lStack

			@visitNode hNode, lStack

		while (lStack.length > 0)
			@endVisitNode lStack

		if defined(text = @endWalk(lStack))
			@addText text

		if nonEmpty(@lLines)
			result = arrayToBlock(@lLines)
		else
			result = ''

		debug "return from walk()", result
		return result

	# ..........................................................

	visitNode: (hNode, lStack) ->

		debug "enter visitNode()", hNode, lStack

		# --- Create a user hash that the user can add to/modify
		#     and will see again at endVisit
		hUser = {}

		if (type = hNode.type)
			debug "type = #{type}"
			text = @visitSpecial(type, hNode, hUser, lStack)
		else
			debug "no type"
			text = @visit(hNode, hUser, lStack)

		if defined(text)
			@addText text

		lStack.push {hNode, hUser}
		debug "return from visitNode()"
		return

	# ..........................................................

	endVisitNode: (lStack) ->

		debug "enter endVisitNode()", lStack
		assert nonEmpty(lStack), "stack is empty"
		{hNode, hUser} = lStack.pop()

		if (type = hNode.type)
			text = @endVisitSpecial(type, hNode, hUser, lStack)
		else
			text = @endVisit(hNode, hUser, lStack)

		if defined(text)
			@addText text

		debug "return from endVisitNode()"
		return

	# ..........................................................

	visitSpecial: (type, hNode, hUser, lStack) ->

		debug "enter TreeWalker.visitSpecial()",
				type, hNode, hUser, lStack
		visiter = @hSpecialVisitTypes[type].visiter
		assert defined(visiter), "No such type: #{OL(type)}"
		func = visiter.bind(this)
		assert isFunction(func), "not a function"
		result = func(hNode, hUser, lStack)
		debug "return from TreeWalker.visitSpecial()", result
		return result

	# ..........................................................

	endVisitSpecial: (type, hNode, hUser, lStack) ->

		func = @hSpecialVisitTypes[type].endVisiter.bind(this)
		return func(hNode, hUser, lStack)

	# ..........................................................

	getBlock: (hOptions={}) ->
		# --- Valid options: logNodes

		debug "enter getBlock()"
		block = @walk(hOptions)
		debug 'block', block
		result = @finalizeBlock(block)
		debug "return from getBlock()", result
		return result
