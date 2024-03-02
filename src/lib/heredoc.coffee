# heredoc.coffee

import {
	undef, defined, notdefined, pass, escapeStr, OL, CWS, className,
	isString, isNonEmptyString, isHash, isEmpty, nonEmpty, isObject,
	toBlock,
	} from '@jdeighan/base-utils'
import {assert, croak} from '@jdeighan/base-utils/exceptions'
import {LOG} from '@jdeighan/base-utils/log'
import {
	dbg, dbgEnter, dbgReturn,
	} from '@jdeighan/base-utils/debug'
import {isTAML, fromTAML} from '@jdeighan/base-utils/taml'
import {
	firstLine, remainingLines, joinBlocks,
	} from '@jdeighan/coffee-utils/block'
import {indented, undented} from '@jdeighan/base-utils/indent'

import {Fetcher} from '@jdeighan/mapper/fetcher'

lHereDocs = []   # checked in this order - list of type names
hHereDocs = {}   # {type: obj}

# ---------------------------------------------------------------------------

export replaceHereDocs = (line, fetcher) =>

	dbgEnter "replaceHereDocs", line
	assert isString(line), "not a string"
	assert (fetcher instanceof Fetcher), "not a Fetcher"

	lParts = lineToParts(line)
	dbg 'lParts', lParts
	lNewParts = []    # to be joined to form new line
	for part in lParts
		if part == '<<<'
			dbg "get HEREDOC lines until blank line"

			lLines = []
			while defined(hNode = fetcher.fetch()) && ! hNode.isEmptyLine()
				lLines.push indented(hNode.str, hNode.level)

			block = undented(toBlock(lLines))
			dbg 'block', block

			str = mapHereDoc(block)
			assert isString(str), "Not a string: #{OL(str)}"
			dbg 'mapped block', str
			lNewParts.push str
		else
			lNewParts.push part    # keep as is

	result = lNewParts.join('')
	dbgReturn "replaceHereDocs", result
	return result

# ---------------------------------------------------------------------------

export lineToParts = (line) ->
	# --- Always returns an odd number of parts
	#     Odd numbered parts are '<<<', Even numbered parts are not '<<<'

	lParts = []
	pos = 0
	while ((start = line.indexOf('<<<', pos)) != -1)
		lParts.push line.substring(pos, start)
		lParts.push '<<<'
		pos = start + 3
	lParts.push line.substring(pos)
	return lParts

# ---------------------------------------------------------------------------
# Returns a CieloScript expression or undef

export mapHereDoc = (block) ->

	dbgEnter "mapHereDoc", block
	assert isString(block), "not a string: #{OL(block)}"
	for type in lHereDocs
		dbg "TRY #{type} HEREDOC"
		heredocObj = hHereDocs[type]
		result = heredocObj.mapToCielo(block)
		if defined(result)
			assert isString(result), "result not a string"
			dbg "   - FOUND #{type} HEREDOC"
			dbgReturn "mapHereDoc", result
			return result
		else
			dbg "   - NOT A #{type} HEREDOC"

	dbg "HEREDOC type 'default'"
	result = JSON.stringify(block)    # can directly replace <<<
	dbgReturn "mapHereDoc", result
	return result

# ---------------------------------------------------------------------------

export addHereDocType = (type, obj) ->

	dbgEnter "addHereDocType", type, obj
	assert isNonEmptyString(type), "type is #{OL(type)}"
	if ! isObject(obj, 'mapToCielo')
		[type, subtype] = jsType(obj)
		console.log "type = #{OL(type)}"
		console.log "subtype = #{OL(subtype)}"
	assert isObject(obj, 'mapToCielo'), "Bad input object: #{OL(obj)}"
	assert (obj instanceof BaseHereDoc), "not a BaseHereDoc"
	assert notdefined(hHereDocs[type]), "Heredoc type #{type} already installed"
	lHereDocs.push type
	hHereDocs[type] = obj
	dbgReturn "addHereDocType"
	return

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# --- To extend,
#        define mapToCielo(block) that:
#           returns undef if it's not your HEREDOC type
#           else returns a CieloScript expression

export class BaseHereDoc

	mapToCielo: (block) ->

		return undef

# ---------------------------------------------------------------------------

export class ExplicitBlockHereDoc extends BaseHereDoc
	# --- First line must be '==='
	#     Return value is quoted string of remaining lines

	mapToCielo: (block) ->

		if firstLine(block) != '==='
			return undef
		return JSON.stringify(remainingLines(block))

# ---------------------------------------------------------------------------

export class OneLineHereDoc extends BaseHereDoc
	# --- First line must begin with '...'
	#     Return value is single line string after '...' with
	#        runs of whitespace replaced with a single space char

	mapToCielo: (block) ->

		if (block.indexOf('...') != 0)
			return undef
		return JSON.stringify(block.substring(3).trim().replace(/\s+/gs, ' '))

# ---------------------------------------------------------------------------

export class TAMLHereDoc extends BaseHereDoc
	# --- First line must be '---'

	mapToCielo: (block) ->

		dbgEnter 'TAMLHereDoc.mapToCielo', block
		if firstLine(block) != '---'
			dbgReturn 'TAMLHereDoc.mapToCielo', undef
			return undef
		obj = fromTAML(block)
		result = JSON.stringify(obj)
		dbgReturn 'TAMLHereDoc.mapToCielo', result
		return result

# ---------------------------------------------------------------------------

# --- Add the standard HEREDOC types
addHereDocType 'one line', new OneLineHereDoc()
addHereDocType 'block', new ExplicitBlockHereDoc()
addHereDocType 'taml', new TAMLHereDoc()
