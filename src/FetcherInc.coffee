# FetcherInc.coffee

import fs from 'fs'

import {
	undef, OL, defined, notdefined,
	isString, isInteger, isEmpty, nonEmpty,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {
	isSimpleFileName, isDir, pathTo,
	} from '@jdeighan/coffee-utils/fs'

import {Node} from '@jdeighan/mapper/node'
import {Fetcher} from '@jdeighan/mapper/fetcher'

# ---------------------------------------------------------------------------
# 1. handle '#include' - implemented using @altInput, overriding fetch()

export class FetcherInc extends Fetcher

	constructor: (hInput, options={}) ->

		dbgEnter "FetcherInc", hInput, options
		super hInput, options
		@altInput = undef      # implements #include
		dbgReturn "FetcherInc"

	# ..........................................................
	# --- override to handle '#include'

	fetch: () ->

		dbgEnter "FetcherInc.fetch"

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
				dbg "from alt, update source"

				# --- Update 'source'
				{filename} = @hSourceInfo
				hNode.source = "#{filename}/#{@includeLineNum} #{hNode.source}"

				dbgReturn "FetcherInc.fetch", hNode
				return hNode

			# --- alternate input is exhausted
			@altInput = undef
			dbg "alt EOF"
		else
			dbg "there is no altInput"

		# --- If we find a #include, this is the line it's on
		saveLineNum = @lineNum

		hNode = super()      # call Fetcher.fetch()
		if notdefined(hNode)
			dbgReturn 'FetcherInc.fetch', undef
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
			@includeLineNum = saveLineNum
			dbg "#include #{fname}"
			assert nonEmpty(fname), "missing file name in #include"
			@createAltInput fname, level
			hNode = @fetch()    # recursive call to this function
			dbgReturn "FetcherInc.fetch", hNode
			return hNode
		else
			dbg "no #include"

		dbgReturn "FetcherInc.fetch", hNode
		return hNode

	# ..........................................................

	createAltInput: (fname, level) ->

		dbgEnter "FetcherInc.createAltInput", fname, level

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

		@altInput = new FetcherInc({source: fullpath}, {addLevel: level})
		dbgReturn "FetcherInc.createAltInput"
		return
