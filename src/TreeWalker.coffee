# TreeWalker.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, defined, notdefined, OL, rtrim, words,
	isString, isNumber, isFunction, isArray, isHash, isInteger,
	isEmpty, nonEmpty, isArrayOfStrings,
	} from '@jdeighan/coffee-utils'
import {toBlock} from '@jdeighan/coffee-utils/block'
import {log, LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {
	splitLine, indentLevel, indented, undented,
	} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Mapper} from '@jdeighan/mapper'
import {lineToParts, mapHereDoc} from '@jdeighan/mapper/heredoc'
import {RunTimeStack} from '@jdeighan/mapper/stack'

# ===========================================================================
#   class TreeWalker
#      - mapNonSpecial() returns mapped item (i.e. uobj) or undef
#   to use, override:
#      mapNode(hNode) - returns user object, def: returns hNode.str
#      mapCmd(hNode)
#      beginLevel(hUser, level)
#      visit(hNode, hUser, hParent, stack)
#      endVisit(hNode, hUser, hParent, stack)
#      endLevel(hUser, level) -

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
	#     1. replace HEREDOCs
	#     2. call mapNode()

	mapNonSpecial: (hNode) ->

		debug "enter TreeWalker.mapNonSpecial()", hNode
		assert notdefined(hNode.type), "hNode is #{OL(hNode)}"

		{str, level, srcLevel} = hNode

		# --- from here on, str is a non-empty string
		assert nonEmpty(str), "hNode is #{OL(hNode)}"
		assert isInteger(srcLevel, {min: 0}), "hNode is #{OL(hNode)}"

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (str.indexOf('<<<') >= 0)
			newStr = @handleHereDocsInLine(str, srcLevel)
			str = newStr
			debug "=> #{OL(str)}"
		else
			debug "no HEREDOCs"

		hNode.str = str

		# --- NOTE: mapNode() may return undef, meaning to ignore
		#     We must pass srcLevel since mapNode() may use fetch()
		uobj = @mapNode(hNode)
		debug "return from TreeWalker.mapNonSpecial()", uobj
		return uobj

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
				block = @fetchHereDocBlock(srcLevel)
				debug 'block', block

				uobj = mapHereDoc(block)
				assert defined(uobj), "mapHereDoc returned undef"
				debug 'mapped block', uobj

				str = @handleHereDoc(uobj, block)
				assert isString(str), "str is #{OL(str)}"
				lNewParts.push str
			else
				lNewParts.push part    # keep as is

		result = lNewParts.join('')
		debug "return from handleHereDocsInLine", result
		return result

	# ..........................................................

	fetchHereDocBlock: (srcLevel) ->
		# --- srcLevel is the level of the line with <<<

		debug "enter TreeWalker.fetchHereDocBlock(#{OL(srcLevel)})"
		func = (hNode) =>
			if isEmpty(hNode.str)
				return true
			else
				assert (hNode.srcLevel > srcLevel),
					"insufficient indentation: srcLevel=#{srcLevel}," \
					+ " node at #{hNode.srcLevel}"
				return false
		block = @fetchBlockUntil(func, 'discardEndLine')
		debug "return from TreeWalker.fetchHereDocBlock()", block
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

		debug "enter TreeWalker.mapCmd()", hNode

		{type, uobj, prefix, srcLevel} = hNode
		assert (type == 'cmd'), 'not a command'
		{cmd, argstr} = uobj
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
					lSkipLines = @skipLinesAtLevel(srcLevel)
					debug "Skip #{lSkipLines.length} lines"
				debug "return undef from TreeWalker.mapCmd()"
				return undef

		debug "call super"
		uobj = super(hNode)
		debug "return from TreeWalker.mapCmd()", uobj
		return uobj

	# ..........................................................

	skipLinesAtLevel: (srcLevel) ->
		# --- srcLevel is the level of #ifdef or #ifndef
		#     don't discard the end line

		debug "enter TreeWalker.skipLinesAtLevel(#{OL(srcLevel)})"
		func = (hNode) =>
			return (hNode.srcLevel <= srcLevel)
		block = @fetchBlockUntil(func, 'keepEndLine')
		debug "return from TreeWalker.skipLinesAtLevel()", block
		return block

	# ..........................................................

	fetchBlockAtLevel: (srcLevel) ->
		# --- srcLevel is the level of enclosing cmd/tag
		#     don't discard the end line

		debug "enter TreeWalker.fetchBlockAtLevel(#{OL(srcLevel)})"
		func = (hNode) =>
			return (hNode.srcLevel <= srcLevel) && nonEmpty(hNode.str)
		block = @fetchBlockUntil(func, 'keepEndLine')
		debug "return from TreeWalker.fetchBlockAtLevel()", block
		return block

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

	walk: (hOptions={}) ->
		# --- Valid options: logNodes, traceNodes
		#     returns an array, normally strings

		debug "enter TreeWalker.walk()", hOptions
		{logNodes, traceNodes} = hOptions   # unpack options

		# --- Initialize local state

		lLines = []   # --- resulting output lines (but may be objects)
		lTrace = []   # --- trace of nodes visited
		stack = new RunTimeStack()   # --- a stack of Node objects
		hGlobalUser = {}

		# .......................................................
		#     Local Functions
		# .......................................................

		add = (text) =>
			# --- in fact, text can be any type of object

			debug "enter add()", text
			assert defined(text), "text is undef"
			if isArray(text)
				debug "text is an array"
				lLines.push text...
			else
				debug "add text #{OL(text)}"
				lLines.push text
			debug "return from add()"
			return

		# .......................................................

		trace = (text, level=0) =>

			lTrace.push "#{'   '.repeat(level)}#{text}"
			return

		# .......................................................

		doBeginWalk = (hUser) =>

			debug "enter doBeginWalk()"
			if traceNodes
				trace "BEGIN WALK #{hstr(hGlobalUser)}"
			text = @beginWalk hUser
			if defined(text)
				add text
			debug "return from doBeginWalk()"
			return

		# .......................................................

		doEndWalk = (hUser) =>

			debug "enter doEndWalk()"
			if traceNodes
				trace "END WALK #{hstr(hGlobalUser)}"
			text = @endWalk hUser
			if defined(text)
				add text
			debug "return from doEndWalk()"
			return

		# .......................................................

		doBeginLevel = (hUser, level) =>

			debug "enter doBeginLevel()"
			if traceNodes
				trace "BEGIN LEVEL #{level} #{hstr(hUser)}", level
			text = @beginLevel hUser, level
			if defined(text)
				add text
			debug "return from doBeginLevel()"
			return

		# .......................................................

		doEndLevel = (hUser, level) =>

			debug "enter doEndLevel()"
			if traceNodes
				trace "END LEVEL #{level} #{hstr(hUser)}", level
			text = @endLevel hUser, level
			if defined(text)
				add text
			debug "return from doEndLevel()"
			return

		# .......................................................

		doVisit = (hNode) =>

			# --- visit the node
			{type, hUser, level, str, uobj} = hNode
			if traceNodes
				trace "VISIT #{level} #{OL(uobj)} #{hstr(hUser)}", level

			if defined(type)
				debug "type = #{type}"
				text = @visitSpecial(type, hNode, hUser, stack)
			else
				debug "no type"
				text = @visit(hNode, hUser, hUser._parent, stack)
			if defined(text)
				add text
			return

		# .......................................................

		doEndVisit = (hNode) =>

			# --- end visit the node
			{type, hUser, level, str, uobj} = hNode
			if traceNodes
				trace "END VISIT #{level} #{OL(uobj)} #{hstr(hUser)}", level

			if defined(type)
				debug "type = #{type}"
				text = @endVisitSpecial type, hNode, hUser, stack
			else
				debug "no type"
				text = @endVisit hNode, hUser, hUser._parent, stack
			if defined(text)
				add text
			return

		# .......................................................

		doBeginWalk hGlobalUser

		# --- Iterate over all input lines

		debug "getting lines"
		i = 0
		for hNode in Array.from(@allMapped()) # iterators mess up debugging

			# --- Log input lines for debugging

			if logNodes
				LOG "hNode[#{i}]", hNode
			else
				debug "hNode[#{i}]", hNode

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
				debug 'stack', stack
				continue    # restart the loop

			i += 1

			# --- add user hash

			hUser = hNode.hUser = {_parent: stack.TOS().hUser}

			# --- At this point, the previous node is on top of stack
			# --- End any levels > level

			while (stack.TOS().level > level)
				hPrevNode = stack.pop()
				debug "pop node", hPrevNode

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
			debug "pop node", hPrevNode

			doEndVisit hPrevNode
			doEndLevel hUser, hPrevNode.level

		doEndWalk hGlobalUser

		if traceNodes
			trace = toBlock(lTrace)
			debug "return from TreeWalker.walk()", lLines, trace
			return [lLines, trace]
		else
			debug "return from TreeWalker.walk()", lLines
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

		debug "enter visit()", hNode, hUser
		uobj = hNode.uobj
		debug "return from visit()", uobj
		return uobj

	# ..........................................................

	endVisit:  (hNode, hUser, hParent, stack) ->

		debug "enter endVisit()", hNode, hUser
		debug "return undef from endVisit()"
		return undef

	# ..........................................................

	visitEmptyLine: (hNode, hUser, hParent, stack) ->

		debug "in TreeWalker.visitEmptyLine()"
		return ''

	# ..........................................................

	endVisitEmptyLine: (hNode, hUser, hParent) ->

		debug "in TreeWalker.endVisitEmptyLine()"
		return undef

	# ..........................................................

	visitComment: (hNode, hUser, hParent) ->

		debug "enter visitComment()", hNode, hUser
		{uobj, level} = hNode
		assert isString(uobj), "uobj not a string"
		result = indented(uobj, level)
		debug "return from visitComment()", result
		return result

	# ..........................................................

	endVisitComment: (hNode, hUser, hParent) ->

		debug "in TreeWalker.endVisitComment()"
		return undef

	# ..........................................................

	visitCmd: (hNode, hUser, hParent) ->

		debug "in TreeWalker.visitCmd() - ERROR"
		{cmd, argstr, level} = hNode.uobj

		# --- NOTE: built in commands, e.g. #ifdef
		#           are handled during the mapping phase
		croak "Unknown cmd: '#{cmd} #{argstr}'"

	# ..........................................................

	endVisitCmd: (hNode, hUser, hParent) ->

		debug "in TreeWalker.endVisitCmd()"
		return undef

	# ..........................................................

	visitSpecial: (type, hNode, hUser, stack) ->

		debug "enter TreeWalker.visitSpecial()",
				type, hNode, hUser
		visiter = @hSpecialVisitTypes[type].visiter
		assert defined(visiter), "No such type: #{OL(type)}"
		func = visiter.bind(this)
		assert isFunction(func), "not a function"
		result = func(hNode, hUser, hUser._parent, stack)
		debug "return from TreeWalker.visitSpecial()", result
		return result

	# ..........................................................

	endVisitSpecial: (type, hNode, hUser, stack) ->

		func = @hSpecialVisitTypes[type].endVisiter.bind(this)
		return func(hNode, hUser, hUser._parent, stack)

	# ..........................................................
	# ..........................................................

	getBlock: (hOptions={}) ->
		# --- Valid options: logNodes, traceNodes

		debug "enter getBlock()"
		lLines = @walk(hOptions)
		if isArrayOfStrings(lLines)
			block = toBlock(lLines)
		else
			block = lLines
		debug 'block', block
		result = @finalizeBlock(block)
		debug "return from getBlock()", result
		return result

# ---------------------------------------------------------------------------
# UTILITIES
# ---------------------------------------------------------------------------

hstr = (h) ->
	# --- Don't include the _parent pointer
	#     if an object has a toDebugStr() method, use that

	nNew = {}
	for own key,value of h
		if (key != '_parent')
			hNew[key] = value
	if isEmpty(nNew)
		return ''
	else
		return OL(nNew)

# ---------------------------------------------------------------------------

export class TraceWalker extends TreeWalker

	getBlock: (hOptions={}) ->

		[result, trace] = super {traceNodes: true}
		return trace
