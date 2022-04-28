# LineFetcher.coffee

import fs from 'fs'

import {
	undef, assert, croak, OL, escapeStr,
	isEmpty, isFunction, isString, isArray,
	} from '@jdeighan/coffee-utils'
import {
	indented, undented, indentLevel,
	} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'
import {DEBUG, LOG} from '@jdeighan/coffee-utils/log'
import {
	blockToArray, arrayToBlock,
	} from '@jdeighan/coffee-utils/block'
import {
	slurp, parseSource, isSimpleFileName, isDir, pathTo,
	} from '@jdeighan/coffee-utils/fs'

import {Getter} from '@jdeighan/mapper/getter'

# ---------------------------------------------------------------------------
#   class LineFetcher - stream in lines from a string
#       handles:
#          __END__
#          #include

export class LineFetcher

	constructor: (source, content=undef) ->

		@setContent source, content

		# --- for handling #include
		@altInput = undef
		@altLevel = undef    # indentation added to lines from alt

	# ..........................................................

	setContent: (source, content) ->
		# --- source should be a file path or a URL
		#     content should be block or a generator
		#     if content is empty, it will be read in using source

		debug "enter setContent(source='#{source}')", content

		# --- @hSourceInfo has keys: dir, filename, stub, ext, fullpath
		#     source may be a URL, e.g. import.meta.url

		@hSourceInfo = parseSource(source)
		@filename = @hSourceInfo.filename
		assert @filename, "LineFetcher: parseSource returned no filename"
		if ! content?
			if @hSourceInfo.fullpath
				content = slurp(@hSourceInfo.fullpath)
				@getter = new Getter(blockToArray(content))
			else
				croak "LineFetcher(): no source or fullpath"
		else if isEmpty(content)
			@getter = new Getter([])
		else if isFunction(content)
			@getter = new Getter(content())  # content is a generator
		else if isString(content)
			@getter = new Getter(blockToArray(content))
		else if isArray(content)
			@getter = new Getter(content)
		else
			croak "LineFetcher(): content must be a string or array",
					"CONTENT", content

		@lineNum = 0
		debug "return from setContent()"
		return

	# ..........................................................

	get:   ()     -> return @getter.get()
	unget: (item) -> return @getter.unget(item)
	peek:  ()     -> return @getter.peek()
	eof:   ()     -> return @getter.eof()

	# ..........................................................

	getIncludeFileFullPath: (fname) ->

		debug "enter getIncludeFileFullPath('#{fname}')"

		# --- Make sure we have a simple file name
		assert isSimpleFileName(fname), \
				"getIncludeFileFullPath(): not a simple file name"

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
	# --- Can override to add additional functionality

	incLineNum: (inc) ->

		@lineNum += inc
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
				@incLineNum(1)
				debug "return #{OL(result)} from fetch() - alt"
				return result
			else
				# --- alternate input is exhausted
				@altInput = undef

		if (@eof())
			debug "return undef from fetch() - at EOF"
			return undef

		# --- Not at EOF
		line = @get()
		if line == '__END__'
			@getter.forceEOF()
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
			@altInput = new LineFetcher(fname, contents)
			@altLevel = indentLevel(prefix)
			debug "alt input created with prefix #{OL(prefix)}"
			line = @altInput.fetch()

			debug "first #include line found = '#{escapeStr(line)}'"

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
	# --- Put a line back, to be fetched later

	unfetch: (line) ->

		debug "enter unfetch(#{OL(line)})"
		assert isString(line), "unfetch(): not a string"
		if @altInput
			@altInput.unget undented(line, @altLevel)
		else
			@unget line
			@incLineNum(-1)
		debug 'return from unfetch()'
		return

	# ..........................................................

	getBlock: () ->

		debug "enter LineFetcher.getBlock()"
		lLines = while (line = @fetch())?
			assert isString(line), "getBlock(): got non-string '#{OL(line)}'"
			line
		block = arrayToBlock(lLines)
		debug "return from LineFetcher.getBlock()", block
		return block
