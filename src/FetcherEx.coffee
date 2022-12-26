# FetcherEx.coffee

import fs from 'fs'

import {assert, croak} from '@jdeighan/base-utils'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {
	undef, OL, defined, notdefined,
	isString, isInteger, isEmpty, nonEmpty,
	} from '@jdeighan/coffee-utils'
import {
	isSimpleFileName, isDir, pathTo,
	} from '@jdeighan/coffee-utils/fs'

import {Node} from '@jdeighan/mapper/node'
import {Fetcher} from '@jdeighan/mapper/fetcher'

# ---------------------------------------------------------------------------
#   class FetcherEx
#      - handles '#include'
#      - overrides fetch()
#      - overrides sourceInfoStr()

export class FetcherEx extends Fetcher

	constructor: (hInput, options={}) ->

		dbgEnter "FetcherEx", hInput, options
		super hInput, options
		@altInput = undef      # implements #include
		dbgReturn "FetcherEx"

	# ..........................................................
	# --- override to handle '#include'

	fetch: () ->

		dbgEnter "FetcherEx.fetch"

		# --- Check if data available from @altInput

		if defined(@altInput)
			dbg "has altInput"
			hNode = @altInput.fetch()

			# --- NOTE: hNode.str will never be #include
			#           because altInput's fetch would handle it

			if defined(hNode)
				# --- NOTE: altInput was created knowing how many levels
				#           to add due to indentation in #include statement
				assert hNode instanceof Node, "Not a Node: #{OL(hNode)}"
				dbg "from alt"
				dbgReturn "FetcherEx.fetch", hNode
				return hNode

			# --- alternate input is exhausted
			@altInput = undef
			dbg "alt EOF"
		else
			dbg "there is no altInput"

		hNode = super()      # call Fetcher.fetch()
		if notdefined(hNode)
			dbgReturn 'FetcherEx.fetch', undef
			return undef

		{str, level} = hNode

		# --- check for #include
		if lMatches = str.match(///^
				\#
				include \b
				\s*
				(.*)
				$///)
			[_, fname] = lMatches
			dbg "#include #{fname}"
			assert nonEmpty(fname), "missing file name in #include"
			@createAltInput fname, level
			hNode = @fetch()    # recursive call to this function
			dbgReturn "FetcherEx.fetch", hNode
			return hNode
		else
			dbg "no #include"

		dbgReturn "FetcherEx.fetch", hNode
		return hNode

	# ..........................................................

	createAltInput: (fname, level) ->

		dbgEnter "FetcherEx.createAltInput", fname, level

		# --- Make sure we have a simple file name
		assert isString(fname), "not a string: #{OL(fname)}"
		assert isSimpleFileName(fname),
				"not a simple file name: #{OL(fname)}"

		# --- Decide which directory to search for file
		dir = @hSourceInfo.dir
		if dir
			assert isDir(dir), "not a directory: #{OL(dir)}"
		else
			dir = process.cwd()  # --- Use current directory

		fullpath = pathTo(fname, dir)
		dbg "fullpath", fullpath
		if notdefined(fullpath)
			croak "Can't find include file #{fname} in dir #{dir}"
		assert fs.existsSync(fullpath), "#{fullpath} does not exist"

		@altInput = new FetcherEx({source: fullpath}, {addLevel: level})
		dbgReturn "FetcherEx.createAltInput"
		return

	# ..........................................................

	sourceInfoStr: (lineNum) ->

		dbgEnter 'FetcherEx.sourceInfoStr', lineNum
		if defined(lineNum)
			assert isInteger(lineNum), "Bad lineNum: #{OL(lineNum)}"
		else
			croak 'No lineNum given'

		lParts = []
		lParts.push "#{@hSourceInfo.filename}/#{lineNum}"
		if defined(@altInput)
			lParts.push @altInput.sourceInfoStr()
		else
			dbg "no altInput"
		result = lParts.join(' ')
		dbgReturn 'FetcherEx.sourceInfoStr', result
		return result
