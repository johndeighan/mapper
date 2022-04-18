# Mapper.coffee

import fs from 'fs'
import pathlib from 'path'

import {
	assert, error, undef, pass, croak, isString, isEmpty, nonEmpty,
	escapeStr, isComment, isArray, isHash, isInteger, deepCopy,
	OL, CWS, replaceVars,
	} from '@jdeighan/coffee-utils'
import {
	blockToArray, arrayToBlock, firstLine, remainingLines,
	} from '@jdeighan/coffee-utils/block'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, pathTo, mydir, parseSource, mkpath, isDir,
	} from '@jdeighan/coffee-utils/fs'
import {
	splitLine, indented, undented, indentLevel,
	} from '@jdeighan/coffee-utils/indent'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {lineToParts, mapHereDoc} from '@jdeighan/mapper/heredoc'

# ---------------------------------------------------------------------------
#   class StringFetcher - stream in lines from a string
#       handles:
#          __END__
#          #include

export class StringFetcher

	constructor: (content, source=undef) ->

		if isEmpty(source)
			@setContent content, 'unit test'
		else
			@setContent content, source

		# --- for handling #include
		@altInput = undef
		@altLevel = undef    # indentation added to lines from alt
		@checkBuffer "StringFetcher constructor end"

	# ..........................................................

	setContent: (content, source) ->

		debug "enter setContent()", content

		# --- @hSourceInfo has keys: dir, filename, stub, ext, fullpath
		#     If source is 'unit test', just has:
		#     { filename: 'unit test', stub: 'unit test'}
		@hSourceInfo = parseSource(source)
		@filename = @hSourceInfo.filename
		assert @filename, "StringFetcher: parseSource returned no filename"
		if ! content?
			if @hSourceInfo.fullpath
				content = slurp(@hSourceInfo.fullpath)
				@lBuffer = blockToArray(content)
			else
				croak "StringFetcher: no source or fullpath"
		else if isEmpty(content)
			@lBuffer = []
		else if isString(content)
			@lBuffer = blockToArray(content)
		else if isArray(content)
			# -- make a deep copy
			@lBuffer = deepCopy(content)
		else
			croak "StringFetcher(): content must be a string",
					"CONTENT", content

		@lineNum = 0
		debug "return from setContent()", @lBuffer
		return

	# ..........................................................

	checkBuffer: (where="unknown") ->

		for str in @lBuffer
			if str == undef
				log "undef value in lBuffer in #{where}"
				croak "A string in lBuffer is undef"
			else if str.match(/\r/)
				log "string has a carriage return"
				croak "A string in lBuffer has a carriage return"
			else if str.match(/\n/)
				log "string has newline"
				croak "A string in lBuffer has a newline"
		return

	# ..........................................................

	getIncludeFileFullPath: (fname) ->

		debug "enter getIncludeFileFullPath('#{fname}')"

		# --- Make sure we have a simple file name
		{root, dir, base, ext} = pathlib.parse(fname)
		assert ! dir, "getIncludeFileFullPath(): not a simple file name"

		# --- Decide which directory to search for file
		dir = @hSourceInfo.dir
		if ! dir || ! isDir(dir)
			# --- Use current directory
			dir = process.cwd()

		path = pathTo(fname, dir)
		debug "path", path
		if path
			assert fs.existsSync(path), "path does not exist"
			debug "return from getIncludeFileFullPath()"
			return path
		else
			debug "return from getIncludeFileFullPath() - file not found"
			return undef

	# ..........................................................

	debugBuffer: () ->

		debug 'BUFFER', @lBuffer
		return

	# ..........................................................
	# --- Can override to add additional functionality

	incLineNum: (inc) ->

		@lineNum += inc
		return

	# ..........................................................

	fetch: (literal=false) ->
		# --- literal = true means don't handle #include,
		#               just return it as is

		debug "enter fetch(literal=#{literal}) from #{@filename}"
		# --- @checkBuffer "in fetch()"
		if @altInput
			assert @altLevel?, "fetch(): alt input without alt level"
			line = @altInput.fetch(literal)
			if line?
				result = indented(line, @altLevel)
				@incLineNum(1)
				debug "return #{OL(result)} from fetch() - alt"
				return result
			else
				# alternate input is exhausted
				@altInput = undef

		if (@lBuffer.length == 0)
			debug "return undef from fetch() - empty buffer"
			return undef

		# --- @lBuffer is not empty here
		line = @lBuffer.shift()
		if line == '__END__'
			@lBuffer = []
			debug "return from fetch() - __END__ seen"
			return undef
		@incLineNum(1)

		if ! literal && lMatches = line.match(///^
				(\s*)
				\# include
				\s+
				(\S.*)
				$///)
			[_, prefix, fname] = lMatches
			fname = fname.trim()
			debug "#include #{fname} with prefix #{OL(prefix)}"
			assert ! @altInput, "fetch(): altInput already set"
			includePath = @getIncludeFileFullPath(fname)
			if ! includePath?
				croak "Can't find include file #{fname} anywhere"

			contents = slurp(includePath)
			@altInput = new StringFetcher(contents, fname)
			@altLevel = indentLevel(prefix)
			debug "alt input created with prefix #{OL(prefix)}"
			line = @altInput.fetch()

			debug "first #include line found = '#{escapeStr(line)}'"
			@altInput.debugBuffer()

			if line?
				result = indented(line, @altLevel)
			else
				result = @fetch()    # recursive call
			debug "return #{OL(result)} from fetch()"
			return result
		else
			debug "return #{OL(line)} from fetch()"
			return line

	# ..........................................................
	# --- Put a line back into lBuffer, to be fetched later

	unfetch: (line) ->

		debug "enter unfetch(#{OL(line)})"
		assert isString(line), "unfetch(): not a string"
		if @altInput
			assert line?, "unfetch(): line is undef"
			@altInput.unfetch undented(line, @altLevel)
		else
			@lBuffer.unshift line
			@incLineNum(-1)
		debug 'return from unfetch()'
		return

	# ..........................................................

	getBlock: () ->

		debug "enter getBlock()"
		lLines = while line = @fetch()
			assert isString(line), "getBlock(): got non-string '#{OL(line)}'"
			line
		block = arrayToBlock(lLines)
		debug "return from getBlock()", block
		return block

# ===========================================================================
#   class Mapper
#      - keep track of indentation
#      - allow mapping of lines, including skipping lines
#      - implement look ahead via peek()

export class Mapper extends StringFetcher

	constructor: (content, source) ->
		super content, source
		@lookahead = undef   # --- lookahead token, placed by unget

		# --- cache in case getAll() is called multiple times
		#     each pair is [<mapped str>, <level>]
		@lAllPairs = undef

	# ..........................................................

	unget: (lPair) ->
		# --- lPair will always be [<item>, <level>]
		#     <item> can be anything - i.e. it's been mapped

		debug 'enter unget() with', lPair
		assert ! @lookahead?, "unget(): there's already a lookahead"
		@lookahead = lPair
		debug 'return from unget()'
		return

	# ..........................................................

	peek: () ->

		debug 'enter peek():'
		if @lookahead?
			debug "return lookahead from peek"
			return @lookahead
		lPair = @get()
		if ! lPair?
			debug "return undef from peek()"
			return undef
		@unget(lPair)
		debug "return #{OL(lPair)} from peek"
		return lPair

	# ..........................................................

	skip: () ->

		debug 'enter skip():'
		if @lookahead?
			@lookahead = undef
			debug "return from skip: clear lookahead"
			return
		@get()
		debug 'return from skip()'
		return

	# ..........................................................
	# --- designed to override with a mapping method
	#     which can map to any valid JavaScript value

	mapLine: (line, level) ->

		debug "enter Mapper.mapLine()"
		assert line? && isString(line), "Mapper.mapLine(): not a string"
		debug "return #{OL(line)}, #{level} from Mapper.mapLine()"
		return line

	# ..........................................................

	get: () ->

		debug "enter Mapper.get() - from #{@filename}"
		if @lookahead?
			saved = @lookahead
			@lookahead = undef
			debug "return lookahead pair from Mapper.get()"
			return saved

		line = @fetch()    # will handle #include
		debug "LINE", line

		if ! line?
			debug "return undef from Mapper.get() at EOF"
			return undef

		[level, str] = splitLine(line)
		result = @mapLine(str, level)
		debug "MAP: '#{str}' => #{OL(result)}"

		# --- if mapLine() returns undef, we skip that line

		while ! result? && (@lBuffer.length > 0)
			line = @fetch()
			[level, str] = splitLine(line)
			result = @mapLine(str, level)
			debug "MAP: '#{str}' => #{OL(result)}"

		if result?
			debug "return [#{OL(result)}, #{level}] from Mapper.get()"
			return [result, level]
		else
			debug "return undef from Mapper.get()"
			return undef

	# ..........................................................
	# --- Fetch a block of text at level or greater than 'level'
	#     as one long string
	# --- Designed to use in mapLine()

	fetchBlock: (atLevel) ->

		debug "enter fetchBlock(#{atLevel})"
		lLines = []

		# --- NOTE: I absolutely hate using a backslash for line continuation
		#           but CoffeeScript doesn't continue while there is an
		#           open parenthesis like Python does :-(

		line = undef
		while (line = @fetch())?
			debug "LINE IS #{OL(line)}"
			assert isString(line),
				"Mapper.fetchBlock(#{atLevel}) - not a string: #{line}"
			if isEmpty(line)
				debug "empty line"
				lLines.push ''
				continue
			[level, str] = splitLine(line)
			debug "LOOP: level = #{level}, str = #{OL(str)}"
			if (level < atLevel)
				@unfetch(line)
				debug "RESULT: unfetch the line"
				break
			result = indented(str, level-atLevel)
			debug "RESULT", result
			lLines.push result

		retval = lLines.join('\n')
		debug "return from fetchBlock with", retval
		return retval

	# ..........................................................

	getAll: () ->

		debug "enter Mapper.getAll()"
		if @lAllPairs?
			debug "return cached lAllPairs from Mapper.getAll()"
			return @lAllPairs
		lPairs = []

		# --- Each pair is [<result>, <level>],
		#     where <result> can be anything
		while (lPair = @get())?
			lPairs.push(lPair)
		@lAllPairs = lPairs
		debug "lAllPairs", @lAllPairs
		debug "return #{lPairs.length} pairs from Mapper.getAll()"
		return lPairs

	# ..........................................................

	getBlock: () ->

		lLines = for [line, level] in @getAll()
			assert isString(line), "getBlock(): got non-string"
			indented(line, level)
		return arrayToBlock(lLines)

# ===========================================================================

export stdSplitCommand = (line, level) ->

	if lMatches = line.match(///^
			\#
			([A-Za-z_]\w*)   # name of the command
			\s*
			(.*)             # argstr for command
			$///)
		[_, cmd, argstr] = lMatches
		return [cmd, argstr]
	else
		return undef      # not a command

# ---------------------------------------------------------------------------

export stdIsComment = (line, level) ->

	lMatches = line.match(///^
			(\#+)     # one or more # characters
			(.|$)     # following character, if any
			///)
	if lMatches
		[_, hashes, ch] = lMatches
		return (hashes.length > 1) || (ch in [' ','\t',''])
	else
		return false

# ---------------------------------------------------------------------------

export class CieloMapper extends Mapper
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

# ===========================================================================

export doMap = (inputClass, text, source='unit test') ->

	if lMatches = inputClass.toString().match(/class\s+(\w+)/)
		className = lMatches[1]
	else
		className = 'unknown'
	debug "enter doMap(#{className}) source='#{source}'"
	if inputClass
		oInput = new inputClass(text, source)
		assert oInput instanceof Mapper,
			"doMap() requires a Mapper or subclass"
	else
		oInput = new CieloMapper(text, source)
	result = oInput.getBlock()
	debug "return from doMap()", result
	return result
