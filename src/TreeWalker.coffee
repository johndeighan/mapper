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
#      - map() returns mapped item or undef
#      - bundle() returns {item, level, lineNum}
#   to use, override:
#      mapStr(str, level) - returns user object, default returns str
#      handleCmd()
#      beginWalk() -
#      visit(uobj, hUser, lStack) -
#      endVisit(uobj, hUser, lStack) -
#      endWalk() -

export class TreeWalker extends Mapper

	constructor: (source=undef, collection=undef, hOptions={}) ->

		super source, collection, hOptions
		@level = 0
		@lMinuses = []   # used to adjust level in #ifdef and #ifndef

	# ..........................................................
	# --- Should always return either:
	#        undef
	#        uobj - mapped object
	# --- Will only receive non-special lines

	map: (item) ->

		debug "enter map()", item

		# --- a TreeWalker makes no sense unless items are strings
		assert isString(item), "non-string: #{OL(item)}"
		@orgLineNum = @lineNum   # save in case we fetch more lines
		debug "orgLineNum = #{@orgLineNum}"

		[@level, str] = splitLine(item)

		debug "split: level = #{OL(@level)}, str = #{OL(str)}"
		assert nonEmpty(str), "empty string should be special"

		# --- check for extension lines, stop on blank line
		debug "check for extension lines"
		lExtLines = @fetchLinesAtLevel(@level+2, {stopOn: ''})
		assert isArray(lExtLines), "lExtLines not an array"
		debug "#{lExtLines.length} extension lines"
		if isEmpty(lExtLines)
			debug "no extension lines"
			debug "lineNum = #{@lineNum}"
		else
			newstr = @joinExtensionLines(str, lExtLines)
			if (newstr != str)
				str = newstr
				debug "=> #{OL(str)}"

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (str.indexOf('<<<') >= 0)
			hResult = @handleHereDoc(str)
			# --- NOTE: hResult.lObjects is not currently used
			#           but I want to use it in the future to
			#           prevent having to construct an object from the line
			if (hResult.line != str)
				str = hResult.line
				debug "=> #{OL(str)}"
		else
			debug "no HEREDOCs"
			debug "lineNum = #{@lineNum}"

		# --- NOTE: mapStr() may return undef, meaning to ignore
		item = @mapStr(str)
		debug "return from map()", item
		return item

	# ..........................................................
	# --- designed to override

	mapStr: (str) ->

		return str

	# ..........................................................

	bundle: (item) ->

		return {
			item
			level: @realLevel()
			lineNum: @orgLineNum
			}

	# ..........................................................

	joinExtensionLines: (line, lExtLines) ->

		# --- There might be empty lines in lExtLines
		#     but we'll skip them here
		for contLine in lExtLines
			if nonEmpty(contLine)
				line += ' ' + contLine.trim()
		return line

	# ..........................................................

	handleHereDoc: (line) ->
		# --- Indentation has been removed from line
		# --- Find each '<<<' and replace with result of mapHereDoc()

		debug "enter handleHereDoc()", line
		assert isString(line), "not a string"
		lParts = lineToParts(line)
		debug 'lParts', lParts
		lObjects = []
		lNewParts = []    # to be joined to form new line
		for part in lParts
			if part == '<<<'
				debug "get HEREDOC lines at level #{@level+1}"
				lLines = @fetchLinesAtLevel(@level+1, {stopOn: '', discard: true})
				lLines = undented(lLines, @level+1)
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
		@level = indentLevel(prefix)
		realLevel = @realLevel()

		# --- Handle our commands, returning if found
		switch cmd
			when 'ifdef', 'ifndef'
				[name, value, isEnv] = @splitDef(argstr)
				assert defined(name), "Invalid #{cmd}, argstr=#{OL(argstr)}"
				ok = @isDefined(name, value, isEnv)
				keep = if (cmd == 'ifdef') then ok else ! ok
				if keep
					@lMinuses.push @level
				else
					lSkipLines = @fetchLinesAtLevel(@level+1)
					debug "Skip #{lSkipLines.length} lines"
				debug "return undef from TreeWalker.handleCmd()"
				return undef

		debug "call super"
		item = super(cmd, argstr, prefix, h)

		debug "return from TreeWalker.handleCmd()", item
		return item

	# ..........................................................

	realLevel: () ->

		lNewMinuses = []
		adjustment = 0
		for i in @lMinuses
			if (@level > i)
				adjustment += 1
				lNewMinuses.push i
		@lMinuses = lNewMinuses
		return @level - adjustment

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

		stopOn = hOptions.stopOn
		if defined(stopOn)
			assert isString(stopOn), "stopOn is #{OL(stopOn)}"
			discard = hOptions.discard || false
		debug "enter TreeWalker.fetchLinesAtLevel(#{OL(atLevel)}, #{OL(stopOn)})"
		assert (atLevel > 0), "atLevel is #{atLevel}"
		lLines = []
		while defined(item = @fetch()) \
				&& debug("item = #{OL(item)}") \
				&& isString(item) \
				&& ((stopOn == undef) || (item != stopOn)) \
				&& (isEmpty(item) || (indentLevel(item) >= atLevel))

			debug "push #{OL(item)}"
			lLines.push item

		# --- Cases:                            unfetch?
		#        1. item is undef                 NO
		#        2. item not a string             YES
		#        3. item == stopOn (& defined)    NO
		#        4. item nonEmpty and undented    YES

		if isString(item) && ! discard
			debug "do unfetch"
			@unfetch item

		debug "return from TreeWalker.fetchLinesAtLevel()", lLines
		return lLines

	# ..........................................................

	fetchBlockAtLevel: (atLevel, hOptions={}) ->

		debug "enter TreeWalker.fetchBlockAtLevel(#{OL(atLevel)})", hOptions
		lLines = @fetchLinesAtLevel(atLevel, hOptions)
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

	visit: (item, hUser, lStack) ->

		debug "enter visit()", item, hUser
		assert (@level >= 0), "level = #{OL(@level)}"
		result = indented(item, @level)
		debug "return from visit()", result
		return result

	# ..........................................................

	endVisit:  (item, hUser, lStack) ->

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

	walk: () ->

		debug "enter walk()"

		# --- lStack is stack of node = {
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
				node = lStack[lStack.length - 1]
				@endVisitNode node, lStack
				lStack.pop()

			# --- Create a user hash that the user can add to/modify
			#     and will see again at endVisit
			hUser = {}
			node = {uobj, hUser}
			lStack.push node
			@visitNode node, lStack

		while (lStack.length > 0)
			node = lStack[lStack.length - 1]
			@endVisitNode node, lStack
			lStack.pop()

		line = @endWalk()
		if defined(line)
			@addLine(line)
		result = arrayToBlock(@lLines)

		debug "return from walk()", result
		return result

	# ..........................................................

	visitNode: (node, lStack) ->

		assert isHash(node), "node is #{OL(node)}"
		{uobj, hUser} = node
		@checkUserObj uobj
		{item, level, lineNum} = uobj
		line = @visit(item, hUser, lStack)
		if defined(line)
			@addLine(line)
		return

	# ..........................................................

	endVisitNode: (node, lStack) ->

		assert isHash(node), "node is #{OL(node)}"
		{uobj, hUser} = node
		@checkUserObj uobj
		assert isHash(hUser), "hUser is #{OL(hUser)}"
		{item, @level, lineNum} = uobj
		line = @endVisit(item, hUser, lStack)
		if defined(line)
			@addLine(line)
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

	visit: (item, hUser, lStack) ->

		hTOS = lStack[lStack.length - 1]
		{item, level, lineNum} = hTOS.uobj
		@lTrace.push "VISIT #{lineNum} #{level} #{OL(item)}"
		return

	# ..........................................................

	endVisit: (item, hUser, lStack) ->

		hTOS = lStack[lStack.length - 1]
		{item, level, lineNum} = hTOS.uobj
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
