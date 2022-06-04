# CieloMapper.coffee

import {TreeWalker} from '@jdeighan/mapper/tree'

# ---------------------------------------------------------------------------

export class CieloMapper extends TreeWalker
	# - removes blank lines (but can be overridden)
	# - does NOT remove comments (but can be overridden)
	# - joins continuation lines
	# - handles HEREDOCs
	# - handles #define <name> <value> and __<name>__ substitution

	constructor: (content, source) ->
		super content, source
		debug "enter CieloMapper(source='#{source}')", content

		@hVars = {
			FILE: @filename
			DIR:  @hSourceInfo.dir
			LINE: 0
			}

		# --- This should only be used in mapLine(), where
		#     it keeps track of the level we're at, to be passed
		#     to handleEmptyLine() since the empty line itself
		#     is always at level 0
		@curLevel = 0
		debug "return from CieloMapper()"

	# ..........................................................
	# --- designed to override with a mapping method
	#     NOTE: line does not include the indentation

	mapLine: (line, level) ->

		debug "enter CieloMapper.mapLine(#{OL(line)}, #{level})"

		assert line?, "mapLine(): line is undef"
		assert isString(line), "mapLine(): #{OL(line)} not a string"
		if isEmpty(line)
			result = @handleEmptyLine(@curLevel)
			debug "return #{OL(result)} from CieloMapper.mapLine() - empty line"
			return result

		debug "line is not empty, checking for command"
		lParts = @splitCommand(line)
		if lParts
			debug "found command", lParts
			[cmd, tail] = lParts
			result = @handleCommand cmd, tail, level
			debug "return #{OL(result)} from CieloMapper.mapLine() - command handled"
			return result

		if isComment(line)
			result = @handleComment(line, level)
			debug "return #{OL(result)} from CieloMapper.mapLine() - comment"
			return result

		debug "hVars", @hVars
		replaced = replaceVars(line, @hVars)
		if replaced != line
			debug "replaced", replaced

		orgLineNum = @lineNum
		@curLevel = level

		# --- Merge in any continuation lines
		debug "check for continuation lines"
		lContLines = @getContLines(level)
		if isEmpty(lContLines)
			debug "no continuation lines found"
			longline = replaced
		else
			debug "#{lContLines.length} continuation lines found"
			longline = @joinContLines(replaced, lContLines)
			debug "line becomes #{OL(longline)}"

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (line.indexOf('<<<') == -1)
			verylongline = longline
		else
			hResult = @handleHereDoc(longline, level)
			verylongline = hResult.line
			debug "line becomes #{OL(verylongline)}"

		debug "mapping string"
		result = @mapString(verylongline, level)
		debug "return #{OL(result)} from CieloMapper.mapLine()"
		return result

	# ..........................................................

	handleEmptyLine: (level) ->

		debug "in CieloMapper.handleEmptyLine()"

		# --- remove blank lines by default
		#     return '' to retain empty lines
		return undef

	# ..........................................................

	splitCommand: (line, level) ->

		debug "enter CieloMapper.splitCommand()"
		if lMatches = line.match(///^
				\#
				([A-Za-z_]\w*)   # name of the command
				\s*
				(.*)             # argstr for command
				$///)
			[_, cmd, argstr] = lMatches
			lResult = [cmd, argstr]
			debug "return from CieloMapper.splitCommand()", lResult
			return lResult
		else
			# --- not a command
			debug "return undef from CieloMapper.splitCommand()"
			return undef

	# ..........................................................

	handleCommand: (cmd, argstr, level) ->

		debug "enter handleCommand #{cmd} '#{argstr}', #{level}"
		switch cmd
			when 'define'
				if lMatches = argstr.match(///^
						(env\.)?
						([A-Za-z_][\w\.]*)   # name of the variable
						(.*)
						$///)
					[_, prefix, name, tail] = lMatches
					tail = tail.trim()
					if prefix
						debug "set env var #{name} to '#{tail}'"
						process.env[name] = tail
					else
						debug "set var #{name} to '#{tail}'"
						@setVariable name, tail

		debug "return undef from handleCommand()"
		return undef   # return value added to output if not undef

	# ..........................................................

	setVariable: (name, value) ->

		debug "enter setVariable('#{name}')", value
		assert isString(name), "name is not a string"
		assert isString(value), "value is not a string"
		assert (name not in ['DIR','FILE','LINE','END']),\
				"Bad var name '#{name}'"
		@hVars[name] = value
		debug "return from setVariable()"
		return

	# ..........................................................
	# --- override to keep variable LINE updated

	incLineNum: (inc) ->
		super inc    # adjusts property @lineNum
		@hVars.LINE = @lineNum
		return

	# ..........................................................

	getContLines: (curlevel) ->

		lLines = []
		while (nextLine = @fetch(true))? \
				&& (nonEmpty(nextLine)) \
				&& ([nextLevel, nextStr] = splitLine(nextLine)) \
				&& (nextLevel >= curlevel+2)
			lLines.push(nextStr)
		if nextLine?
			# --- we fetched a line we didn't want
			@unfetch nextLine
		return lLines

	# ..........................................................

	joinContLines: (line, lContLines) ->

		for contLine in lContLines
			if lMatches = line.match(/\s*\\$/)
				n = lMatches[0].length
				line = line.substr(0, line.length - n)
			line += ' ' + contLine
		return line

	# ..........................................................

	isComment: (line, level) ->

		debug "in CieloMapper.isComment()"
		return stdIsComment(line, level)

	# ..........................................................

	handleComment: (line, level) ->

		debug "in CieloMapper.handleComment()"
		return line      # keep comments by default

	# ..........................................................

	mapString: (line, level) ->
		# --- NOTE: line has indentation removed
		#     when overriding, may return anything
		#     return undef to generate nothing

		assert isString(line),
				"default mapString(): #{OL(line)} is not a string"
		return line

	# ..........................................................

	mapHereDoc: (block) ->
		# --- A method you can override
		#     Distinct from the mapHereDoc() function found in /heredoc

		hResult = mapHereDoc(block)
		assert isHash(hResult), "mapHereDoc(): hResult not a hash"
		return hResult

	# ..........................................................

	handleHereDoc: (line, level) ->
		# --- Indentation has been removed from line
		# --- Find each '<<<' and replace with result of mapHereDoc()

		assert isString(line), "handleHereDoc(): not a string"
		debug "enter handleHereDoc(#{OL(line)})"
		lParts = lineToParts(line)
		lObjects = []
		lNewParts = for part in lParts
			if part == '<<<'
				lLines = @getHereDocLines(level+1)
				hResult = @mapHereDoc(arrayToBlock(lLines))
				lObjects.push hResult.obj
				hResult.str
			else
				part    # keep as is

		hResult = {
			line: lNewParts.join('')
			lParts: lParts
			lObjects: lObjects
			}

		debug "return from handleHereDoc", hResult
		return hResult

	# ..........................................................

	getHereDocLines: (atLevel) ->
		# --- Get all lines until addHereDocLine() returns undef
		#     atLevel will be one greater than the indent
		#        of the line containing <<<

		# --- NOTE: splitLine() removes trailing whitespace
		debug "enter CieloMapper.getHereDocLines()"
		lLines = []
		while (line = @fetch())? \
				&& (newline = @hereDocLine(undented(line, atLevel)))?
			assert (indentLevel(line) >= atLevel),
				"invalid indentation in HEREDOC section"
			lLines.push newline
		assert isArray(lLines), "getHereDocLines(): retval not an array"
		debug "return from CieloMapper.getHereDocLines()", lLines
		return lLines

	# ..........................................................

	hereDocLine: (line) ->

		if isEmpty(line)
			return undef        # end the HEREDOC section
		else if (line == '.')
			return ''           # interpret '.' as blank line
		else
			return line
