# heredoc.coffee

import {
	undef, pass, croak, escapeStr, CWS,
	} from '@jdeighan/coffee-utils'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'
import {isTAML, taml} from '@jdeighan/string-input/taml'

lAllHereDocs = []

# ---------------------------------------------------------------------------

export mapHereDoc = (block) ->

	for heredoc in lAllHereDocs
		if heredoc.isMyHereDoc(block)
			return heredoc.map(block)
	croak "No valid heredoc type found"

# ---------------------------------------------------------------------------

export addHereDocType = (obj) ->

	lAllHereDocs.unshift obj
	return

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export class BaseHereDoc

	isMyHereDoc: (block) ->
		return true

	mapToString: (block) ->
		return block

	# --- Return a string that JavaScript will interpret as a value
	map: (block) ->
		return '"' + qesc(@mapToString(block)) + '"'

# ---------------------------------------------------------------------------

export class BlockHereDoc extends BaseHereDoc

	isMyHereDoc: (block) ->
		return firstLine(block) == '$$$'

	mapToString: (block) ->
		return remainingLines(block)

# ---------------------------------------------------------------------------

export class OneLineHereDoc extends BaseHereDoc

	isMyHereDoc: (block) ->
		return block.indexOf('...') == 0

	mapToString: (block) ->
		# --- replace all runs of whitespace with single space char
		block = block.replace(/\s+/gs, ' ')
		return block.substring(3).trim()

# ---------------------------------------------------------------------------

export class TAMLHereDoc extends BaseHereDoc

	isMyHereDoc: (block) ->
		return isTAML(block)

	map: (block) ->
		return JSON.stringify(taml(block))

# ---------------------------------------------------------------------------

export isFunctionHeader = (str) ->

	return str.match(///^
			(?:
				([A-Za-z_][A-Za-z0-9_]*)  # optional function name
				\s*
				=
				\s*
				)?
			\(
			\s*
			(                            # optional parameters
				[A-Za-z_][A-Za-z0-9_]*
				(?:
					,
					\s*
					[A-Za-z_][A-Za-z0-9_]*
					)*
				)?
			\)
			\s*
			->
			\s*
			$///)

export class FuncHereDoc extends BaseHereDoc

	isMyHereDoc: (block) ->
		return isFunctionHeader(firstLine(block))

	map: (block, lMatches=undef) ->
		# --- caller should pass return value from isMyHereDoc here
		#     but if not, we'll just call it again
		if ! lMatches
			lMatches = @isMyHereDoc(block)
		block = remainingLines(block)
		[_, funcName, strParms] = lMatches
		if ! strParms
			strParms = ''
		if funcName
			return CWS("#{funcName} = (#{strParms}) -> #{block}")
		else
			return CWS("(#{strParms}) -> #{block}")

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

lAllHereDocs.push new BlockHereDoc()
lAllHereDocs.push new TAMLHereDoc()
lAllHereDocs.push new OneLineHereDoc()
lAllHereDocs.push new FuncHereDoc()
lAllHereDocs.push new BaseHereDoc()
