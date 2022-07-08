# TreeWalker.coffee

import {
	assert, undef, pass, croak, defined, OL, rtrim, words,
	isString, isNumber, isEmpty, nonEmpty, isArray, isHash, isInteger,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {
	splitLine, indentLevel, indented, undented,
	} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Mapper} from '@jdeighan/mapper'
import {lineToParts, mapHereDoc} from '@jdeighan/mapper/heredoc'

# ===========================================================================
#   class TreeWalker
#      - map() returns mapped item or undef
#      - bundle() returns {item, level}
#   to use, override:
#      mapStr(str) - returns user object, default returns str
#      handleCmd()
#      beginWalk() -
#      visit(uobj, hUser, level, lStack) -
#      endVisit(uobj, hUser, level, lStack) -
#      endWalk() -

export class TreeWalker extends Mapper

	constructor: (source=undef, collection=undef, hOptions={}) ->

		super source, collection, hOptions

		@srcLevel = 0
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

		[@srcLevel, str] = splitLine(item)
		debug "split: level = #{OL(@srcLevel)}, str = #{OL(str)}"
		assert nonEmpty(str), "empty string should be special"

		# --- check for extension lines, stop on blank line if found
		debug "check for extension lines"
		hOptions = {
			stopOn: ''
			}
		lExtLines = @fetchLinesAtLevel(@srcLevel+2, hOptions)
		assert isArray(lExtLines), "lExtLines not an array"
		debug "#{lExtLines.length} extension lines"
		if isEmpty(lExtLines)
			debug "no extension lines"
		else
			newstr = @joinExtensionLines(str, lExtLines)
			if (newstr != str)
				str = newstr
				debug "=> #{OL(str)}"

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (str.indexOf('<<<') >= 0)
			newStr = @handleHereDocsInLine(str)
			if (newStr != str)
				str = newStr
				debug "=> #{OL(str)}"
		else
			debug "no HEREDOCs"

		# --- NOTE: mapStr() may return undef, meaning to ignore
		item = @mapStr(str, @srcLevel)
		debug "return from map()", item
		return item

	# ..........................................................
	# --- designed to override

	mapStr: (str, srcLevel) ->

		return str

	# ..........................................................

	bundle: (item) ->

		return {
			item
			level: @realLevel()
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

	handleHereDocsInLine: (line) ->
		# --- Indentation has been removed from line
		# --- Find each '<<<' and replace with result of mapHereDoc()

		debug "enter handleHereDocsInLine()", line
		assert isString(line), "not a string"
		lParts = lineToParts(line)
		debug 'lParts', lParts
		lNewParts = []    # to be joined to form new line
		for part in lParts
			if part == '<<<'
				debug "get HEREDOC lines at level #{@srcLevel+1}"
				hOptions = {
					stopOn: ''
					discard: true    # discard the terminating empty line
					}

				# --- block will be undented
				block = @fetchBlockAtLevel(@srcLevel+1, hOptions)
				debug 'block', block

				cieloExpr = mapHereDoc(block)
				assert defined(cieloExpr), "mapHereDoc returned undef"
				debug 'cieloExpr', cieloExpr

				str = @handleHereDoc(cieloExpr, block)
				assert defined(str), "handleHereDoc returned undef"
				lNewParts.push str
			else
				lNewParts.push part    # keep as is

		result = lNewParts.join('')
		debug "return from handleHereDocsInLine", result
		return result

	# ..........................................................

	handleHereDoc: (cieloExpr, block) ->

		return cieloExpr

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
		@srcLevel = indentLevel(prefix)
		debug "srcLevel = #{@srcLevel}"

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
					@lMinuses.push @srcLevel
				else
					lSkipLines = @fetchLinesAtLevel(@srcLevel+1)
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
			if (@srcLevel > i)
				adjustment += 1
				lNewMinuses.push i
		@lMinuses = lNewMinuses
		return @srcLevel - adjustment

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
		debug "enter TreeWalker.fetchLinesAtLevel()", atLevel, stopOn
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

		debug "enter TreeWalker.fetchBlockAtLevel()", atLevel, hOptions
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

	visit: (item, hUser, level, lStack) ->

		debug "enter visit()", item, hUser, level
		result = indented(item, level)
		debug "return from visit()", result
		return result

	# ..........................................................

	endVisit:  (item, hUser, level, lStack) ->

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
		assert isHash(uobj, words('item level')),
				"user object is #{OL(uobj)}"
		{item, level} = uobj
		assert defined(item), "item is undef"
		assert isInteger(level), "level is #{OL(level)}"
		assert (level >= 0), "level is #{OL(level)}"
		return uobj

	# ..........................................................

	addText: (text) ->

		debug "enter addText()", text
		if defined(text)
			if isArray(text)
				debug "text is an array"
				@lLines.push text...
			else
				@lLines.push text
		debug "return from addText()"
		return

	# ..........................................................

	walk: () ->

		debug "enter walk()"

		# --- lStack is stack of node = {
		#        uobj: {item, level}
		#        hUser: {}
		#        }
		@lLines = []  # --- resulting lines
		lStack = []

		debug "begin walk"
		text = @beginWalk()
		@addText(text)

		debug "getting uobj's"
		for uobj from @allMapped()
			{_, level} = @checkUserObj uobj
			while (lStack.length > level)
				node = lStack.pop()
				@endVisitNode node, lStack

			# --- Create a user hash that the user can add to/modify
			#     and will see again at endVisit
			hUser = {}
			node = {uobj, hUser}
			@visitNode node, lStack
			lStack.push node

		while (lStack.length > 0)
			node = lStack.pop()
			@endVisitNode node, lStack

		text = @endWalk()
		@addText(text)
		result = arrayToBlock(@lLines)

		debug "return from walk()", result
		return result

	# ..........................................................

	visitNode: (node, lStack) ->

		assert isHash(node), "node is #{OL(node)}"
		{uobj, hUser} = node
		{item, level} = @checkUserObj uobj
		text = @visit(item, hUser, level, lStack)
		@addText(text)
		return

	# ..........................................................

	endVisitNode: (node, lStack) ->

		assert isHash(node), "node is #{OL(node)}"
		{uobj, hUser} = node
		assert isHash(hUser), "hUser is #{OL(hUser)}"
		{item, level} = @checkUserObj uobj
		text = @endVisit(item, hUser, level, lStack)
		@addText(text)
		return

	# ..........................................................

	getBlock: () ->

		debug "enter getBlock()"
		block = @walk()
		debug 'block', block
		result = @finalizeBlock(block)
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

	visit: (item, hUser, level, lStack) ->

		@lTrace.push "VISIT #{level} #{OL(item)}"
		return

	# ..........................................................

	endVisit: (item, hUser, level, lStack) ->

		@lTrace.push "END VISIT #{level} #{OL(item)}"
		return

	# ..........................................................

	endWalk: () ->

		@lTrace.push "END WALK"
		block = arrayToBlock(@lTrace)
		@lTrace = undef
		return block

# ---------------------------------------------------------------------------
