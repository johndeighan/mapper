# heredoc.coffee

import {
	assert, isString, isHash, isEmpty, nonEmpty,
	undef, pass, croak, escapeStr, CWS,
	} from '@jdeighan/coffee-utils'
import {
	firstLine, remainingLines, joinBlocks,
	} from '@jdeighan/coffee-utils/block'
import {indented} from '@jdeighan/coffee-utils/indent'
import {debug} from '@jdeighan/coffee-utils/debug'
import {LOG} from '@jdeighan/coffee-utils/log'

lAllHereDocs = []
lAllHereDocNames = []
export debugHereDoc = false

# ---------------------------------------------------------------------------

export doDebugHereDoc = (flag=true) ->

	debugHereDoc = flag
	return

# ---------------------------------------------------------------------------

export lineToParts = (line) ->

	lParts = []     # joined at the end
	pos = 0
	while ((start = line.indexOf('<<<', pos)) != -1)
		if (start > pos)
			lParts.push line.substring(pos, start)
		lParts.push '<<<'
		pos = start + 3
	if (line.length > pos)
		lParts.push line.substring(pos)
	return lParts

# ---------------------------------------------------------------------------
# Returns a hash with keys:
#    str - replacement string
#    obj - any kind of object, number, string, etc.
#    type - typeof obj

export mapHereDoc = (block) ->

	debug "enter mapHereDoc()"
	assert isString(block), "mapHereDoc(): not a string"
	for heredoc,i in lAllHereDocs
		name = heredoc.myName()
		debug "TRY #{name} HEREDOC"
		if result = heredoc.isMyHereDoc(block)
			debug "found #{name} HEREDOC"
			if debugHereDoc
				console.log "--------------------------------------"
				console.log "HEREDOC type '#{name}'"
				console.log "--------------------------------------"
				console.log block
				console.log "--------------------------------------"
			result = heredoc.map(block, result)
			result.type = typeof result.obj
			debug "return from mapHereDoc()", result
			return result
		else
			if debugHereDoc
				LOG "NOT A #{name} HEREDOC"
	result = {
		str: JSON.stringify(block) # can directly replace <<<
		obj: block
		type: typeof block
		}
	debug "return from mapHereDoc()"
	return result

# ---------------------------------------------------------------------------

export addHereDocType = (obj) ->

	name = obj.myName()
	if name not in lAllHereDocNames
		lAllHereDocNames.unshift name
		lAllHereDocs.unshift obj
	return

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export class BlockHereDoc

	myName: () ->
		return 'explicit block'

	isMyHereDoc: (block) ->
		return firstLine(block) == '==='

	map: (block) ->
		block = remainingLines(block)
		return {
			str: JSON.stringify(block) # can directly replace <<<
			obj: block
			}

# ---------------------------------------------------------------------------

export class OneLineHereDoc

	myName: () ->
		return 'one line'

	isMyHereDoc: (block) ->
		return block.indexOf('...') == 0

	map: (block) ->
		# --- replace all runs of whitespace with single space char
		block = block.substring(3).trim().replace(/\s+/gs, ' ')
		return {
			str: JSON.stringify(block) # can directly replace <<<
			obj: block
			}

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

qesc = (block) ->

	hEsc = {
		"\n": "\\n"
		"\r": ""
		"\t": "\\t"
		"\"": "\\\""
		}
	return escapeStr(block, hEsc)

# ---------------------------------------------------------------------------

# --- last one is checked first
addHereDocType new OneLineHereDoc()   #  ...
addHereDocType new BlockHereDoc()     #  ===
