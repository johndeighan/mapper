# TreeWalker.coffee

import {
	assert, undef, pass, croak, defined, OL, rtrim,
	isString, isNumber, isEmpty, nonEmpty, isArray, isHash,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {
	splitLine, indentLevel, indented, undented,
	} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Mapper} from '@jdeighan/mapper'
import {
	lineToParts, mapHereDoc, addHereDocType,
	} from '@jdeighan/mapper/heredoc'
import {FuncHereDoc} from '@jdeighan/mapper/func'
import {TAMLHereDoc} from '@jdeighan/mapper/taml'
import {RunTimeStack} from '@jdeighan/mapper/stack'

# ===========================================================================
#   class TreeWalker
#      - map() returns {uobj, level, lineNum} or undef
#   to use, override:
#      mapStr(str, level) - returns user object, default returns str
#      handleCmd()
#      beginWalk() -
#      visit(uobj, level, lineNum) -
#      endVisit(uobj, level, lineNum) -
#      endWalk() -

export class TreeWalker extends Mapper

	# ..........................................................
	# --- Should always return either:
	#        undef
	#        object with {uobj, level, lineNum}
	# --- Will only receive non-special lines

	map: (item) ->

		debug "enter map()", item

		# --- a TreeWalker makes no sense unless items are strings
		assert isString(item), "non-string: #{OL(item)}"
		lineNum = @lineNum   # save in case we fetch more lines

		[level, str] = splitLine(item)

		debug "split: level = #{OL(level)}, str = #{OL(str)}"
		assert nonEmpty(str), "empty string should be special"

		# --- check for extension lines
		debug "check for extension lines"
		lExtLines = @fetchLinesAtLevel(level+2)
		assert isArray(lExtLines), "lExtLines not an array"
		if nonEmpty(lExtLines)
			newstr = @joinExtensionLines(str, lExtLines)
			if (newstr != str)
				str = newstr
				debug "=> #{OL(str)}"

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (str.indexOf('<<<') >= 0)
			hResult = @handleHereDoc(str, level)
			# --- NOTE: hResult.lObjects is not currently used
			#           but I want to use it in the future to
			#           prevent having to construct an object from the line
			if (hResult.line != str)
				str = hResult.line
				debug "=> #{OL(str)}"

		# --- NOTE: mapStr() may return undef, meaning to ignore
		item = @mapStr(str, level)
		if defined(item)
			uobj = {level, lineNum, item}
			debug "return from map()", uobj
			return uobj
		else
			debug "return undef from map()"
			return undef

	# ..........................................................
	# --- designed to override

	mapStr: (str, level) ->

		return str

	# ..........................................................

	joinExtensionLines: (line, lExtLines) ->

		# --- There might be empty lines in lExtLines
		#     but we'll skip them here
		for contLine in lExtLines
			if nonEmpty(contLine)
				line += ' ' + contLine.trim()
		return line

	# ..........................................................

	handleHereDoc: (line, level) ->
		# --- Indentation has been removed from line
		# --- Find each '<<<' and replace with result of mapHereDoc()

		debug "enter handleHereDoc()", line, level
		assert isString(line), "not a string"
		lParts = lineToParts(line)
		debug 'lParts', lParts
		lObjects = []
		lNewParts = []    # to be joined to form new line
		for part in lParts
			if part == '<<<'
				debug "get HEREDOC lines at level #{level+1}"
				lLines = @fetchLinesAtLevel(level+1, '') # stop on blank line
				lLines = undented(lLines, level+1)
				debug 'lLines', lLines

				hResult = mapHereDoc(arrayToBlock(lLines))
				debug 'hResult', hResult
				lObjects.push hResult.obj
				lNewParts.push hResult.str
			else
				lNewParts.push part    # keep as is

		hResult = {
			line: lNewParts.join('')
			lObjects: lObjects
			}

		debug "return from handleHereDoc", hResult
		return hResult

	# ..........................................................

	extSep: (str, nextStr) ->

		return ' '

	# ..........................................................

	isEmptyHereDocLine: (str) ->

		return (str == '.')

	# ..........................................................
	# --- We define commands 'ifdef' and 'ifndef'

	handleCmd: (cmd, argstr, prefix, h) ->
		# --- h has keys 'cmd','argstr' and 'prefix'
		#     but may contain additional keys

		debug "enter TreeWalker.handleCmd()", h

		# --- Handle our commands, returning if found
		switch cmd
			when 'ifdef', 'ifndef'
				lResult = @splitDef(argstr)
				assert defined(lResult), "Invalid #{cmd}, argstr=#{OL(argstr)}"
				[isEnv, name, value] = lResult
				if isEnv
					if defined(value)
						item = {cmd, isEnv, name, value}
					else
						item = {cmd, isEnv, name}
				else
					if defined(value)
						item = {cmd, name, value}
					else
						item = {cmd, name}

				uobj = {
					lineNum: @lineNum
					level: indentLevel(prefix)
					item
					}
				debug "return from TreeWalker.handleCmd()", uobj
				return uobj

		debug "call super"
		uobj = super(cmd, argstr, prefix, h)
		debug "return super from TreeWalker.handleCmd()", uobj
		return uobj

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
			return [isEnv, name, value]
		else
			return undef

	# ..........................................................

	fetchLinesAtLevel: (atLevel, stopOn=undef) ->
		# --- Does NOT remove any indentation

		debug "enter TreeWalker.fetchLinesAtLevel(#{OL(atLevel)}, #{OL(stopOn)})"
		assert (atLevel > 0), "atLevel is 0"
		lLines = []
		while defined(item = @fetch()) \
				&& debug("item = #{OL(item)}") \
				&& isString(item) \
				&& ((stopOn == undef) || (item != stopOn)) \
				&& debug("OK") \
				&& (isEmpty(item) || (indentLevel(item) >= atLevel))

			debug "push #{OL(item)}"
			lLines.push item

		# --- Cases:                            unfetch?
		#        1. item is undef                 NO
		#        2. item not a string             YES
		#        3. item == stopOn (& defined)    NO
		#        4. item nonEmpty and undented    YES

		if ((item == undef) || (item == stopOn))
			debug "don't unfetch"
		else
			debug "do unfetch"
			@unfetch item

		debug "return from TreeWalker.fetchLinesAtLevel()", lLines
		return lLines

	# ..........................................................

	fetchBlockAtLevel: (atLevel, stopOn=undef) ->

		debug "enter TreeWalker.fetchBlockAtLevel(#{OL(atLevel)})"
		lLines = @fetchLinesAtLevel(atLevel, stopOn)
		debug 'lLines', lLines
		lLines = undented(lLines, atLevel)
		debug "undented lLines", lLines
		result = arrayToBlock(lLines)
		debug "return from TreeWalker.fetchBlockAtLevel()", result
		return result

	# ..........................................................
	# --- override these for tree walking

	beginWalk: () ->

		return undef

	# ..........................................................

	visit: (uobj, level, lineNum) ->

		debug "enter visit()", uobj, level, lineNum
		assert (level >= 0), "level = #{OL(level)}"
		result = indented(uobj, level)
		debug "return from visit()", result
		return result

	# ..........................................................

	endVisit:  (uobj, level, lineNum) ->

		return undef

	# ..........................................................

	endWalk: () ->

		return undef

	# ..........................................................
	# ..........................................................

	isDefined: (uobj) ->

		{name, value, isEnv} = uobj
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

	visitNode: (node, hUser) ->

		debug "enter visitNode()", node, hUser
		{uobj, level, lineNum} = node
		debug "level = #{OL(level)}"
		debug "lineNum = #{OL(lineNum)}"
		cmd = @whichCmd(uobj)
		debug "cmd = #{OL(cmd)}"
		switch cmd
			when 'ifdef'
				@doVisit = @isDefined(uobj)
				@minus += 1
			when 'ifndef'
				@doVisit = ! @isDefined(uobj)
				@minus += 1
			else
				if @doVisit
					line = @visit(uobj, level-@minus, lineNum, hUser)
					if defined(line)
						@addLine(line)
		@lStack.push {node, hUser, doVisit: @doVisit}
		debug "return from visitNode()"
		return

	# ..........................................................

	endVisitNode: () ->

		debug "enter endVisitNode()"
		{node, hUser, doVisit} = @lStack.pop()
		{uobj, level, lineNum} = node
		switch @whichCmd(uobj)
			when 'ifdef', 'ifndef'
				@doVisit = doVisit
				@minus -= 1
			else
				if @doVisit
					line = @endVisit(uobj, level-@minus, lineNum, hUser)
					if defined(line)
						@addLine(line)
		debug "return from endVisitNode()"
		return

	# ..........................................................

	whichCmd: (uobj) ->

		if isHash(uobj) && uobj.hasOwnProperty('cmd')
			return uobj.cmd
		return undef

	# ..........................................................

	walk: () ->

		debug "enter walk()"

		# --- @lStack is stack of {
		#        node: {uobj, level, lineNum},
		#        hUser: {_parent: <parent node>, ...}
		#        }
		@lLines = []  # --- resulting lines

		# --- Initialize these here, but they're managed in
		#     @visitNode() and @endVisitNode()
		@lStack = []
		@minus = 0       # --- subtract this from level in visit, endVisit
		@doVisit = true  # --- if false, skip visiting

		debug "begin walk"
		line = @beginWalk()
		if defined(line)
			@addLine(line)

		debug "getting nodes"
		for node from @allMapped()
			while (@lStack.length > node.level)
				@endVisitNode()

			# --- Create a user hash that the user can add to/modify
			#     and contains a reference to the parent node
			#     and will see again at endVisit
			if (@lStack.length == 0)
				hUser = {}
			else
				hUser = {_parent: @lStack[@lStack.length-1].node}
			@visitNode node, hUser

		while (@lStack.length > 0)
			@endVisitNode()

		line = @endWalk()
		if defined(line)
			@addLine(line)
		result = arrayToBlock(@lLines)

		@lStack = undef
		@minus = undef
		@doVisit = undef

		debug "return from walk()", result
		return result

	# ..........................................................

	addLine: (line) ->

		assert defined(line), "line is undef"
		debug "enter addLine(#{OL(line)})", line
		if isArray(line)
			debug "line is an array"
			@lLines.push line...
		else
			@lLines.push line
		debug "return from addLine()"
		return

	# ..........................................................

	getBlock: () ->

		debug "enter getBlock()"
		result = @walk()
		debug "return from getBlock()", result
		return result

# ---------------------------------------------------------------------------

export class TraceWalker extends TreeWalker

	# ..........................................................
	#     builds a trace of the tree
	#        which is returned by endWalk()

	beginWalk: () ->

		@lTrace = ["begin"]   # an array of strings
		return

	# ..........................................................

	visit: (uobj, level, lineNum) ->

		@lTrace.push "|.".repeat(level) + "> #{OL(uobj)}"
		return

	# ..........................................................

	endVisit: (uobj, level, lineNum) ->

		@lTrace.push "|.".repeat(level) + "< #{OL(uobj)}"
		return

	# ..........................................................

	endWalk: () ->

		@lTrace.push "end"
		block = arrayToBlock(@lTrace)
		@lTrace = undef
		return block

# ---------------------------------------------------------------------------

addHereDocType new TAMLHereDoc()     #  ---
addHereDocType new FuncHereDoc()     #  () ->
