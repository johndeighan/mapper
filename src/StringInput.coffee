# StringInput.coffee

import {strict as assert} from 'assert'
import fs from 'fs'
import pathlib from 'path'

import {
	undef, say, pass, error, isString, isEmpty, isComment,
	deepCopy, stringToArray, unitTesting, oneline,
	} from '@jdeighan/coffee-utils'
import {slurp} from '@jdeighan/coffee-utils/fs'
import {splitLine, indented} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'
import {getFileContents, brewCoffee} from '@jdeighan/string-input/convert'

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
			error "getFromAlt(): There is no alt input"
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
			error "fetchFromAlt(): There is no alt input"
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
		`$: <varname> = <expr>;`

- converts
		<== <expr>
	to:
		`$: <expr>;`

- converts
		<===
			<code>
	to:
		```
		$: {
			<code>
			}
###

# ---------------------------------------------------------------------------
# --- export to allow unit testing

export class CoffeeMapper extends StringInput
	# - removes blank lines and comments
	# - converts <var> <== <expr> to `$: <var> = <expr>

	constructor: (content, hOptions) ->

		super content, hOptions

	mapLine: (orgLine) ->

		[level, line] = splitLine(orgLine)
		if isEmpty(line) || line.match(/^#\s/)
			return undef
		if lMatches = line.match(///^
				(?:
					([A-Za-z][A-Za-z0-9_]*)   # variable name
					\s*
					)?
				\< \= \=
				\s*
				(.*)
				$///)
			[_, varname, expr] = lMatches
			if expr
				# --- convert to JavaScript if not unit testing ---
				try
					jsExpr = brewCoffee(expr).trim()   # will have trailing ';'
				catch err
					error err.message

				if varname
					result = indented("\`\$\: #{varname} = #{jsExpr}\`", level)
				else
					result = indented("\`\$\: #{jsExpr}\`", level)
			else
				if varname
					error "Invalid syntax - variable name not allowed"
				code = @fetchBlock(level+1)
				try
					jsCode = brewCoffee(code)
				catch err
					error err.message

				result = """
						\`\`\`
						\$\: {
						#{indented(jsCode, 1)}
						#{indented('}', 1)}
						\`\`\`
						"""
			return indented(result, level)
		else
			return orgLine

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
				error "FileInput(): file '#{filename}' does not exist"
			content = slurp(filename)

		super content, hOptions

# ---------------------------------------------------------------------------
