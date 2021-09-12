# StringInput.coffee

import {strict as assert} from 'assert'
import fs from 'fs'
import pathlib from 'path'
import {dirname, resolve, parse as parse_fname} from 'path';

import {
	undef, pass, croak, isString, isEmpty, nonEmpty,
	isComment, isArray, isHash, isInteger, deepCopy,
	stringToArray, arrayToString, unitTesting, oneline,
	} from '@jdeighan/coffee-utils'
import {slurp, pathTo} from '@jdeighan/coffee-utils/fs'
import {splitLine, indented, undented} from '@jdeighan/coffee-utils/indent'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {markdownify} from '@jdeighan/string-input/markdown'
import {isTAML, taml} from '@jdeighan/string-input/taml'

# ---------------------------------------------------------------------------
#   class StringInput - stream in lines from a string or array

export class StringInput
	# --- handles #include statements

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
					"CONTENT", content
		@lineNum = 0

		debug "BUFFER", @lBuffer

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

	unget: (item) ->

		# --- item has already been mapped
		debug 'enter unget() with', item
		assert not @lookahead?
		@lookahead = item
		debug 'return from unget()'
		return

	# ..........................................................

	peek: () ->

		debug 'enter peek():'
		if @lookahead?
			debug "return lookahead token from peek"
			return @lookahead
		item = @get()
		if not item?
			debug "return from peek() - undef"
			return undef
		@unget(item)
		debug "return #{oneline(item)} from peek"
		return item

	# ..........................................................

	skip: () ->

		debug 'enter skip():'
		if @lookahead?
			@lookahead = undef
			debug "return from skip: clear lookahead token"
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
			debug "return #{oneline(result)} from getFromAlt"
			return indented(result, @altLevel)
		else
			@altInput = undef
			@altLevel = undef
			debug "return from getFromAlt: alt returned undef, alt input removed"
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
			"return #{oneline(result)} from getFromAlt()"
			return indented(result, @altLevel)
		else
			debug "return from fetchFromAlt: alt returned undef, alt input removed"
			@altInput = undef
			@altLevel = undef
			return undef

	# ..........................................................
	# --- designed to override with a mapping method
	#     NOTE: line includes the indentation

	mapLine: (line) ->

		debug "in default mapLine(#{oneline(line)})"
		return line

	# ..........................................................

	get: () ->

		debug "enter get() - src #{@filename}"
		if @lookahead?
			saved = @lookahead
			@lookahead = undef
			debug "return lookahead token from get() - src #{@filename}"
			return saved

		if @altInput && (line = @getFromAlt())?
			debug "return from get() with #{oneline(line)} - from alt #{@filename}"
			return line

		line = @fetch()    # will handle #include
		debug "LINE", line

		if not line?
			debug "return from get() with undef at EOF - src #{@filename}"
			return undef

		result = @mapLine(line)
		debug "MAP: '#{line}' => #{oneline(result)}"

		# --- if mapLine() returns undef, we skip that line

		while not result? && (@lBuffer.length > 0)
			line = @fetch()
			result = @mapLine(line)
			debug "'#{line}' mapped to '#{result}'"

		debug "return #{oneline(result)} from get() - src #{@filename}"
		return result

	# ..........................................................
	# --- This should be used to fetch from @lBuffer
	#     to maintain proper @lineNum for error messages
	#     MUST handle #include

	fetch: () ->

		debug "enter fetch()"
		if @altInput && (result = @fetchFromAlt())?
			debug "return alt #{oneline(result)} from fetch()"
			return result

		if @lBuffer.length == 0
			debug "return from fetch() - empty buffer, return undef"
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
				debug "return from fetch() 'Contents of #{fname}' - unit testing"
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

		debug "return from fetch() #{oneline(line)} from buffer:"
		return line

	# ..........................................................
	# --- Put one or more lines back into lBuffer, to be fetched later

	unfetch: (str) ->

		debug "enter unfetch()", str
		@lBuffer.unshift(str)
		@lineNum -= 1
		debug 'return from unfetch()'
		return

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
			debug "LINE IS #{oneline(line)}"
			assert isString(line),
				"StringInput.fetchBlock(#{atLevel}) - not a string: #{line}"
			if isEmpty(line)
				debug "empty line"
				lLines.push ''
				continue
			[level, str] = splitLine(line)
			debug "LOOP: level = #{level}, str = #{oneline(str)}"
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

		debug "enter getAll()"
		lLines = []
		line = @get()
		while line?
			lLines.push(line)
			line = @get()
		debug "return #{lLines.length} lines from getAll()"
		return lLines

	# ..........................................................

	skipAll: () ->
		# --- Useful if you don't need the final output, but, e.g.
		#     mapString() builds something that you will fetch

		line = @get()
		while line?
			line = @get()
		return

	# ..........................................................

	getAllText: () ->

		return arrayToString(@getAll())

# ===========================================================================

export class SmartInput extends StringInput
	# - removes blank lines and comments
	# - joins continuation lines
	# - handles HEREDOCs

	getContLines: (curlevel) ->

		lLines = []
		while (nextLine = @fetch())? \
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

		if isEmpty(lContLines)
			return line
		return line + ' ' + lContLines.join(' ')

	# ..........................................................

	handleEmptyLine: () ->

		debug "in default handleEmptyLine()"
		return undef      # skip blank lines by default

	# ..........................................................

	handleComment: () ->

		debug "in default handleComment()"
		return undef      # skip comments by default

	# ..........................................................
	# --- designed to override with a mapping method
	#     NOTE: line includes the indentation

	mapLine: (orgLine) ->

		debug "enter mapLine(#{oneline(orgLine)})"

		assert orgLine?, "mapLine(): orgLine is undef"
		if isEmpty(orgLine)
			debug "return undef from mapLine() - empty"
			return @handleEmptyLine()

		if isComment(orgLine)
			debug "return undef from mapLine() - comment"
			return @handleComment()

		[level, line] = splitLine(orgLine)
		orgLineNum = @lineNum

		# --- Merge in any continuation lines
		debug "check for continuation lines"
		lContLines = @getContLines(level)
		if nonEmpty(lContLines)
			line = @joinContLines(line, lContLines)
			debug "line becomes #{oneline(line)}"

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (line.indexOf('<<<') != -1)
			line = @handleHereDoc(line, level)
			debug "line becomes #{oneline(line)}"

		debug "mapping string"
		result = @mapString(line, level)
		debug "return #{oneline(result)} from mapLine()"
		return result

	# ..........................................................

	mapString: (line, level) ->
		# --- NOTE: line has indentation removed
		#     when overriding, may return anything
		#     return undef to generate nothing

		assert isString(line),
				"default mapString(): #{oneline(line)} is not a string"
		return indented(line, level)

	# ..........................................................

	handleHereDoc: (line, level) ->
		# --- Indentation is removed from line
		# --- Find each '<<<' and replace with result of heredocStr()

		assert isString(line), "handleHereDoc(): not a string"
		debug "enter handleHereDoc(#{oneline(line)})"
		lParts = []     # joined at the end
		pos = 0
		while ((start = line.indexOf('<<<', pos)) != -1)
			part = line.substring(pos, start)
			debug "PUSH #{oneline(part)}"
			lParts.push part
			lLines = @getHereDocLines(level)
			assert isArray(lLines), "handleHereDoc(): lLines not an array"
			debug "HEREDOC lines: #{oneline(lLines)}"
			if (lLines.length > 0)
				blk = arrayToString(undented(lLines))
				if isTAML(blk)
					result = taml(blk)
					newstr = JSON.stringify(result)
				else
					newstr = @heredocStr(blk)
				assert isString(newstr), "handleHereDoc(): newstr not a string"
				debug "PUSH #{oneline(newstr)}"
				lParts.push newstr
			pos = start + 3

		# --- If no '<<<' in string, just return original line
		if (pos == 0)
			debug "return from handleHereDoc - no <<< in line"
			return line

		assert line.indexOf('<<<', pos) == -1,
			"handleHereDoc(): Not all HEREDOC markers were replaced" \
				+ "in '#{line}'"
		part = line.substring(pos, line.length)
		debug "PUSH #{oneline(part)}"
		lParts.push part
		result = lParts.join('')
		debug "return from handleHereDoc", result
		return result

	# ..........................................................

	addHereDocLine: (lLines, line) ->

		if (line.trim() == '.')
			lLines.push ''
		else
			lLines.push line
		return

	# ..........................................................

	heredocStr: (str) ->
		# --- return replacement string for '<<<'

		return str.replace(/\n/sg, ' ')

	# ..........................................................

	getHereDocLines: (level) ->
		# --- Get all lines until empty line is found
		#     BUT treat line of a single period as empty line
		#     1st line should be indented level+1, or be empty

		lLines = []
		firstLineLevel = undef
		while (@lBuffer.length > 0) && not isEmpty(@lBuffer[0])
			line = @fetch()
			[lineLevel, str] = splitLine(line)

			if firstLineLevel?
				assert (lineLevel >= firstLineLevel),
					"invalid indentation in HEREDOC section"
				str = indented(str, lineLevel - firstLineLevel)
			else
				# --- This is the first line of the HEREDOC section
				if isEmpty(str)
					return []
				assert (lineLevel == level+1),
					"getHereDocLines(): 1st line indentation should be #{level+1}"
				firstLineLevel = lineLevel
			@addHereDocLine lLines, str

		if (@lBuffer.length > 0)
			@fetch()   # empty line
		return lLines

# ---------------------------------------------------------------------------

###

WHEN NOT UNIT TESTING

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

# ===========================================================================

export class CoffeeMapper extends SmartInput

	mapString: (line, level) ->

		debug "enter mapString(#{oneline(line)})"
		if (line == '<==')
			# --- Generate a reactive block
			code = @fetchBlock(level+1)    # might be empty
			if isEmpty(code)
				debug "return undef from mapString() - empty code block"
				return undef
			else
				result = """
						`$:{`
						#{code}
						`}`
						"""

		else if lMatches = line.match(///^
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
		else
			debug "return from mapLine() - no match"
			return indented(line, level)

		debug "return from mapLine()", result
		return indented(result, level)

# ---------------------------------------------------------------------------

export class CoffeePostMapper extends StringInput
	# --- variable declaration immediately following one of:
	#        $:{;
	#        $:;
	#     should be moved above this line

	mapLine: (line) ->

		if @savedLine
			if line.match(///^ \s* var \s ///)
				result = "#{line}\n#{@savedLine}"
			else
				result = "#{@savedLine}\n#{line}"
			@savedLine = undef
			return result

		if (lMatches = line.match(///^
				(\s*)       # possible leading whitespace
				\$ \:
				(\{)?       # optional {
				\;
				(.*)        # any remaining text
				$///))
			[_, ws, brace, rest] = lMatches
			assert not rest, "CoffeePostMapper: extra text after $:"
			if brace
				@savedLine = "#{ws}$:{"
			else
				@savedLine = "#{ws}$:"
			return undef
		else if (lMatches = line.match(///^
				(\s*)        # possible leading whitespace
				\}
				\;
				(.*)
				$///))
			[_, ws, rest] = lMatches
			assert not rest, "CoffeePostMapper: extra text after $:"
			return "#{ws}\}"
		else
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

export class FileInput extends SmartInput

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
#        2. Override mapNode(), which gets the line with
#           any continuation lines appended, plus any
#           HEREDOC sections expanded
#        3. If desired, override handleHereDoc, which patches
#           HEREDOC lines into the original string

export class PLLParser extends SmartInput

	mapString: (line, level) ->

		return [level, @lineNum, @mapNode(line)]

	# ..........................................................

	mapNode: (line) ->

		return line

	# ..........................................................

	getTree: () ->

		debug "enter getTree()"
		lLines = @getAll()
		debug "lLines = #{oneline(lLines)}"
		assert lLines?, "lLines is undef"
		assert isArray(lLines), "getTree(): lLines is not an array"
		tree = treeify(lLines)
		debug "return from getTree()", tree
		return tree

# ---------------------------------------------------------------------------
# Each item must be a sub-array with 3 items: [<level>, <lineNum>, <node>]
# If a predicate is supplied, it must return true for any <node>

export treeify = (lItems, atLevel=0, predicate=undef) ->
	# --- stop when an item of lower level is found, or at end of array

	debug "enter treeify(#{atLevel})"
	debug 'lItems', lItems
	try
		checkTree(lItems, predicate)
		debug "check OK"
	catch err
		croak err, 'lItems', lItems
	lNodes = []
	while (lItems.length > 0) && (lItems[0][0] >= atLevel)
		item = lItems.shift()
		len = item.length
		[level, lineNum, node] = item
		assert level==atLevel,
			"treeify(): item at level #{level}, should be #{atLevel}"
		h = {node, lineNum}
		body = treeify(lItems, atLevel+1)
		if body?
			h.body = body
		lNodes.push(h)
	if lNodes.length==0
		debug "return undef from treeify()"
		return undef
	else
		debug "return #{lNodes.length} nodes from treeify()", lNodes
		return lNodes

# ---------------------------------------------------------------------------

export checkTree = (lItems, predicate) ->

	# --- Each item should be a sub-array with 3 items:
	#        1. an integer - level
	#        2. an integer - a line number
	#        3. anything, but if predicate is defined, it must return true

	assert isArray(lItems), "treeify(): lItems is not an array"
	for item,i in lItems
		assert isArray(item), "treeify(): lItems[#{i}] is not an array"
		len = item.length
		assert len == 3, "treeify(): item has length #{len}"
		[level, lineNum, node] = item
		assert isInteger(level), "checkTree(): level not an integer"
		assert isInteger(lineNum), "checkTree(): lineNum not an integer"
		if predicate?
			assert predicate(node), "checkTree(): node fails predicate"
	return

# ---------------------------------------------------------------------------

hExtToEnvVar = {
	'.md':   'dir_markdown',
	'.taml': 'dir_data',
	'.txt':  'dir_data',
	}

# ---------------------------------------------------------------------------

export getFileContents = (fname, convert=false) ->

	debug "enter getFileContents('#{fname}')"
	if unitTesting
		debug "return from getFileContents() - unit testing"
		return "Contents of #{fname}"

	{root, dir, base, ext} = parse_fname(fname.trim())
	assert not root && not dir, "getFileContents():" \
		+ " root='#{root}', dir='#{dir}'" \
		+ " - full path not allowed"
	envvar = hExtToEnvVar[ext]
	debug "envvar = '#{envvar}'"
	assert envvar, "getFileContents() doesn't work for ext '#{ext}'"
	dir = process.env[envvar]
	debug "dir = '#{dir}'"
	assert dir, "env var '#{envvar}' not set for file extension '#{ext}'"
	fullpath = pathTo(base, dir)   # guarantees that file exists
	debug "fullpath = '#{fullpath}'"
	assert fullpath, "getFileContents(): Can't find file #{fname}"

	contents = slurp(fullpath)
	if not convert
		debug "return from getFileContents() - not converting"
		return contents
	switch ext
		when '.md'
			contents = markdownify(contents)
		when '.taml'
			contents = taml(contents)
		when '.txt'
			pass
		else
			croak "getFileContents(): No handler for ext '#{ext}'"
	debug "return from getFileContents()", contents
	return contents
