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
	debug,
	error,
	sep_dash,
	isString,
	unitTesting,
	} from '@jdeighan/coffee-utils'
import {slurp} from '@jdeighan/coffee-utils/fs'
import {
	splitLine,
	indentedStr,
	indentation,
	} from '@jdeighan/coffee-utils/indent'

# ---------------------------------------------------------------------------
#   class StringInput - stream in lines from a string or array

export class StringInput

	constructor: (content, @hOptions={}) ->
		# --- Valid options:
		#        filename
		#        prefix       # prepended to each defined retval from _mapped()
		#        hIncludePaths    { <ext>: <dir>, ... }

		{filename, prefix, hIncludePaths} = @hOptions

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

		@prefix = prefix || ''
		@hIncludePaths = @hOptions.hIncludePaths || {}
		if not unitTesting
			for own ext, dir of @hIncludePaths
				assert ext.indexOf('.') == 0, "invalid key in hIncludePaths"
				assert fs.existsSync(dir), "dir #{dir} does not exist"
		@lookahead = undef     # lookahead token, placed by unget
		@altInput = undef

	# ........................................................................

	mapLine: (line) ->

		return line

	# ........................................................................

	unget: (item) ->
		debug 'UNGET:'
		assert not @lookahead?
		debug item, "Lookahead:"
		@lookahead = item

	# ........................................................................

	peek: () ->
		debug 'PEEK:'
		if @lookahead?
			debug "   return lookahead token"
			return @lookahead
		item = @get()
		@unget(item)
		return item

	# ........................................................................

	skip: () ->
		debug 'SKIP:'
		if @lookahead?
			debug "   undef lookahead token"
			@lookahead = undef
			return
		@get()
		return

	# ........................................................................
	# --- returns [dir, base] if a valid #include

	checkForInclude: (str) ->

		assert not str.match(/^\s/), "checkForInclude(): string has indentation"
		if lMatches = str.match(///^
				\# include
				\s+
				(\S.*)
				$///)
			[_, fname] = lMatches
			filename = fname.trim()
			{root, dir, base, ext} = pathlib.parse(filename)
			if not root \
					&& not dir \
					&& @hIncludePaths \
					&& dir = @hIncludePaths[ext]
				assert base == filename, "base = #{base}, filename = #{filename}"

				# --- It's a plain file name with an extension
				#     that we can handle
				return [dir, base]
		return undef

	# ........................................................................
	# --- Returns undef if either:
	#        1. there's no alt input
	#        2. get from alt input returns undef (then closes alt input)

	getFromAlt: () ->
		if not @altInput
			return undef
		result = @altInput.get()
		if not result?
			debug "   alt input removed"
			@altInput = undef
		return result

	# ........................................................................

	get: () ->
		debug "GET (#{@filename}):"
		if @lookahead?
			debug "   RETURN (#{@filename}) lookahead token"
			save = @lookahead
			@lookahead = undef
			return save
		if line = @getFromAlt()
			debug "   RETURN (#{@filename}) '#{line}' from alt input"
			return line

		line = @fetch()
		if not line?
			debug "   RETURN (#{@filename}) undef - at EOF"
			return undef

		result = @_mapped(line)
		while not result? && (@lBuffer.length > 0)
			line = @fetch()
			result = @_mapped(line)
		debug "   RETURN (#{@filename}) '#{result}'"
		return result

	# ........................................................................

	_mapped: (line) ->

		assert isString(line), "Not a string: '#{line}'"
		debug "   _MAPPED: '#{line}'"
		assert not @lookahead?, "_mapped(): lookahead exists"
		if not line?
			return undef


		[level, str] = splitLine(line)
		if lResult = @checkForInclude(str)
			assert not @altInput, "get(): altInput already set"
			[dir, base] = lResult
			@altInput = new FileInput("#{dir}/#{base}", {
					prefix: indentation(level),
					hIncludePaths: @hIncludePaths,
					})
			debug "   alt input created"

			altLine = @getFromAlt()
			if altLine?
				debug "   _mapped(): line becomes '#{altLine}'"
				line = altLine
			else
				debug "   _mapped(): alt was undef, retain line '#{line}'"


		result = @mapLine(line)
		debug "      mapped to '#{result}'"

		if result?
			if isString(result)
				result = @prefix + result
			debug "      _mapped(): returning '#{result}'"
			return result
		else
			debug "      _mapped(): returning undef"
			return undef

	# ........................................................................
	# --- This should be used to fetch from @lBuffer
	#     to maintain proper @lineNum for error messages

	fetch: () ->
		if @lBuffer.length == 0
			return undef
		@lineNum += 1
		return @lBuffer.shift()

	# ........................................................................
	# --- Put one or more lines into lBuffer, to be fetched later
	#     TO DO: maintain correct line numbering!!!

	unfetch: (block) ->
		lLines = stringToArray(block)
		@lBuffer.unshift(lLines...)

	# ........................................................................
	# --- Fetch a block of text at level or greater than 'level'
	#     as one long string
	# --- Designed to use in mapLine()

	fetchBlock: (atLevel) ->

		lLines = []

		# --- NOTE: I absolutely hate using a backslash for line continuation
		#           but CoffeeScript doesn't continue while there is an
		#           open parenthesis like Python does :-(

		while (  (@lBuffer.length > 0) \
				&& ([level, str] = splitLine(@lBuffer[0])) \
				&& (level >= atLevel) \
				&& (line = @fetch()) \
				)
			if lResult = @checkForInclude(str)
				[dir, base] = lResult
				oInput = new FileInput("#{dir}/#{base}", {
						prefix: indentation(level),
						hIncludePaths: @hIncludePaths,
						})
				for line in oInput.getAll()
					lLines.push line
			else
				lLines.push indentedStr(str, level - atLevel)
		return lLines.join('\n')

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
