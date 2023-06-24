# TreeMapper.coffee

import {
	undef, pass, defined, notdefined, OL, rtrim, words,
	isString, isNumber, isFunction, isArray, isHash, isInteger,
	isEmpty, nonEmpty, getOptions, toBlock, isArrayOfStrings,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {
	LOG, LOGVALUE, clearMyLogs, getMyLogs, echoMyLogs,
	} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn, clearDebugLog, getDebugLog, callStack,
	} from '@jdeighan/base-utils/debug'
import {toTAML} from '@jdeighan/base-utils/taml'
import {
	splitLine, indentLevel, indented, undented, isUndented,
	} from '@jdeighan/coffee-utils/indent'

import {Mapper} from '@jdeighan/mapper'
import {replaceHereDocs} from '@jdeighan/mapper/heredoc'
import {RunTimeStack} from '@jdeighan/mapper/stack'

threeSpaces = "   "

# ===========================================================================
#   class TreeMapper
#   to use, override:
#      getUserObj(hNode) - returns user object
#         default: returns hNode.str
#      mapCmd(hNode)
#
#      beginLevel(hEnv, hNode)
#      endLevel(hEnv, hNode)
#
#      visit(hNode, hEnv, hParentEnv)
#      endVisit(hNode, hEnv, hParentEnv)
#
#      visitSpecial(hNode, hEnv, hParentEnv)
#      endVisitSpecial(hNode, hEnv, hParentEnv)
#   the call one of:
#      .getBlock() - to get a block of text

export class TreeMapper extends Mapper

	constructor: (hInput, hOptions={}) ->

		super hInput, hOptions

		@hSpecialVisitTypes = {}

		@registerVisitType 'empty',   @visitEmptyLine, @endVisitEmptyLine
		@registerVisitType 'comment', @visitComment,   @endVisitComment
		@registerVisitType 'cmd',     @visitCmd,       @endVisitCmd

		@lMinuses = []   # used to adjust level in #ifdef and #ifndef

	# ..........................................................

	registerVisitType: (type, visitor, endVisitor) ->

		assert @isValidType(type), "Unknown type: #{type}"
		@hSpecialVisitTypes[type] = {
			visitor
			endVisitor
			}
		return

	# ..........................................................
	# --- Will only receive non-special lines
	#        - adjust level if #ifdef or #ifndef was encountered
	#        - replace HEREDOCs
	#        - call getUserObj() - returns str by default

	mapToUserObj: (hNode) ->

		dbgEnter "TreeMapper.mapToUserObj", hNode
		@checkNonSpecial hNode

		if @adjustLevel(hNode)
			dbg "hNode.level adjusted #{hNode.srcLevel} => #{hNode.level}"
		else
			dbg "no level adjustment"

		{str, srcLevel} = hNode
		dbg "check for HEREDOC"
		if (str.indexOf('<<<') >= 0)
			newStr = replaceHereDocs(str, this)
			dbg "=> #{OL(newStr)}"
			assert isUndented(newStr),
				"after heredoc handling, str has indentation"
			hNode.str = newStr
		else
			dbg "no HEREDOCs"

		# --- NOTE: getUserObj() may return undef, meaning to ignore
		#     We must pass srcLevel since getUserObj() may use fetch()
		uobj = @getUserObj(hNode)
		dbgReturn "TreeMapper.mapToUserObj", uobj
		return uobj

	# ..........................................................

	getUserObj: (hNode) ->

		return hNode.str

	# ..........................................................

	checkNonSpecial: (hNode) ->

		{type, str, srcLevel, level} = hNode
		assert notdefined(hNode.type), "hNode is #{OL(hNode)}"
		assert nonEmpty(str), "empty str in #{OL(hNode)}"
		assert isUndented(str), "str has indentation"
		assert isInteger(srcLevel, {min: 0}), "Bad srcLevel in #{OL(hNode)}"
		assert isInteger(level, {min: 0}), "Bad level in #{OL(hNode)}"
		assert (level == srcLevel), "levels not equal in #{OL(hNode)}"
		return

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
				if (cmd == 'ifdef')
					keep = ok
				else
					keep = ! ok
				dbg "keep = #{OL(keep)}"
				if keep
					dbg "add #{srcLevel} to lMinuses"
					@lMinuses.push srcLevel
				else
					lSkipLines = @fetchLinesAtLevel(srcLevel+1)
					dbg "Skip #{lSkipLines.length} lines"
				dbgReturn "TreeMapper.mapCmd", undef
				return undef

		dbg "call super"
		uobj = super(hNode)
		dbgReturn "TreeMapper.mapCmd", uobj
		return uobj

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
	# ..........................................................

	walk: (hOptions={}) ->
		# --- returns an array, normally strings
		#     Valid options:
		#        logNodes
		#        logCalls
		#        logLines
		#        logHash
		#        logStack
		#        echo

		dbgEnter "TreeMapper.walk"

		hOptions = getOptions(hOptions)
		if hOptions.echo
			echoMyLogs()
		{logNodes,logCalls,logLines,logHash,logStack} = hOptions
		lDebugs = []
		for key in Object.keys(hOptions)
			if hOptions[key]
				lDebugs.push key
		if nonEmpty(lDebugs)
			dbg "DEBUG: #{lDebugs.join(',')}"

		# --- hParent for level 0 nodes
		hGlobalEnv = {
			_global_: true   # marker, for help debugging
			}

		lLines = []                   # --- resulting output
		stack = new RunTimeStack()    # --- a stack of Node objects

		# .......................................................
		#     Local Functions
		#     these MUST use fat-arrow syntax, to preserve 'this'
		# .......................................................

		logstr = (block, level=undef) =>

			dbgEnter 'logstr', block, level
			if defined(level)
				result = indented(block, level)
			else
				result = block
			dbgReturn 'logstr', result
			return result

		# .......................................................

		doLogNode = (hNode) =>

			if logNodes
				LOG logstr("----- NODE -----")
				LOG logstr(indented(toTAML(hNode)))
				LOG logstr("----------------")
			else
				# --- This works when debugging is set to 'walk'
				#     because we don't have dbgEnter/dbgReturn in here
				dbg "NODE: #{OL(hNode.level)} #{OL(hNode.uobj)}"
			return

		# .......................................................

		doLogCall = (call, level) =>

			if ! logCalls
				return
			if defined(level)
				str = logstr(call, level)
			else
				str = logstr(call)
			LOG str
			return

		# .......................................................

		doLogLines = (level) =>

			if ! logLines
				return
			LOG logstr("----- LINES -----", level)
			for line in lLines
				LOG logstr(indented(line), level)
			return

		# .......................................................

		doLogHash = (h, level) =>

			if ! logHash
				return
			if isEmpty(h)
				LOG logstr("----- EMPTY HASH -----", level)
			else
				LOG logstr("----- HASH -----", level)
				LOG logstr(toTAML(h), level)
			LOG logstr("----------------", level)
			return

		# .......................................................

		doLogStack = (level) =>

			if ! logStack
				return
			LOG logstr("----- STACK -----", level)
			LOG logstr(stack.desc(), level)
			LOG logstr("-----------------", level)
			return

		# .......................................................

		add = (item) =>
			# --- item can be any type of object
			#     returns true iff something was added

			dbgEnter "add", item
			if isString(item)
				dbg "add item #{OL(item)}"
				lLines.push item
				result = true
			else if isArray(item)
				dbg "item is an array"
				result = false
				for subitem in item
					if add subitem
						result = true
			else if notdefined(item)
				result = false
			else
				croak "Bad item: #{OL(item)}"
			dbgReturn "add", result
			return result

		# .......................................................

		doAddEnv = (hNode) =>

			if (hNode.level == 0)
				hNode.hEnv = {
					_hParEnv: hGlobalEnv
					}
			else
				hNode.hEnv = {
					_hParEnv: stack.TOS().hEnv
					}
			# --- This logs when debugging is set to 'walk'
			#     because we don't have dbgEnter/dbgReturn in here
			dbg "ADD ENV: #{OL(hNode.hEnv)}"
			return

		# .......................................................

		doBeginLevel = (hNode) =>

			dbgEnter 'doBeginLevel', level
			{level, hEnv} = hNode
			assert isHash(hEnv), "node has no env"
			_hParEnv = hEnv._hParEnv
			assert isHash(_hParEnv), "node's env has no parent env"

			doLogCall "BEGIN LEVEL #{level}", level
			added = add @beginLevel(_hParEnv, hNode)
			if added
				doLogLines level
			doLogHash hEnv, level
			dbgReturn 'doBeginLevel'
			return

		# .......................................................

		doEndLevel = (hNode) =>

			dbgEnter 'doEndLevel', level
			{level, hEnv} = hNode
			assert isHash(hEnv), "node has no env"
			_hParEnv = hEnv._hParEnv
			assert isHash(_hParEnv), "node's env has no parent env"

			doLogCall "END LEVEL #{level}", level
			added = add @endLevel(_hParEnv, hNode)
			if added
				doLogLines level
			doLogHash hEnv, level
			dbgReturn 'doEndLevel'
			return

		# .......................................................

		doVisitNode = (hNode) =>

			dbgEnter 'doVisitNode'
			{type, level, uobj, hEnv} = hNode
			assert isHash(hEnv), "node has no env"
			_hParEnv = hEnv._hParEnv
			assert isHash(_hParEnv), "node's env has no parent env"
			doLogCall "VISIT #{level} #{OL(uobj)}", level

			if defined(type)
				added = add @visitSpecial(hNode, hEnv, _hParEnv)
			else
				added = add @visit(hNode, hEnv, _hParEnv)
			if added
				doLogLines level

			doLogHash hEnv, level
			dbgReturn 'doVisitNode'
			return

		# .......................................................

		doEndVisitNode = (hNode) =>

			dbgEnter 'doEndVisitNode'
			{type, level, uobj, hEnv} = hNode
			doLogCall "END VISIT #{level} #{OL(uobj)}", level

			if defined(type)
				added = add @endVisitSpecial(hNode, hEnv, hEnv._hParEnv)
			else
				added = add @endVisit(hNode, hEnv, hEnv._hParEnv)
			if added
				doLogLines level

			doLogHash hEnv, level
			dbgReturn 'doEndVisitNode'
			return

		# .......................................................
		#     main body of walk()
		# .......................................................

		doLogCall "BEGIN WALK", 0
		added = add @beginWalk(hGlobalEnv)
		if added
			doLogLines 0
		doLogHash hGlobalEnv, 0

		# === Begin First Node ===

		hNode = @get()

		if notdefined(hNode)
			dbg "first node is not defined"
			doLogCall "END WALK"
			added = add @endWalk(hGlobalEnv)
			if added
				doLogLines 0
			doLogHash hGlobalEnv
			dbgReturn "TreeMapper.walk", lLines
			return lLines

		assert (hNode.level == 0), "1st node at level #{hNode.level}"
		doLogNode hNode

		doAddEnv hNode
		doBeginLevel hNode
		doVisitNode hNode

		dbg "push onto stack", hNode
		stack.push hNode
		doLogStack 0

		# --- From now on, there's always something on the stack
		#     Until the very end, where everything is popped off

		# === End First Node ===

		while defined(hNode = @get())
			doLogNode hNode

			# --- End any levels > hNode.level
			while (stack.TOS().level > hNode.level)
				hPopNode = stack.pop()
				dbg "POP: [#{OL(hPopNode.level)} #{OL(hPopNode.uobj)}]"
				doEndVisitNode hPopNode
				doEndLevel hPopNode

			# --- Now, there are 2 cases:
			#        1. TOS level = current node's level
			#        2. TOS level < current node's level

			if (stack.TOS().level == hNode.level)
				hPopNode = stack.pop()
				dbg "POP: [#{OL(hPopNode.level)} #{OL(hPopNode.uobj)}]"
				doEndVisitNode hPopNode
				newLevel = false
			else
				newLevel = true
				assert (stack.TOS().level < hNode.level), "Can't happen"

			doAddEnv hNode
			if newLevel
				doBeginLevel hNode
			doVisitNode hNode
			dbg "push onto stack", hNode
			stack.push hNode

		while (stack.size() > 0)
			hNode = stack.pop()
			dbg "pop node", hNode
			doEndVisitNode hNode
			doEndLevel(hNode)

		doLogCall "END WALK"
		added = add @endWalk hGlobalEnv
		if added
			doLogLines 0
		doLogHash hGlobalEnv

		dbgReturn "TreeMapper.walk", lLines
		return lLines

	# ..........................................................
	# These are designed to override
	# ..........................................................

	beginWalk: (hGlobalEnv) ->

		return undef

	# ..........................................................

	beginLevel: (hEnv, hNode) ->

		return undef

	# ..........................................................

	startLevel: (hEnv, level) ->

		croak "There is no startLevel() method - use beginLevel()"

	# ..........................................................

	endLevel: (hEnv, hNode) ->

		return undef

	# ..........................................................

	endWalk: (hEnv) ->

		return undef

	# ..........................................................

	visit: (hNode, hEnv, hParentEnv) ->

		dbgEnter "TreeMapper.visit", hNode
		{uobj, level} = hNode
		if isString(uobj) && (level > 0)
			uobj = indented(uobj, level, @oneIndent)
		dbgReturn "TreeMapper.visit", uobj
		return uobj

	# ..........................................................

	endVisit:  (hNode, hEnv, hParentEnv) ->

		dbgEnter "TreeMapper.endVisit", hNode
		dbgReturn "TreeMapper.endVisit", undef
		return undef

	# ..........................................................

	visitEmptyLine: (hNode, hEnv, hParentEnv) ->

		dbg "in TreeMapper.visitEmptyLine()"
		return ''

	# ..........................................................

	endVisitEmptyLine: (hNode, hEnv, hParentEnv) ->

		dbg "in TreeMapper.endVisitEmptyLine()"
		return undef

	# ..........................................................

	visitComment: (hNode, hEnv, hParentEnv) ->

		dbgEnter "TreeMapper.visitComment", hNode

		# --- NOTE: in Mapper.isComment(), the comment text
		#           is placed in hNode._commentText

		{uobj, level, _commentText} = hNode
		assert isString(uobj), "uobj not a string"
		result = indented(uobj, level, @oneIndent)
		hEnv.commentText = _commentText
		dbgReturn "TreeMapper.visitComment", result
		return result

	# ..........................................................

	endVisitComment: (hNode, hEnv, hParentEnv) ->

		dbg "in TreeMapper.endVisitComment()"
		return undef

	# ..........................................................

	visitCmd: (hNode, hEnv, hParentEnv) ->

		dbg "in TreeMapper.visitCmd() - ERROR"
		{uobj} = hNode
		{cmd, argstr, level} = hNode.uobj

		# --- NOTE: built in commands, e.g. #ifdef
		#           are handled during the mapping phase
		croak "Unknown cmd: '#{cmd} #{argstr}'"

	# ..........................................................

	endVisitCmd: (hNode, hEnv, hParentEnv) ->

		dbg "in TreeMapper.endVisitCmd()"
		return undef

	# ..........................................................

	visitSpecial: (hNode, hEnv, hParentEnv) ->

		dbgEnter "TreeMapper.visitSpecial", hNode
		{type} = hNode
		visitor = @hSpecialVisitTypes[type].visitor
		assert defined(visitor), "No such type: #{OL(type)}"
		func = visitor.bind(this)
		assert isFunction(func), "not a function"
		result = func(hNode, hEnv, hParentEnv)
		dbgReturn "TreeMapper.visitSpecial", result
		return result

	# ..........................................................

	endVisitSpecial: (hNode, hEnv, hParentEnv) ->

		dbgEnter "TreeMapper.endVisitSpecial", hNode
		{type} = hNode
		endVisitor = @hSpecialVisitTypes[type].endVisitor
		assert defined(endVisitor), "No such type: #{OL(type)}"
		func = endVisitor.bind(this)
		result = func(hNode, hEnv, hParentEnv)
		dbgReturn "TreeMapper.endVisitSpecial", result
		return result

	# ..........................................................

	getBlock: (hOptions=undef) ->

		dbgEnter "getBlock"
		lLines = @walk(hOptions)
		dbg 'lLines', lLines
		block = toBlock(lLines)
		dbg 'block', block
		result = @finalizeBlock(block)
		dbgReturn "getBlock", result
		return result

# ---------------------------------------------------------------------------
# UTILITIES
# ---------------------------------------------------------------------------

export getTrace = (hInput, hOptions='logCalls') ->

	dbgEnter "getTrace", hInput
	mapper = new TreeMapper(hInput)
	clearMyLogs()
	mapper.walk(hOptions)
	result = getMyLogs()
	dbgReturn "getTrace", result
	return result
