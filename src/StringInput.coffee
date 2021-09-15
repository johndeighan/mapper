# StringInput.coffee

import {strict as assert} from 'assert'
import fs from 'fs'
import pathlib from 'path'
import {dirname, resolve, parse as parse_fname} from 'path';

import {
	undef, pass, croak, isString, isEmpty, nonEmpty,
	isComment, isArray, isHash, isInteger, deepCopy,
	stringToArray, arrayToString, oneline, escapeStr,
	} from '@jdeighan/coffee-utils'
import {log} from '@jdeighan/coffee-utils/log'
import {slurp, pathTo} from '@jdeighan/coffee-utils/fs'
import {splitLine, indented, undented} from '@jdeighan/coffee-utils/indent'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {markdownify} from '@jdeighan/string-input/markdown'
import {isTAML, taml} from '@jdeighan/string-input/taml'

# ---------------------------------------------------------------------------
#   class StringFetcher - stream in lines from a string
#                         handles #include

export class StringFetcher

	constructor: (content, @hOptions={}) ->
		# --- Valid options:
		#        filename

		if isEmpty(content)
			@lBuffer = []
		else if isString(content)
			@lBuffer = stringToArray(content)
		else if isArray(content)
			# -- make a deep copy
			@lBuffer = deepCopy(content)
		else
			croak "StringFetcher(): content must be array or string",
					"CONTENT", content
		debug "in constructor: BUFFER", @lBuffer

		@lineNum = 0

		{filename} = @hOptions
		if filename
			try
				# --- We only want the bare filename
				{base} = pathlib.parse(filename)
				@filename = base
			catch
				@filename = filename
		else
			@filename = 'unit test'

		# --- for handling #include
		@altInput = undef
		@altPrefix = undef    # prefix prepended to lines from alt

	# ..........................................................

	fetch: () ->

		debug "enter fetch()"
		if @altInput
			assert @altPrefix?, "fetch(): alt intput without alt prefix"
			line = @altInput.fetch()
			if line?
				result = "#{@altPrefix}#{line}"
				debug "return '#{escapeStr(result)}' from fetch() - alt"
				return result
			else
				@altInput = undef    # it's exhausted

		if (@lBuffer.length == 0)
			debug "return undef from fetch() - empty buffer"
			return undef

		# --- @lBuffer is not empty here
		line = @lBuffer.shift()
		@lineNum += 1

		if lMatches = line.match(///^
				(\s*)
				\# include
				\s+
				(\S.*)
				$///)
			[_, prefix, fname] = lMatches
			debug "#include #{fname} with prefix '#{escapeStr(prefix)}'"
			assert not @altInput, "fetch(): altInput already set"
			contents = getFileContents(fname)
			@altInput = new StringFetcher(contents)
			@altPrefix = prefix
			debug "alt input created with prefix '#{escapeStr(prefix)}'"
			line = @altInput.fetch()
			if line?
				return "#{@altPrefix}#{line}"
			else
				return @fetch()    # recursive call
		else
			debug "return #{oneline(line)} from fetch()"
			return line

	# ..........................................................
	# --- Put a line back into lBuffer, to be fetched later

	unfetch: (line) ->

		debug "enter unfetch('#{escapeStr(line)}')"
		@lBuffer.unshift(line)
		@lineNum -= 1
		debug 'return from unfetch()'
		return

	# ..........................................................

	nextLine: () ->

		line = @fetch()
		@unfetch(line)
		return line

	# ..........................................................

	getPositionInfo: () ->

		if @altInput
			return @altInput.getPositionInfo()
		else
			return {
				file: @filename,
				lineNum: @lineNum,
				}

	# ..........................................................

	fetchAll: () ->

		lLines = []
		while (line = @fetch())?
			lLines.push line
		return lLines

	# ..........................................................

	fetchAllBlock: () ->

		lLines = @fetchAll()
		return arrayToString(lLines)

# ===========================================================================
#   class StringInput
#      - keep track of indentation
#      - allow mapping of lines, including skipping lines
#      - implement look ahead via peek()

export class StringInput extends StringFetcher

	constructor: (content, hOptions={}) ->
		# --- Valid options:
		#        filename

		super content, hOptions
		@lookahead = undef   # --- lookahead token, placed by unget

		# --- cache in case getAll() is called multiple times
		@lAllPairs = undef

	# ..........................................................

	unget: (pair) ->
		# --- pair will always be [<item>, <level>]
		#     <item> can be anything - i.e. it's been mapped

		debug 'enter unget() with', pair
		assert not @lookahead?, "unget(): there's already a lookahead"
		@lookahead = pair
		debug 'return from unget()'
		return

	# ..........................................................

	peek: () ->

		debug 'enter peek():'
		if @lookahead?
			debug "return lookahead from peek"
			return @lookahead
		pair = @get()
		if not pair?
			debug "return from peek() - undef"
			return undef
		@unget(pair)
		debug "return #{oneline(pair)} from peek"
		return pair

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

		assert line? && isString(line), "mapLine(): not a string"
		debug "in default mapLine('#{escapeStr(line)}', #{level})"
		return line

	# ..........................................................

	get: () ->

		debug "enter get() - src #{@filename}"
		if @lookahead?
			saved = @lookahead
			@lookahead = undef
			debug "return lookahead pair from get()"
			return saved

		line = @fetch()    # will handle #include
		debug "LINE", line

		if not line?
			debug "return from get() with undef at EOF"
			return undef

		[level, newline] = splitLine(line)
		result = @mapLine(newline, level)
		debug "MAP: '#{newline}' => #{oneline(result)}"

		# --- if mapLine() returns undef, we skip that line

		while not result? && (@lBuffer.length > 0)
			line = @fetch()
			[level, newline] = splitLine(line)
			result = @mapLine(newline, level)
			debug "MAP: '#{newline}' => #{oneline(result)}"

		if result?
			debug "return #{oneline(result)}, #{level} from get()"
			return [result, level]
		else
			debug "return undef from get()"
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
		if @lAllPairs?
			debug "return cached lAllPairs from getAll()"
			return @lAllPairs
		lPairs = []
		while (pair = @get())?
			lPairs.push(pair)
		@lAllPairs = lPairs
		debug "return #{lPairs.length} pairs from getAll()"
		return lPairs

	# ..........................................................

	getAllText: () ->

		lLines = for [line, level] in @getAll()
			indented(line, level)
		return arrayToString(lLines)

# ===========================================================================

export class SmartInput extends StringInput
	# - removes blank lines and comments (but can be overridden)
	# - joins continuation lines
	# - handles HEREDOCs

	constructor: (content, hOptions={}) ->
		# --- Valid options:
		#        filename

		super content, hOptions

		# --- This should only be used in mapLine(), where
		#     it keeps track of the level we're at, to be passed
		#     to handleEmptyLine() since the empty line itself
		#     is always at level 0
		@curLevel = 0

	# ..........................................................

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

	handleEmptyLine: (level) ->

		debug "in default handleEmptyLine()"
		return undef      # skip blank lines by default

	# ..........................................................

	handleComment: (line, level) ->

		debug "in default handleComment()"
		return undef      # skip comments by default

	# ..........................................................
	# --- designed to override with a mapping method
	#     NOTE: line includes the indentation

	mapLine: (line, level) ->

		debug "enter mapLine('#{escapeStr(line)}', #{level})"

		assert line?, "mapLine(): line is undef"
		assert isString(line), "mapLine(): #{oneline(line)} not a string"
		if isEmpty(line)
			debug "return undef from mapLine() - empty"
			return @handleEmptyLine(@curLevel)

		if isComment(line)
			debug "return undef from mapLine() - comment"
			return @handleComment(line, level)

		orgLineNum = @lineNum
		@curLevel = level

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
# ---------------------------------------------------------------------------
# --- To derive a class from this:
#        1. Extend this class
#        2. Override mapNode(), which gets the line with
#           any continuation lines appended, plus any
#           HEREDOC sections expanded
#        3. If desired, override handleHereDoc, which patches
#           HEREDOC lines into the original string

export class PLLParser extends SmartInput

	constructor: (content, hOptions={}) ->
		# --- Valid options:
		#        filename

		super content, hOptions

		# --- Cached tree, in case getTree() is called multiple times
		@tree = undef

	mapString: (line, level) ->

		result = @mapNode(line, level)
		if result?
			return [level, @lineNum, result]
		else
			# --- We need to skip over all following nodes
			#     at a higher level than this one
			@fetchBlock(level+1)
			return undef

	# ..........................................................

	mapNode: (line, level) ->

		return line

	# ..........................................................

	getAll: () ->

		# --- This returns a list of pairs, but
		#     we don't need the level anymore since it's
		#     also stored in the node

		lPairs = super()
		debug "lPairs", lPairs

		lItems = for pair in lPairs
			pair[0]
		debug "lItems", lItems
		return lItems

	# ..........................................................

	getTree: () ->

		debug "enter getTree()"
		if @tree?
			debug "return cached tree from getTree()"
			return @tree

		lItems = @getAll()

		assert lItems?, "lItems is undef"
		assert isArray(lItems), "getTree(): lItems is not an array"

		# --- treeify will consume its input, so we'll first
		#     make a deep copy
		tree = treeify(deepCopy(lItems))
		debug "TREE", tree

		@tree = tree
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
		[level, lineNum, node] = item

		if (level != atLevel)
			croak "treeify(): item at level #{level}, should be #{atLevel}",
					"TREE", lItems

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
