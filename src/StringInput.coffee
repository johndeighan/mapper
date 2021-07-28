# StringInput.coffee

import fs from 'fs'
import {
	undef,
	deepCopy,
	stringToArray,
	say,
	debug,
	sep_dash,
	} from '@jdeighan/coffee-utils'
import {splitLine, indentedStr} from '@jdeighan/coffee-utils/indent'

# ---------------------------------------------------------------------------
#   class StringInput - stream in lines from a string or array

export class StringInput

	constructor: (
			content,
			@filename='unit test',
			@mapper=null) ->
		if typeof content == 'object'
			# -- make a deep copy
			@lBuffer = deepCopy(content)
		else
			@lBuffer = stringToArray(content)
		@lineNum = 0

		@lookahead = undef     # lookahead token

	eof: () ->
		return not @peek()?

	peek: () ->
		if @lookahead?
			debug "   return lookahead token"
			return @lookahead
		if (@lBuffer.length == 0)
			debug "   return undef - at EOF"
			return undef
		line = @fetch()
		result = @_mapped(line)
		while not result? && (@lBuffer.length > 0)
			line = @fetch()
			result = @_mapped(line)
		debug "   return '#{result}'"
		@lookahead = result
		return result

	skip: () ->
		debug 'SKIP:'
		if @lookahead?
			debug "   undef lookahead token"
			@lookahead = undef
			return
		if (@lBuffer.length == 0)
			debug "   return - at EOF"
			return
		line = @fetch()
		result = @_mapped(line)
		while not result? && (@lBuffer.length > 0)
			line = @fetch()
			result = @_mapped(line)
		debug "   return"
		return

	get: () ->
		debug 'GET:'
		if @lookahead?
			debug "   return lookahead token"
			save = @lookahead
			@lookahead = undef
			return save
		if (@lBuffer.length == 0)
			debug "   return undef - at EOF"
			return undef
		line = @fetch()
		result = @_mapped(line)
		while not result? && (@lBuffer.length > 0)
			line = @fetch()
			result = @_mapped(line)
		debug "   return '#{result}'"
		return result

	_mapped: (line) ->
		debug "   _MAPPED: '#{line}'"
		console.assert not @lookahead?

		if not @mapper
			debug "      no mapper - returning '#{line}'"
			return line

		result = @mapper(line, this)
		debug "      mapped to '#{result}'"
		return result

	# --- This should be used to fetch from @lBuffer
	#     to maintain proper @lineNum for error messages
	fetch: () ->
		if @lBuffer.length == 0
			return undef
		@lineNum += 1
		return @lBuffer.shift()

	# --- Put one or more lines into lBuffer, to be fetched later
	#     TO DO: maintain correct line numbering!!!
	unfetch: (block) ->
		lLines = stringToArray(block)
		@lBuffer.unshift(lLines...)

	# --- Fetch a block of text at level or greater than 'level'
	#     as one long string
	# --- Designed to use in a mapper

	fetchBlock: (atLevel) ->

		block = ''

		# --- NOTE: I absolutely hate using a backslash for line continuation
		#           but CoffeeScript doesn't continue while there is an
		#           open parenthesis like Python does :-(

		while (  (@lBuffer.length > 0) \
				&& ([level, str] = splitLine(@lBuffer[0])) \
				&& (level >= atLevel) \
				&& (line = @fetch()) \
				)
			block += line + '\n'
		return block

# ---------------------------------------------------------------------------
#   class FileInput - contents from a file

export class FileInput extends StringInput

	constructor: (filepath, mapper=null) ->
		if not fs.existsSync(filepath)
			throw new Error("FileInput(): file '#{filepath}' does not exist")
		content = fs.readFileSync(filepath).toString()
		super content, filepath, mapper

# ---------------------------------------------------------------------------
#   utility func for processing content using a mapper

export procContent = (content, mapper) ->

	debug sep_dash
	debug content, "CONTENT (before proc):"
	debug sep_dash

	oInput = new StringInput(content, 'proc', mapper)
	lLines = []
	while not oInput.eof()
		lLines.push oInput.get()
	if lLines.length == 0
		result = ''
	else
		result = lLines.join('\n') + '\n'

	debug sep_dash
	debug result, "CONTENT (after proc):"
	debug sep_dash

	return result

# ---------------------------------------------------------------------------
#    1. Skips blank lines and comments
#    2. returns { level, line, lineNum }

export SimpleMapper = (line, oInput) ->

	# --- line has indentation stripped off
	[level, line] = splitLine(line)

	if (line == '') || line.match(/^#\s/)
		return undef     # skip comments and blank lines

	lineNum = oInput.lineNum   # save line number
	return { level, line, lineNum }
