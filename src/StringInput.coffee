# StringInput.coffee

import {strict as assert} from 'assert'
import fs from 'fs'
import pathlib from 'path'

import {
	undef, log, pass, croak, isString, isEmpty, isComment, isArray, isHash,
	escapeStr, deepCopy, stringToArray, unitTesting, oneline,
	} from '@jdeighan/coffee-utils'
import {slurp} from '@jdeighan/coffee-utils/fs'
import {splitLine, indented, undented} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {getFileContents} from '@jdeighan/string-input/convert'

# ---------------------------------------------------------------------------
#   class StringInput - stream in lines from a string or array

export class StringInput

	constructor: (content, @hOptions={}) ->
		# --- Valid options:
		#        filename

		{filename} = @hOptions

		if isEmpty(content)
			@lBuffer = []
		else if isString(content)
			@lBuffer = stringToArray(content)
		else if isArray(content)
			# -- make a deep copy
			@lBuffer = deepCopy(content)
		else
			croak "StringInput(): content must be array or string",
					content, "CONTENT"
		@lineNum = 0

		if filename
			try
				# --- We only want the bare filename
				{base} = pathlib.parse(filename)
				@filename = base
			catch
				@filename = filename
		else
			@filename = 'unit test'

		@lookahead = undef     # lookahead token, placed by unget
		@altInput = undef
		@altLevel = undef      # controls prefix prepended to lines

	# ..........................................................
	# --- designed to override with a mapping method
	#     NOTE: line includes the indentation

	mapLine: (line) ->

		return line

	# ..........................................................

	unget: (item) ->

		# --- item has already been mapped
		debug item, 'enter unget() with:'
		assert not @lookahead?
		@lookahead = item
		debug 'return from unget()'
		return

	# ..........................................................

	peek: () ->

		debug 'enter peek():'
		if @lookahead?
			debug "return lookahead token"
			return @lookahead
		item = @get()
		if not item?
			return undef
		@unget(item)
		debug item, 'return with:'
		return item

	# ..........................................................

	skip: () ->

		debug 'enter skip():'
		if @lookahead?
			@lookahead = undef
			debug "return: clear lookahead token"
			return
		@get()
		debug 'return from skip()'
		return

	# ..........................................................
	# --- Returns undef if either:
	#        1. there's no alt input
	#        2. get from alt input returns undef (then closes alt input)

	getFromAlt: () ->

		debug "enter getFromAlt()"
		if not @altInput
			croak "getFromAlt(): There is no alt input"
		result = @altInput.get()
		if result?
			debug result, "return with:"
			return indented(result, @altLevel)
		else
			@altInput = undef
			@altLevel = undef
			debug "return: alt returned undef, alt input removed"
			return undef

	# ..........................................................
	# --- Returns undef if either:
	#        1. there's no alt input
	#        2. get from alt input returns undef (then closes alt input)

	fetchFromAlt: () ->

		debug "enter fetchFromAlt()"
		if not @altInput
			croak "fetchFromAlt(): There is no alt input"
		result = @altInput.fetch()
		if result?
			debug result, "return with:"
			return indented(result, @altLevel)
		else
			debug "return: alt returned undef, alt input removed"
			@altInput = undef
			@altLevel = undef
			return undef

	# ..........................................................

	get: () ->

		debug "enter StringInput.get() - from #{@filename}"
		if @lookahead?
			saved = @lookahead
			@lookahead = undef
			debug "return lookahead token - from #{@filename}"
			return saved

		if @altInput && (line = @getFromAlt())?
			debug "return with '#{oneline(line)}' - from alt #{@filename}"
			return line

		line = @fetch()    # will handle #include
		debug "LINE: '#{oneline(line)}'"

		if not line?
			debug "return with undef at EOF - from #{@filename}"
			return undef

		result = @mapLine(line)
		while not result? && (@lBuffer.length > 0)
			line = @fetch()
			result = @mapLine(line)

		debug "return '#{oneline(result)}' - from #{@filename}"
		return result

	# ..........................................................
	# --- This should be used to fetch from @lBuffer
	#     to maintain proper @lineNum for error messages
	#     MUST handle #include

	fetch: () ->

		debug "enter fetch()"
		if @altInput && (result = @fetchFromAlt())?
			debug result, "return from alt with:"
			return result

		if @lBuffer.length == 0
			debug "return - empty buffer, return undef"
			return undef

		@lineNum += 1
		line = @lBuffer.shift()
		[level, str] = splitLine(line)

		if lMatches = str.match(///^
				\# include
				\s+
				(\S.*)
				$///)
			[_, fname] = lMatches
			assert not @altInput, "fetch(): altInput already set"
			if unitTesting
				debug "return 'Contents of #{fname}' - unit testing"
				return indented("Contents of #{fname}", level)
			contents = getFileContents(fname)
			@altInput = new StringInput(contents)
			@altLevel = level
			debug "alt input created at level #{level}"

			# --- We just created an alt input
			#     we need to get its first line
			altLine = @getFromAlt()
			if altLine?
				debug "fetch(): getFromAlt returned '#{altLine}'"
				line = altLine
			else
				debug "fetch(): alt was undef, retain line '#{line}'"

		debug "return '#{oneline(line)}' from buffer:"
		return line

	# ..........................................................
	# --- Put one or more lines back into lBuffer, to be fetched later

	unfetch: (str) ->

		debug str, "enter unfetch() with:"
		@lBuffer.unshift(str)
		@lineNum -= 1
		debug 'return from unfetch()'
		return

	# ..........................................................
	# --- Fetch a block of text at level or greater than 'level'
	#     as one long string
	# --- Designed to use in mapLine()

	fetchBlock: (atLevel) ->

		debug "enter fetchBlock(atLevel = #{atLevel})"
		lLines = []

		# --- NOTE: I absolutely hate using a backslash for line continuation
		#           but CoffeeScript doesn't continue while there is an
		#           open parenthesis like Python does :-(

		line = undef
		while (line = @fetch())?
			debug "LINE IS '#{oneline(line)}'"
			assert isString(line),
				"StringInput.fetchBlock(#{atLevel}) - not a string: #{line}"
			if isEmpty(line)
				debug "empty line"
				lLines.push ''
				continue
			[level, str] = splitLine(line)
			debug "LOOP: level = #{level}, str = '#{oneline(str)}'"
			if (level < atLevel)
				@unfetch(line)
				debug "RESULT: unfetch the line"
				break
			result = indented(str, level-atLevel)
			debug result, "RESULT:"
			lLines.push result

		retval = lLines.join('\n')
		debug retval, "return with (#{lLines.length} lines):"
		return retval

	# ..........................................................

	getAll: () ->

		debug "enter getAll()"
		lLines = []
		line = @get()
		while line?
			lLines.push(line)
			line = @get()
		debug "return #{lLines.length} lines from getAll()"
		return lLines

	# ..........................................................

	getAllText: () ->

		return @getAll().join('\n')

# ---------------------------------------------------------------------------

###

- removes blank lines and comments

- converts
		<varname> <== <expr>

	to:
		`$:`
		<varname> = <expr>

	coffeescript to:
		var <varname>;
		$:;
		<varname> = <js expr>;

	brewCoffee() to:
		var <varname>;
		$:
		<varname> = <js expr>;

- converts
		<==
			<code>

	to:
		`$:{`
		<code>
		`}`

	coffeescript to:
		$:{;
		<js code>
		};

	brewCoffee() to:
		$:{
		<js code>
		}

###

# ---------------------------------------------------------------------------
# --- export to allow unit testing

export class CoffeeMapper extends StringInput
	# - removes blank lines and comments
	# - makes above conversions

	constructor: (content, hOptions) ->

		super content, hOptions

	mapLine: (orgLine) ->

		debug "enter mapLine()"
		[level, line] = splitLine(orgLine)
		if isEmpty(line) || isComment(line)
			return undef
		if (line == '<==')
			# --- Generate a reactive block
			code = @fetchBlock(level+1)    # might be empty
			if isEmpty(code)
				return undef
			result = """
					`$:{`
					#{code}
					`}`
					"""
			debug "return from mapLine()"
			return indented(result, level)
		if lMatches = line.match(///^
				([A-Za-z][A-Za-z0-9_]*)   # variable name
				\s*
				\< \= \=
				\s*
				(.*)
				$///)
			[_, varname, expr] = lMatches
			code = @fetchBlock(level+1)    # must be empty
			assert isEmpty(code),
					"mapLine(): indented code not allowed after '#{line}'"
			assert not isEmpty(expr),
					"mapLine(): empty expression in '#{line}'"
			result = """
					`$:`
					#{varname} = #{expr}
					"""
			debug "return from mapLine()"
			return indented(result, level)
		else
			debug "return from mapLine() - no match"
			return orgLine

# ---------------------------------------------------------------------------

export class CoffeePostMapper extends StringInput
	# --- variable declaration immediately following one of:
	#        $:{
	#        $:
	#     should be moved above this line

	mapLine: (line) ->

		if @savedLine
			if line.match(///^ \s* var \s ///)
				result = "#{line}\n#{@savedLine}"
			else
				result = "#{@savedLine}\n#{line}"
			@savedLine = undef
			return result

		if (line.match(///^ \s* \$ \: \{? ///))
			@savedLine = line
			return undef

		return line

# ---------------------------------------------------------------------------

export class SassMapper extends StringInput
	# --- only removes comments

	mapLine: (line) ->

		if isComment(line)
			return undef
		return line

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
#   class FileInput - contents from a file

export class FileInput extends StringInput

	constructor: (filename, hOptions={}) ->

		{root, dir, base, ext} = pathlib.parse(filename.trim())
		hOptions.filename = base
		if unitTesting
			content = "Contents of #{base}"
		else
			if not fs.existsSync(filename)
				croak "FileInput(): file '#{filename}' does not exist"
			content = slurp(filename)

		super content, hOptions

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# --- To derive a class from this:
#        1. Extend this class
#        2. Override mapString(), which gets the line with
#           any continuation lines appended, plus any
#           HEREDOC sections
#        3. If desired, override patchLine, which patches
#           HEREDOC lines into the original string

export class PLLParser extends StringInput

	constructor: (content, hOptions={}) ->

		super content, hOptions
		debug content, "new PLLParser: contents"

	getContLines: (curlevel) ->

		lLines = []
		while (nextLine = @fetch()) \
				&& ([nextLevel, nextStr] = splitLine(nextLine)) \
				&& (nextLevel >= curlevel+2)
			lLines.push(nextStr)
		if nextLine
			# --- we fetched a line we didn't want
			@unfetch nextLine
		return lLines

	# ..........................................................

	joinContLines: (line, lContLines) ->

		for str in lContLines
			line += ' ' + str
		return line

	# ..........................................................
	# ..........................................................

	patchLine: (line) ->
		# --- Find each '<<<' and replace with result of heredocStr()

		assert isString(line), "patchLine(): not a string"
		debug "enter patchLine('#{escapeStr(line)}')"
		lParts = []     # joined at the end
		pos = 0
		while ((start = line.indexOf('<<<', pos)) != -1)
			lParts.push line.substring(pos, start)
			lLines = @getHereDocLines()
			assert isArray(lLines), "patchLine(): lLines is not an array"
			if (lLines.length > 0)
				str = undented(lLines).join('\n')
				newstr = @heredocStr(str)
				assert isString(newstr), "patchLine(): newstr is not a string"
				lParts.push newstr
			pos = start + 3

		assert line.indexOf('<<<', pos) == -1,
			"patchLine(): Not all HEREDOC markers were replaced" \
				+ "in '#{line}'"
		lParts.push line.substring(pos, line.length)
		result = lParts.join('')
		debug "return '#{result}'"
		return result

	# ..........................................................

	getHereDocLines: () ->
		# --- Get all lines until empty line is found
		#     BUT treat line of a single period as empty line

		orgLineNum = @lineNum
		lLines = []
		while (@lBuffer.length > 0) && not isEmpty(@lBuffer[0])
			line = @fetch()
			if (line.trim() == '.')
				lLines.push ''
			else
				lLines.push line
		if (@lBuffer.length > 0)
			@fetch()   # empty line
		return lLines

	# ..........................................................

	heredocStr: (str) ->
		# --- return replacement string for '<<<'

		return str.replace(/\n/g, ' ')

	# ..........................................................

	handleEmptyLine: (lineNum) ->

		return undef      # skip blank lines by default

	# ..........................................................

	handleComment: (lineNum) ->

		return undef      # skip comments by default

	# ..........................................................

	mapString: (line, level) ->
		# --- NOTE: line has indentation removed

		return line

	# ..........................................................

	mapLine: (orgLine) ->

		assert orgLine?, "mapLine(): orgLine is undef"
		if isEmpty(orgLine)
			return @handleEmptyLine(@lineNum)

		if isComment(orgLine)
			return @handleComment(@lineNum)

		[level, line] = splitLine(orgLine)
		orgLineNum = @lineNum

		# --- Merge in any continuation lines
		lContLines = @getContLines(level)
		line = @joinContLines(line, lContLines)

		# --- handle HEREDOCs
		line = @patchLine(line)

		mapped = @mapString(line, level)
		if mapped?
			return [level, orgLineNum, mapped]
		else
			return undef

	# ..........................................................

	getTree: () ->

		debug "enter getTree()"
		lLines = @getAll()
		assert lLines?, "lLines is undef"
		assert isArray(lLines), "getTree(): lLines is not an array"
		debug "return #{lLines.length} lines from getTree()"
		return treeify(lLines)

# ---------------------------------------------------------------------------
# Each item must be a sub-array with 3 items: [<level>, <lineNum>, <node>]

export treeify = (lItems, atLevel=0) ->
	# --- stop when an item of lower level is found, or at end of array

	debug "enter treeify()"
	debug lItems, "lItems:"
	lNodes = []
	while (lItems.length > 0) && (lItems[0][0] >= atLevel)
		item = lItems.shift()
		assert isArray(item), "treeify(): item is not an array"
		len = item.length
		assert len == 3, "treeify(): item has length #{len}"
		[level, lineNum, node] = item
		assert level==atLevel,
			"treeify(): item at level #{level}, should be #{atLevel}"
		h = {node, lineNum}
		body = treeify(lItems, atLevel+1)
		if body?
			h.body = body
		lNodes.push(h)
	if lNodes.length==0
		debug "return undef from treeify"
		return undef
	else
		debug "return #{lNodes.length} nodes from treeify"
		return lNodes
