# StringInput.coffee

import fs from 'fs'
import pathlib from 'path'

import {
	assert, undef, pass, croak, isString, isEmpty, nonEmpty, escapeStr,
	isComment, isArray, isHash, isInteger, deepCopy, OL, CWS,
	} from '@jdeighan/coffee-utils'
import {
	blockToArray, arrayToBlock, firstLine, remainingLines,
	} from '@jdeighan/coffee-utils/block'
import {log} from '@jdeighan/coffee-utils/log'
import {
	slurp, pathTo, mydir, parseSource, mkpath,
	} from '@jdeighan/coffee-utils/fs'
import {
	splitLine, indented, undented, indentLevel,
	} from '@jdeighan/coffee-utils/indent'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'
import {hPrivEnv} from '@jdeighan/coffee-utils/privenv'
import {markdownify} from '@jdeighan/string-input/markdown'
import {isTAML, taml} from '@jdeighan/string-input/taml'
import {mapHereDoc} from '@jdeighan/string-input/heredoc'

# ---------------------------------------------------------------------------

# --- Default env vars for #include files
hExtToEnvVar = {
	'.md':   'DIR_MARKDOWN',
	'.taml': 'DIR_DATA',
	'.txt':  'DIR_DATA',
	}

# ---------------------------------------------------------------------------
#   class StringFetcher - stream in lines from a string
#                         handles #include

export class StringFetcher

	constructor: (content, source='unit test') ->

		# --- Has keys: dir, filename, stub, ext
		hSourceInfo = parseSource(source)

		filename = hSourceInfo.filename
		assert filename, "StringFetcher: parseSource returned no filename"
		@filename = filename
		@hSourceInfo = hSourceInfo

		if ! content?
			if hSourceInfo.fullpath
				content = slurp(hSourceInfo.fullpath)
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
			croak "StringFetcher(): content must be array or string",
					"CONTENT", content

		# --- patch {{FILE}} and {{LINE}}
		@lBuffer = for line,i in @lBuffer
			patch(patch(line, '{{FILE}}', @filename), '{{LINE}}', i+1)
		debug "in constructor: BUFFER", @lBuffer

		@lineNum = 0

		# --- for handling #include
		@altInput = undef
		@altLevel = undef    # indentation added to lines from alt

	# ..........................................................

	getIncludeFileDir: (ext) ->
		# --- override to not use defaults

		envvar = hExtToEnvVar[ext]
		if envvar?
			return hPrivEnv[envvar]
		else
			return undef

	# ..........................................................

	getIncludeFileFullPath: (filename) ->

		{root, dir, base, ext} = pathlib.parse(filename)
		assert ! dir, "getFileFullPath(): arg is not a simple file name"
		if @hSourceInfo.dir?
			path = mkpath(@hSourceInfo.dir, filename)
			if fs.existsSync(path)
				return path
		incDir = @getIncludeFileDir ext
		if incDir?
			assert fs.existsSync(incDir), "dir #{incDir} does not exist"
		path = mkpath(incDir, filename)
		if fs.existsSync(path)
			return path
		return undef

	# ..........................................................

	debugBuffer: () ->

		debug 'BUFFER', @lBuffer
		return

	# ..........................................................

	fetch: (literal=false) ->
		# --- literal = true means don't handle #include,
		#               just return it as is

		debug "enter fetch(literal=#{literal}) from #{@filename}"
		if @altInput
			assert @altLevel?, "fetch(): alt input without alt level"
			line = @altInput.fetch(literal)
			if line?
				result = indented(line, @altLevel)
				debug "return #{OL(result)} from fetch() - alt"
				return result
			else
				@altInput = undef    # it's exhausted

		if (@lBuffer.length == 0)
			debug "return undef from fetch() - empty buffer"
			return undef

		# --- @lBuffer is not empty here
		line = @lBuffer.shift()
		if line == '__END__'
			return undef
		@lineNum += 1

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
			@lineNum -= 1
		debug 'return from unfetch()'
		return

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
		return arrayToBlock(lLines)

# ===========================================================================
#   class StringInput
#      - keep track of indentation
#      - allow mapping of lines, including skipping lines
#      - implement look ahead via peek()

export class StringInput extends StringFetcher

	constructor: (content, source) ->
		super content, source
		@lookahead = undef   # --- lookahead token, placed by unget

		# --- cache in case getAll() is called multiple times
		#     each pair is [mapped str, level]
		@lAllPairs = undef

	# ..........................................................

	unget: (pair) ->
		# --- pair will always be [<item>, <level>]
		#     <item> can be anything - i.e. it's been mapped

		debug 'enter unget() with', pair
		assert ! @lookahead?, "unget(): there's already a lookahead"
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
		if ! pair?
			debug "return undef from peek()"
			return undef
		@unget(pair)
		debug "return #{OL(pair)} from peek"
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

		debug "enter StringInput.mapLine()"
		assert line? && isString(line), "StringInput.mapLine(): not a string"
		debug "return #{OL(line)}, #{level} from StringInput.mapLine()"
		return line

	# ..........................................................

	get: () ->

		debug "enter StringInput.get() - from #{@filename}"
		if @lookahead?
			saved = @lookahead
			@lookahead = undef
			debug "return lookahead pair from StringInput.get()"
			return saved

		line = @fetch()    # will handle #include
		debug "LINE", line

		if ! line?
			debug "return undef from StringInput.get() at EOF"
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
			debug "return [#{OL(result)}, #{level}] from StringInput.get()"
			return [result, level]
		else
			debug "return undef from StringInput.get()"
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
				"StringInput.fetchBlock(#{atLevel}) - not a string: #{line}"
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

		debug "enter StringInput.getAll()"
		if @lAllPairs?
			debug "return cached lAllPairs from StringInput.getAll()"
			return @lAllPairs
		lPairs = []
		while (pair = @get())?
			lPairs.push(pair)
		@lAllPairs = lPairs
		debug "lAllPairs", @lAllPairs
		debug "return #{lPairs.length} pairs from StringInput.getAll()"
		return lPairs

	# ..........................................................

	getAllText: () ->

		lLines = for [line, level] in @getAll()
			indented(line, level)
		return arrayToBlock(lLines)

# ===========================================================================

export class SmartInput extends StringInput
	# - removes blank lines and comments (but can be overridden)
	# - joins continuation lines
	# - handles HEREDOCs

	constructor: (content, source) ->
		super content, source

		# --- This should only be used in mapLine(), where
		#     it keeps track of the level we're at, to be passed
		#     to handleEmptyLine() since the empty line itself
		#     is always at level 0
		@curLevel = 0

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

		if isEmpty(lContLines)
			return line
		return line + ' ' + lContLines.join(' ')

	# ..........................................................

	handleEmptyLine: (level) ->

		debug "in SmartInput.handleEmptyLine()"
		return undef      # skip blank lines by default

	# ..........................................................

	handleComment: (line, level) ->

		debug "in SmartInput.handleComment()"
		return undef      # skip comments by default

	# ..........................................................
	# --- designed to override with a mapping method
	#     NOTE: line includes the indentation

	mapLine: (line, level) ->

		debug "enter SmartInput.mapLine(#{OL(line)}, #{level})"

		assert line?, "mapLine(): line is undef"
		assert isString(line), "mapLine(): #{OL(line)} not a string"
		if isEmpty(line)
			debug "return undef from SmartInput.mapLine() - empty"
			return @handleEmptyLine(@curLevel)

		if isComment(line)
			debug "return undef from SmartInput.mapLine() - comment"
			return @handleComment(line, level)

		orgLineNum = @lineNum
		@curLevel = level

		# --- Merge in any continuation lines
		debug "check for continuation lines"
		lContLines = @getContLines(level)
		if isEmpty(lContLines)
			debug "no continuation lines found"
		else
			debug "#{lContLines.length} continuation lines found"
			line = @joinContLines(line, lContLines)
			debug "line becomes #{OL(line)}"

		# --- handle HEREDOCs
		debug "check for HEREDOC"
		if (line.indexOf('<<<') != -1)
			line = @handleHereDoc(line, level)
			debug "line becomes #{OL(line)}"

		debug "mapping string"
		result = @mapString(line, level)
		debug "return #{OL(result)} from SmartInput.mapLine()"
		return result

	# ..........................................................

	mapString: (line, level) ->
		# --- NOTE: line has indentation removed
		#     when overriding, may return anything
		#     return undef to generate nothing

		assert isString(line),
				"default mapString(): #{OL(line)} is not a string"
		return line

	# ..........................................................

	handleHereDoc: (line, level) ->
		# --- Indentation is removed from line
		# --- Find each '<<<' and replace with result of mapHereDoc()

		assert isString(line), "handleHereDoc(): not a string"
		debug "enter handleHereDoc(#{OL(line)})"
		lParts = []     # joined at the end
		pos = 0
		while ((start = line.indexOf('<<<', pos)) != -1)
			part = line.substring(pos, start)
			debug "PUSH #{OL(part)}"
			lParts.push part
			lLines = @getHereDocLines(level+1)
			assert isArray(lLines), "handleHereDoc(): lLines not an array"
			debug "HEREDOC lines: #{OL(lLines)}"
			newstr = mapHereDoc(arrayToBlock(lLines))
			assert isString(newstr), "handleHereDoc(): newstr not a string"
			debug "PUSH #{OL(newstr)}"
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
		debug "PUSH #{OL(part)}"
		lParts.push part
		result = lParts.join('')
		debug "return from handleHereDoc", result
		return result

	# ..........................................................

	getHereDocLines: (atLevel) ->
		# --- Get all lines until addHereDocLine() returns undef
		#     atLevel will be one greater than the indent
		#        of the line containing <<<

		# --- NOTE: splitLine() removes trailing whitespace
		debug "enter SmartInput.getHereDocLines()"
		lLines = []
		while (line = @fetch())? \
				&& (newline = @hereDocLine(undented(line, atLevel)))?
			assert (indentLevel(line) >= atLevel),
				"invalid indentation in HEREDOC section"
			lLines.push newline
		assert isArray(lLines), "getHereDocLines(): retval not an array"
		debug "return from SmartInput.getHereDocLines()", lLines
		return lLines

	# ..........................................................

	hereDocLine: (line) ->

		if isEmpty(line)
			return undef        # end the HEREDOC section
		else if (line == '.')
			return ''           # interpret '.' as blank line
		else
			return line

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

	constructor: (content, source) ->
		super content, source

		# --- Cached tree, in case getTree() is called multiple times
		@tree = undef

	# ..........................................................

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
# Utility function to get a tree from text,
#    given a function to map a string (to anything!)

export treeFromBlock = (block, mapFunc) ->

	class MyPLLParser extends PLLParser

		mapNode: (line) ->
			assert isString(line), "MyPLLParser.mapNode(): not a string"
			return mapFunc(line)

	parser = new MyPLLParser(block)
	return parser.getTree()

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

patch = (str, substr, value) ->

	# --- Replace substr with value throughout str
	return str.replace(substr, value)

# ---------------------------------------------------------------------------

export getFileContents = (fname, convert=false, dir=undef) ->

	fname = fname.trim()
	debug "enter getFileContents('#{fname}')"

	assert isString(fname), "getFileContents(): fname not a string"
	{root, dir, base, ext} = pathlib.parse(fname)
	assert ! root && ! dir, "getFileContents():" \
		+ " root='#{root}', dir='#{dir}'" \
		+ " - full path not allowed"

	if dir
		path = mkpath(dir, fname)
		if fs.existsSync(path)
			return slurp(path)

	envvar = hExtToEnvVar[ext]
	debug "envvar = '#{envvar}'"
	assert envvar, "getFileContents() doesn't work for ext '#{ext}'"

	dir = hPrivEnv[envvar]
	debug "dir = '#{dir}'"
	if ! dir?
		croak "env var '#{envvar}' not set for file extension '#{ext}'",
			'hPrivEnv', hPrivEnv
	fullpath = pathTo(base, dir)   # guarantees that file exists
	debug "fullpath = '#{fullpath}'"
	assert fullpath, "getFileContents(): Can't find file #{fname}"

	contents = slurp(fullpath)
	if ! convert
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
