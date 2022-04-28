# CieloMapper.coffee

import {
	undef, assert, croak, OL, replaceVars,
	isString, isEmpty, nonEmpty, isArray, isHash, isBoolean,
	} from '@jdeighan/coffee-utils'
import {arrayToBlock} from '@jdeighan/coffee-utils/block'
import {undented, splitLine, indentLevel} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'

import {Mapper} from '@jdeighan/mapper'
import {lineToParts, mapHereDoc} from '@jdeighan/mapper/heredoc'

# ===========================================================================

export class CieloMapper extends Mapper
	# - removes blank lines (but can be overridden)
	# - does NOT remove comments (but can be overridden)
	# - joins continuation lines
	# - handles HEREDOCs
	# - handles #define <name> <value> and __<name>__ substitution

	constructor: (source, content=undef) ->

		debug "enter CieloMapper(source='#{source}')", content
		super source, content

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
	# --- override to keep variable LINE updated

	incLineNum: (inc) ->

		super inc    # adjusts property @lineNum
		@hVars.LINE = @lineNum
		return

	# ..........................................................
	# --- designed to override with a mapping method
	#     NOTE: line does not include the indentation

	mapLine: (line, level) ->

		debug "enter CieloMapper.mapLine(#{OL(line)}, #{level})"

		assert line?, "mapLine(): line is undef"
		assert isString(line), "mapLine(): #{OL(line)} not a string"
		if isEmpty(line)
			result = @handleEmptyLine(@curLevel)
			debug "return from CieloMapper.mapLine() - empty line", result
			return result

		if @isComment(line)
			result = @handleComment(line, level)
			debug "return from CieloMapper.mapLine() - comment", result
			return result

		lParts = @isCommand(line)
		if lParts
			debug "COMMAND", lParts
			[cmd, argstr] = lParts

			lResult = @handleCommand(cmd, argstr, level)
			debug "handleCommand() returned #{OL(lResult)}"
			assert isArray(lResult), "handleCommand() failed to return array"

			[handled, result] = lResult
			assert isBoolean(handled),
					"1st arg in handleCommand() result isn't boolean"
			if handled
				debug "return from CieloMapper.mapLine()", result
				return result
			else
				croak "Unknown command: '#{line}'"

		# --- Merge in any continuation lines
		debug "check for continuation lines"
		lContLines = @getContLines(level)
		if isEmpty(lContLines)
			debug "no continuation lines found"
		else
			debug "#{lContLines.length} continuation lines found"
			line = @joinContLines(line, lContLines)
			debug "line becomes #{OL(line)}"

		debug "hVars", @hVars
		debug 'line', line
		newline = replaceVars(line, @hVars)
		if newline != line
			line = newline
			debug "line becomes #{OL(line)}"

		orgLineNum = @lineNum
		@curLevel = level

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (line.indexOf('<<<') > -1)
			hResult = @handleHereDoc(line, level)
			line = hResult.line
			debug "line becomes #{OL(line)}"

		debug "mapping string"
		result = @mapString(line, level)
		debug "return #{OL(result)} from CieloMapper.mapLine()"
		return result

	# ..........................................................

	handleEmptyLine: (level) ->

		debug "in CieloMapper.handleEmptyLine()"

		# --- remove blank lines by default
		#     return '' to retain empty lines
		return undef

	# ..........................................................

	isComment: (line, level) ->

		lMatches = line.match(///^
				(\#+)     # one or more # characters
				(.|$)     # following character, if any
				///)
		if lMatches
			[_, hashes, ch] = lMatches
			return (hashes.length > 1) || (ch in [' ','\t',''])
		else
			return false

	# ..........................................................

	handleComment: (line, level) ->

		debug "in CieloMapper.handleComment()"
		return line      # keep comments by default

	# ..........................................................

	isCommand: (line, level) ->

		debug "enter CieloMapper.isCommand()"
		if lMatches = line.match(///^
				\#
				([A-Za-z_]\w*)   # name of the command
				\s*
				(.*)             # argstr for command
				$///)
			[_, cmd, argstr] = lMatches
			lResult = [cmd, argstr]
			debug "return from CieloMapper.isCommand()", lResult
			return lResult
		else
			# --- not a command
			debug "return undef from CieloMapper.isCommand()"
			return undef

	# ..........................................................
	# --- handleCommand must return a pair:
	#        [handled:boolean, result:any]

	handleCommand: (cmd, argstr, level) ->

		debug "enter CieloMapper.handleCommand #{cmd} '#{argstr}', #{level}"
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
				result = [true, undef]
			else
				result = [false, undef]
		debug "return from CieloMapper.handleCommand()", result
		return result

	# ..........................................................

	setVariable: (name, value) ->
		# --- value can be a non-string
		#     if so, when replacement occurs, it will be JSON stringified

		debug "enter setVariable('#{name}')", value
		assert isString(name), "name is not a string"
		if isString(value)
			assert (name not in ['DIR','FILE','LINE','END']),
					"Bad var name '#{name}'"
		@hVars[name] = value
		debug "return from setVariable()"
		return

	# ..........................................................

	handleHereDoc: (line, level) ->
		# --- Indentation has been removed from line
		# --- Find each '<<<' and replace with result of replaceHereDoc()

		assert isString(line), "handleHereDoc(): not a string"
		debug "enter handleHereDoc(#{OL(line)})"
		lParts = lineToParts(line)
		lObjects = []
		lNewParts = for part in lParts
			if part == '<<<'
				lLines = @getHereDocLines(level+1)
				hResult = @replaceHereDoc(arrayToBlock(lLines))
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

	replaceHereDoc: (block) ->
		# --- A method you can override

		hResult = mapHereDoc(block)
		assert isHash(hResult), "replaceHereDoc(): hResult not a hash"
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
				&& (line2 = @hereDocLine(undented(line, atLevel)))?
			assert (indentLevel(line) >= atLevel),
				"invalid indentation in HEREDOC section"
			lLines.push line2
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
	# ..........................................................

	mapString: (line, level) ->
		# --- NOTE: line has indentation removed
		#     when overriding, may return anything
		#     return undef to generate nothing

		assert isString(line),
				"default mapString(): #{OL(line)} is not a string"
		return line
