# TreeWalker.coffee

import {
	assert, undef, pass, croak, defined, OL, rtrim,
	isString, isNumber, isEmpty, nonEmpty, isArray, isHash, isInteger,
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

# ===========================================================================
#   class TreeWalker
#      - map() returns {item, level, lineNum} or undef
#   to use, override:
#      mapStr(str, level) - returns user object, default returns str
#      handleCmd()
#      beginWalk() -
#      visit(uobj, level, lineNum) -
#      endVisit(uobj, level, lineNum) -
#      endWalk() -

export class TreeWalker extends Mapper

	constructor: (source=undef, collection=undef, hOptions={}) ->

		super source, collection, hOptions
		@lMinuses = []   # used to adjust level in #ifdef and #ifndef

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
		item = @mapStr(str, level, lineNum)
		if defined(item)
			uobj = {item, level: @realLevel(level), lineNum}
			debug "return from map()", uobj
			return uobj
		else
			debug "return undef from map()"
			return undef

	# ..........................................................
	# --- designed to override

	mapStr: (str, level, lineNum) ->

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
		level = indentLevel(prefix)
		realLevel = @realLevel(level)
		lineNum = @lineNum

		# --- Handle our commands, returning if found
		switch cmd
			when 'ifdef', 'ifndef'
				[name, value, isEnv] = @splitDef(argstr)
				assert defined(name), "Invalid #{cmd}, argstr=#{OL(argstr)}"
				ok = @isDefined(name, value, isEnv)
				keep = if (cmd == 'ifdef') then ok else ! ok
				if keep
					@lMinuses.push level
				else
					lSkipLines = @fetchLinesAtLevel(level+1)
					debug "Skip #{lSkipLines.length} lines"
				debug "return undef from TreeWalker.handleCmd()"
				return undef

		debug "call super"
		item = super(cmd, argstr, prefix, h)

		if defined(item)
			uobj = {level: realLevel, lineNum, item}
			debug "return from TreeWalker.handleCmd()", uobj
			return uobj
		else
			debug "return undef from TreeWalker.handleCmd()"
			return undef

	# ..........................................................

	getResult: (result, prefix) ->

		if (result == undef)
			return undef
		else
			assert (@lineNum > 0), "lineNum is #{OL(@lineNum)} in getResult()"
			return {
				item: result
				level: @realLevel(indentLevel(prefix))
				lineNum: @lineNum
				}

	# ..........................................................

	realLevel: (level) ->

		lNewMinuses = []
		adjustment = 0
		for i in @lMinuses
			if (level > i)
				adjustment += 1
				lNewMinuses.push i
		@lMinuses = lNewMinuses
		return level - adjustment

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

	visit: (item, level, lineNum, hUser) ->

		debug "enter visit()", item, level, lineNum, hUser
		assert (level >= 0), "level = #{OL(level)}"
		result = indented(item, level)
		debug "return from visit()", result
		return result

	# ..........................................................

	endVisit:  (item, level, lineNum, hUser) ->

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

	checkUserObj: (uobj) ->

		assert defined(uobj), "user object is undef"
		assert isHash(uobj), "user object is #{OL(uobj)}"
		{item, level, lineNum} = uobj
		assert defined(item), "item is undef"
		assert isInteger(level), "level is #{OL(level)}"
		assert (level >= 0), "level is #{OL(level)}"
		assert isInteger(lineNum), "lineNum is #{OL(lineNum)}"
		assert (lineNum >= -1), "lineNum is #{OL(lineNum)}"
		return

	# ..........................................................

	visitNode: (uobj, hUser, lStack) ->

		@checkUserObj uobj
		{item, level, lineNum} = uobj
		line = @visit(item, level, lineNum, hUser, lStack)
		if defined(line)
			@addLine(line)
		return

	# ..........................................................

	endVisitNode: (node, lStack) ->

		assert isHash(node), "node is #{OL(node)}"
		{uobj, hUser} = node
		@checkUserObj uobj
		assert isHash(hUser), "hUser is #{OL(hUser)}"
		{item, level, lineNum} = uobj
		line = @endVisit(item, level, lineNum, hUser, lStack)
		if defined(line)
			@addLine(line)
		return

	# ..........................................................

	walk: () ->

		debug "enter walk()"

		# --- lStack is stack of {
		#        uobj: {item, level, lineNum}
		#        hUser: {}
		#        }
		@lLines = []  # --- resulting lines
		lStack = []

		debug "begin walk"
		line = @beginWalk()
		if defined(line)
			@addLine(line)

		debug "getting uobj's"
		for uobj from @allMapped()
			@checkUserObj uobj
			{item, level, lineNum} = uobj
			while (lStack.length > level)
				node = lStack.pop()
				@endVisitNode node, lStack

			# --- Create a user hash that the user can add to/modify
			#     and will see again at endVisit
			hUser = {}
			@visitNode uobj, hUser, lStack
			lStack.push {uobj, hUser}

		while (lStack.length > 0)
			node = lStack.pop()
			@endVisitNode node, lStack

		line = @endWalk()
		if defined(line)
			@addLine(line)
		result = arrayToBlock(@lLines)

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

		@lTrace = ["BEGIN WALK"]   # an array of strings
		return

	# ..........................................................

	visit: (item, level, lineNum, hUser) ->

		@lTrace.push "VISIT #{lineNum} #{level} #{OL(item)}"
		return

	# ..........................................................

	endVisit: (item, level, lineNum, hUser) ->

		@lTrace.push "END VISIT #{lineNum} #{level} #{OL(item)}"
		return

	# ..........................................................

	endWalk: () ->

		@lTrace.push "END WALK"
		block = arrayToBlock(@lTrace)
		@lTrace = undef
		return block

# ---------------------------------------------------------------------------

addHereDocType new TAMLHereDoc()     #  ---
addHereDocType new FuncHereDoc()     #  () ->
