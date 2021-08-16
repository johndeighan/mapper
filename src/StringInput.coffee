# StringInput.coffee

import {strict as assert} from 'assert'
import fs from 'fs'
import pathlib from 'path'
import {
	undef,
	deepCopy,
	stringToArray,
	say,
	pass,
	error,
	isString,
	unitTesting,
	} from '@jdeighan/coffee-utils'
import {slurp, findFile} from '@jdeighan/coffee-utils/fs'
import {
	splitLine,
	indentedStr,
	indentation,
	} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'

# ---------------------------------------------------------------------------
#   class StringInput - stream in lines from a string or array

export class StringInput

	constructor: (content, @hOptions={}) ->
		# --- Valid options:
		#        filename

		{filename} = @hOptions

		if isString(content)
			@lBuffer = stringToArray(content)
		else if isArray(content)
			# -- make a deep copy
			@lBuffer = deepCopy(content)
		else
			error "StringInput(): content must be array or string"
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

	# ........................................................................
	# --- designed to override with a mapping method

	mapLine: (line) -> return line

	# ........................................................................

	unget: (item) ->

		# --- item has already been mapped
		debug item, 'enter unget() with:'
		assert not @lookahead?
		@lookahead = item
		debug 'return from unget()'
		return

	# ........................................................................

	peek: () ->

		debug 'enter peek():'
		if @lookahead?
			debug "return lookahead token"
			return @lookahead
		item = @get()
		@unget(item)
		debug item, 'return with:'
		return item

	# ........................................................................

	skip: () ->

		debug 'enter skip():'
		if @lookahead?
			@lookahead = undef
			debug "return: clear lookahead token"
			return
		@get()
		debug 'return'
		return

	# ........................................................................
	# --- Returns undef if either:
	#        1. there's no alt input
	#        2. get from alt input returns undef (then closes alt input)

	getFromAlt: () ->

		debug "enter getFromAlt()"
		if not @altInput
			error "getFromAlt(): There is no alt input"
		result = @altInput.get()
		if result?
			debug result, "return with:"
			return indentedStr(result, @altLevel)
		else
			debug "return: alt returned undef, alt input removed"
			@altInput = undef
			@altLevel = undef
			return undef

	# ........................................................................
	# --- Returns undef if either:
	#        1. there's no alt input
	#        2. get from alt input returns undef (then closes alt input)

	fetchFromAlt: () ->

		debug "enter fetchFromAlt()"
		if not @altInput
			error "fetchFromAlt(): There is no alt input"
		result = @altInput.fetch()
		if result?
			debug result, "return with:"
			return indentedStr(result, @altLevel)
		else
			debug "return: alt returned undef, alt input removed"
			@altInput = undef
			@altLevel = undef
			return undef

	# ........................................................................

	get: () ->

		debug "enter get() (from #{@filename}):"
		if @lookahead?
			saved = @lookahead
			@lookahead = undef
			debug "return (from #{@filename}) with lookahead token"
			return saved

		if @altInput && (line = @getFromAlt())?
			debug "return with '#{line}' (from alt #{@filename})"
			return line

		line = @fetch()    # will handle #include
		debug line, "line ="

		if not line?
			debug "return with undef (from #{@filename}) at EOF"
			return undef

		result = @mapLine(line)
		while not result? && (@lBuffer.length > 0)
			line = @fetch()
			result = @mapLine(line)

		debug result, "return (from #{@filename})"
		return result

	# ........................................................................
	# --- This should be used to fetch from @lBuffer
	#     to maintain proper @lineNum for error messages
	#     MUST handle #include

	fetch: () ->

		debug "enter fetch()"
		if @altInput && (result = @fetchFromAlt())?
			debug result, "return with:"
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
				return indentation(level) + "Contents of #{fname}"
			fullpath = findFile(fname)
			contents = slurp(fullpath)
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

		debug line, "return from buffer:"
		return line

	# ........................................................................
	# --- Put one or more lines back into lBuffer, to be fetched later

	unfetch: (str) ->

		debug str, "enter unfetch() with:"
		@lBuffer.unshift(str)
		@lineNum -= 1
		debug 'return from unfetch()'
		return

	# ........................................................................
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
		while (line = @fetch())
			[level, str] = splitLine(line)
			debug "LOOP: level = #{level}, str = '#{str}'"
			if (level < atLevel)
				@unfetch(line)
				debug "RESULT: unfetch the line"
				break
			result = @mapLine(str)
			if result?
				result = indentedStr(result, level-atLevel)
				debug result, "RESULT from mapLine() was:"
				lLines.push result
			else
				debug "RESULT from mapLine() was undef"

		retval = lLines.join('\n')
		debug retval, "return with:"
		return retval

	# ........................................................................

	getAll: () ->

		lLines = []
		line = @get()
		while line?
			lLines.push(line)
			line = @get()
		return lLines

	# ........................................................................

	getAllText: () ->

		return @getAll().join('\n')

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
				error "FileInput(): file '#{filename}' does not exist"
			content = slurp(filename)

		super content, hOptions

# ---------------------------------------------------------------------------
