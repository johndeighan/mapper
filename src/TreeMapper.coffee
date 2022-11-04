# TreeMapper.coffee

import {
	LOG, LOGVALUE, setLogger, assert, croak, toTAML,
	} from '@jdeighan/exceptions'
import {dbg, dbgEnter, dbgReturn} from '@jdeighan/exceptions/debug'
import {unescapeStr} from '@jdeighan/exceptions/utils'
import {
	undef, pass, defined, notdefined, OL, rtrim, words,
	isString, isNumber, isFunction, isArray, isHash, isInteger,
	isEmpty, nonEmpty, isArrayOfStrings,
	} from '@jdeighan/coffee-utils'
import {toBlock} from '@jdeighan/coffee-utils/block'
import {
	splitLine, indentLevel, indented, undented,
	} from '@jdeighan/coffee-utils/indent'

import {Mapper} from '@jdeighan/mapper'
import {lineToParts, mapHereDoc} from '@jdeighan/mapper/heredoc'
import {RunTimeStack} from '@jdeighan/mapper/stack'

threeSpaces = "   "

# ===========================================================================
#   class TreeMapper
#      - mapNonSpecial() returns mapped item (i.e. uobj) or undef
#   to use, override:
#      mapNode(hNode) - returns user object, def: returns hNode.str
#      mapCmd(hNode)
#      beginLevel(hUser, level)
#      visit(hNode, hUser, hParent, stack)
#      endVisit(hNode, hUser, hParent, stack)
#      endLevel(hUser, level) -

export class TreeMapper extends Mapper

	constructor: (source=undef, content=undef, hOptions={}) ->

		super source, content, hOptions

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

		dbgEnter "TreeMapper.mapNode", hNode
		if @adjustLevel(hNode)
			dbg "hNode.level adjusted", hNode
		else
			dbg "no adjustment"
		uobj = super(hNode)
		dbgReturn "TreeMapper.mapNode", uobj
		return uobj

	# ..........................................................
	# --- Should always return either:
	#        undef
	#        uobj - mapped object
	# --- Will only receive non-special lines
	#     1. replace HEREDOCs
	#     2. call mapNode()

	mapNonSpecial: (hNode) ->

		dbgEnter "TreeMapper.mapNonSpecial", hNode
		assert notdefined(hNode.type), "hNode is #{OL(hNode)}"

		{str, level, srcLevel} = hNode

		# --- from here on, str is a non-empty string
		assert nonEmpty(str), "hNode is #{OL(hNode)}"
		assert isInteger(srcLevel, {min: 0}), "hNode is #{OL(hNode)}"

		# --- handle HEREDOCs
		dbg "check for HEREDOC"
		if (str.indexOf('<<<') >= 0)
			newStr = @handleHereDocsInLine(str, srcLevel)
			str = newStr
			dbg "=> #{OL(str)}"
		else
			dbg "no HEREDOCs"

		hNode.str = str

		# --- NOTE: mapNode() may return undef, meaning to ignore
		#     We must pass srcLevel since mapNode() may use fetch()
		uobj = @mapNode(hNode)
		dbgReturn "TreeMapper.mapNonSpecial", uobj
		return uobj

	# ..........................................................

	handleHereDocsInLine: (line, srcLevel) ->
		# --- Indentation has been removed from line
		# --- Find each '<<<' and replace with result of mapHereDoc()

		dbgEnter "handleHereDocsInLine", line
		assert isString(line), "not a string"
		lParts = lineToParts(line)
		dbg 'lParts', lParts
		lNewParts = []    # to be joined to form new line
		for part in lParts
			if part == '<<<'
				dbg "get HEREDOC lines at level #{srcLevel+1}"
				hOptions = {
					stopOn: ''
					discard: true    # discard the terminating empty line
					}

				# --- block will be undented
				block = @fetchHereDocBlock(srcLevel)
				dbg 'block', block

				uobj = mapHereDoc(block)
				assert defined(uobj), "mapHereDoc returned undef"
				dbg 'mapped block', uobj

				str = @handleHereDoc(uobj, block)
				assert isString(str), "str is #{OL(str)}"
				lNewParts.push str
			else
				lNewParts.push part    # keep as is

		result = lNewParts.join('')
		dbgReturn "handleHereDocsInLine", result
		return result

	# ..........................................................

	fetchHereDocBlock: (srcLevel) ->
		# --- srcLevel is the level of the line with <<<

		dbgEnter "TreeMapper.fetchHereDocBlock", srcLevel
		func = (hNode) =>
			if isEmpty(hNode.str)
				return true
			else
				assert (hNode.srcLevel > srcLevel),
					"insufficient indentation: srcLevel=#{srcLevel}," \
					+ " node at #{hNode.srcLevel}"
				return false
		block = @fetchBlockUntil(func, 'discardEndLine')
		dbgReturn "TreeMapper.fetchHereDocBlock", block
		return block

	# ..........................................................

	handleHereDoc: (uobj, block) ->

		return uobj

	# ..........................................................

	isEmptyHereDocLine: (str) ->

		return (str == '.')

	# ..........................................................
	# --- We define commands 'ifdef' and 'ifndef'

	mapCmd: (hNode) ->

		dbgEnter "TreeMapper.mapCmd", hNode

		{type, uobj, prefix, srcLevel} = hNode
		assert (type == 'cmd'), 'not a command'
		{cmd, argstr} = uobj
		dbg "srcLevel = #{srcLevel}"

		# --- Handle our commands, returning if found
		switch cmd
			when 'ifdef', 'ifndef'
				[name, value, isEnv] = @splitDef(argstr)
				assert defined(name), "Invalid #{cmd}, argstr=#{OL(argstr)}"
				ok = @isDefined(name, value, isEnv)
				dbg "ok = #{OL(ok)}"
				keep = if (cmd == 'ifdef') then ok else ! ok
				dbg "keep = #{OL(keep)}"
				if keep
					dbg "add #{srcLevel} to lMinuses"
					@lMinuses.push srcLevel
				else
					lSkipLines = @skipLinesAtLevel(srcLevel)
					dbg "Skip #{lSkipLines.length} lines"
				dbgReturn "TreeMapper.mapCmd", undef
				return undef

		dbg "call super"
		uobj = super(hNode)
		dbgReturn "TreeMapper.mapCmd", uobj
		return uobj

	# ..........................................................

	skipLinesAtLevel: (srcLevel) ->
		# --- srcLevel is the level of #ifdef or #ifndef
		#     don't discard the end line

		dbgEnter "TreeMapper.skipLinesAtLevel", srcLevel
		func = (hNode) =>
			return (hNode.srcLevel <= srcLevel)
		block = @fetchBlockUntil(func, 'keepEndLine')
		dbgReturn "TreeMapper.skipLinesAtLevel", block
		return block

	# ..........................................................

	fetchBlockAtLevel: (srcLevel) ->
		# --- srcLevel is the level of enclosing cmd/tag
		#     don't discard the end line

		dbgEnter "TreeMapper.fetchBlockAtLevel", srcLevel
		func = (hNode) =>
			return (hNode.srcLevel <= srcLevel) && nonEmpty(hNode.str)
		block = @fetchBlockUntil(func, 'keepEndLine')
		dbgReturn "TreeMapper.fetchBlockAtLevel", block
		return block

	# ..........................................................

	adjustLevel: (hNode) ->

		dbgEnter "adjustLevel", hNode

		srcLevel = hNode.srcLevel
		dbg "srcLevel", srcLevel
		assert isInteger(srcLevel, {min: 0}), "level is #{OL(srcLevel)}"

		# --- Calculate the needed adjustment and new level
		dbg "lMinuses", @lMinuses
		lNewMinuses = []
		adjust = 0
		for i in @lMinuses
			if (srcLevel > i)
				adjust += 1
				lNewMinuses.push i
		@lMinuses = lNewMinuses
		dbg 'new lMinuses', @lMinuses

		if (adjust == 0)
			dbgReturn "adjustLevel", false
			return false

		assert (srcLevel >= adjust), "srcLevel=#{srcLevel}, adjust=#{adjust}"
		newLevel = srcLevel - adjust

		# --- Make adjustments to hNode
		hNode.level = newLevel

		dbg "level adjusted #{srcLevel} => #{newLevel}"
		dbgReturn "adjustLevel", true
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

	getLog: () ->

		return toBlock(@lLog)

	# ..........................................................

	walk: (hOptions={}) ->
		# --- Valid options: logNodes, includeUserHash
		#     returns an array, normally strings

		dbgEnter "TreeMapper.walk", hOptions

		@logNodes = !! hOptions.logNodes
		if @logNodes
			@lLog = []
			@includeUserHash = !! hOptions.includeUserHash

		# --- Initialize local state

		lLines = []   # --- resulting output lines (but may be objects)
		stack = new RunTimeStack()   # --- a stack of Node objects
		hGlobalUser = {}  # --- hParent for level 0 nodes

		# .......................................................
		#     Local Functions
		# .......................................................

		log = (level, text, hUser) =>

			if ! @logNodes
				return

			dbgEnter "log", level, text, hUser
			oldLogger = setLogger (str) => @lLog.push(str)
			LOG toBlock(indented([text], level, threeSpaces))
			if @includeUserHash && defined(hUser)
				if isEmpty(hUser)
					LOG "hUser = {}"
				else
					LOGVALUE 'hUser', hUser
					LOG ""
			setLogger oldLogger
			dbgReturn "log"
			return

		# .......................................................

		add = (text) =>
			# --- in fact, text can be any type of object

			dbgEnter "add", text
			assert defined(text), "text is undef"
			if isArray(text)
				dbg "text is an array"
				for item in text
					if defined(item)
						lLines.push item
			else
				dbg "add text #{OL(text)}"
				lLines.push text
			dbgReturn "add"
			return

		# .......................................................

		doBeginWalk = (hUser) =>

			dbgEnter "doBeginWalk"
			log 0, "BEGIN WALK", hGlobalUser
			text = @beginWalk hUser
			if defined(text)
				add text
			dbgReturn "doBeginWalk"
			return

		# .......................................................

		doEndWalk = (hUser) =>

			dbgEnter "doEndWalk"
			log 0, "END WALK", hGlobalUser
			text = @endWalk hUser
			if defined(text)
				add text
			dbgReturn "doEndWalk"
			return

		# .......................................................

		doBeginLevel = (hUser, level) =>

			dbgEnter "doBeginLevel"
			log level, "BEGIN LEVEL #{level}", hUser
			text = @beginLevel hUser, level
			if defined(text)
				add text
			dbgReturn "doBeginLevel"
			return

		# .......................................................

		doEndLevel = (hUser, level) =>

			dbgEnter "doEndLevel"
			log level, "END LEVEL #{level}", hUser
			text = @endLevel hUser, level
			if defined(text)
				add text
			dbgReturn "doEndLevel"
			return

		# .......................................................

		doVisit = (hNode) =>

			# --- visit the node
			{type, hUser, level, str, uobj} = hNode
			log level, "VISIT #{level} #{OL(str)}", hUser

			if defined(type)
				dbg "type = #{type}"
				text = @visitSpecial(type, hNode, hUser, stack)
			else
				dbg "no type"
				text = @visit(hNode, hUser, hUser._parent, stack)
			if defined(text)
				add text
			return

		# .......................................................

		doEndVisit = (hNode) =>

			# --- end visit the node
			{type, hUser, level, str, uobj} = hNode
			log level, "END VISIT #{level} #{OL(str)}", hUser

			if defined(type)
				dbg "type = #{type}"
				text = @endVisitSpecial type, hNode, hUser, stack
			else
				dbg "no type"
				text = @endVisit hNode, hUser, hUser._parent, stack
			if defined(text)
				add text
			return

		# .......................................................

		doBeginWalk hGlobalUser

		# --- Iterate over all input lines

		dbg "getting lines"
		i = 0
		for hNode in Array.from(@allMapped()) # iterators mess up debugging

			# --- Log input lines for debugging

			dbg "hNode[#{i}]", hNode

			{level, str} = hNode     # unpack node

			if (i==0)
				# --- The first node is a special case, we handle it,
				#     then continue to the second node (if any)

				assert (level == 0), "first node at level #{level}"
				i = 1
				hNode.hUser = {_parent: hGlobalUser}
				doBeginLevel hGlobalUser, 0
				doVisit hNode
				stack.push hNode
				dbg 'stack', stack
				continue    # restart the loop

			i += 1

			# --- add user hash

			hUser = hNode.hUser = {_parent: stack.TOS().hUser}

			# --- At this point, the previous node is on top of stack
			# --- End any levels > level

			while (stack.TOS().level > level)
				hPrevNode = stack.pop()
				dbg "pop node", hPrevNode

				doEndVisit hPrevNode
				doEndLevel hPrevNode.hUser, hPrevNode.level

			diff = level - stack.TOS().level

			# --- This is a consequence of the while loop condition
			assert (diff >= 0), "Can't happen"

			# --- This shouldn't happen because it would be an extension line
			assert (diff < 2), "Shouldn't happen"

			if (diff == 0)
				hPrevNode = stack.TOS()
				doEndVisit hPrevNode
				doVisit hNode
				stack.replaceTOS hNode
			else if (diff == 1)
				doBeginLevel hUser, level
				doVisit hNode
				stack.push hNode

		while (stack.len > 0)
			hPrevNode = stack.pop()
			dbg "pop node", hPrevNode

			doEndVisit hPrevNode
			doEndLevel hUser, hPrevNode.level

		doEndWalk hGlobalUser

		dbgReturn "TreeMapper.walk", lLines
		return lLines

	# ..........................................................
	# These are designed to override
	# ..........................................................

	beginWalk: (hUser) ->

		return undef

	# ..........................................................

	beginLevel: (hUser, level) ->

		return undef

	# ..........................................................

	startLevel: (hUser, level) ->

		croak "There is no startLevel() method - use beginLevel()"

	# ..........................................................

	endLevel: (hUser, level) ->

		return undef

	# ..........................................................

	endWalk: (hUser) ->

		return undef

	# ..........................................................

	visit: (hNode, hUser, hParent, stack) ->

		dbgEnter "visit", hNode, hUser
		uobj = hNode.uobj
		dbgReturn "visit", uobj
		return uobj

	# ..........................................................

	endVisit:  (hNode, hUser, hParent, stack) ->

		dbgEnter "endVisit", hNode, hUser
		dbgReturn "endVisit", undef
		return undef

	# ..........................................................

	visitEmptyLine: (hNode, hUser, hParent, stack) ->

		dbg "in TreeMapper.visitEmptyLine()"
		return ''

	# ..........................................................

	endVisitEmptyLine: (hNode, hUser, hParent) ->

		dbg "in TreeMapper.endVisitEmptyLine()"
		return undef

	# ..........................................................

	visitComment: (hNode, hUser, hParent) ->

		dbgEnter "visitComment", hNode, hUser, hParent
		{uobj, level} = hNode
		assert isString(uobj), "uobj not a string"
		result = indented(uobj, level)
		dbgReturn "visitComment", result
		return result

	# ..........................................................

	endVisitComment: (hNode, hUser, hParent) ->

		dbg "in TreeMapper.endVisitComment()"
		return undef

	# ..........................................................

	visitCmd: (hNode, hUser, hParent) ->

		dbg "in TreeMapper.visitCmd() - ERROR"
		{cmd, argstr, level} = hNode.uobj

		# --- NOTE: built in commands, e.g. #ifdef
		#           are handled during the mapping phase
		croak "Unknown cmd: '#{cmd} #{argstr}'"

	# ..........................................................

	endVisitCmd: (hNode, hUser, hParent) ->

		dbg "in TreeMapper.endVisitCmd()"
		return undef

	# ..........................................................

	visitSpecial: (type, hNode, hUser, stack) ->

		dbgEnter "TreeMapper.visitSpecial", type, hNode, hUser
		visiter = @hSpecialVisitTypes[type].visiter
		assert defined(visiter), "No such type: #{OL(type)}"
		func = visiter.bind(this)
		assert isFunction(func), "not a function"
		result = func(hNode, hUser, hUser._parent, stack)
		dbgReturn "TreeMapper.visitSpecial", result
		return result

	# ..........................................................

	endVisitSpecial: (type, hNode, hUser, stack) ->

		func = @hSpecialVisitTypes[type].endVisiter.bind(this)
		return func(hNode, hUser, hUser._parent, stack)

	# ..........................................................
	# ..........................................................

	getBlock: (hOptions={}) ->
		# --- Valid options: logNodes

		dbgEnter "getBlock"
		lLines = @walk(hOptions)
		if isArrayOfStrings(lLines)
			block = toBlock(lLines)
		else
			block = lLines
		dbg 'block', block
		result = @finalizeBlock(block)
		dbgReturn "getBlock", result
		return result

# ---------------------------------------------------------------------------
# UTILITIES
# ---------------------------------------------------------------------------

export trace = (source, content=undef) ->

	dbgEnter "trace", source, content
	mapper = new TreeMapper(source, content)
	mapper.walk({logNodes: true})
	result = mapper.getLog()
	dbgReturn "trace", result
	return result

# ---------------------------------------------------------------------------

hstr = (h) ->
	# --- Don't include the _parent pointer
	#     if an object has a toDebugStr() method, use that

	hNew = {}
	for own key,value of h
		if (key != '_parent')
			hNew[key] = value
	if isEmpty(hNew)
		return ''
	else
		return OL(hNew)
