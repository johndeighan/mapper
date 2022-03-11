# heredoc.coffee

import {
	assert, isString, undef, pass, croak, escapeStr, CWS,
	} from '@jdeighan/coffee-utils'
import {firstLine, remainingLines} from '@jdeighan/coffee-utils/block'
import {isTAML, taml} from '@jdeighan/string-input/taml'

lAllHereDocs = []
lAllHereDocNames = []
DEBUG = false

# ---------------------------------------------------------------------------

export doDebug = (flag=true) ->

	DEBUG = flag
	return

# ---------------------------------------------------------------------------

export lineToParts = (line) ->
	# --- Odd number of parts
	#     Each even index part is '<<<'

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

export mapHereDoc = (block) ->

	for heredoc,i in lAllHereDocs
		if heredoc.isMyHereDoc(block)
			if DEBUG
				console.log "--------------------------------------"
				console.log "HEREDOC type '#{lAllHereDocNames[i]}'"
				console.log "--------------------------------------"
				console.log block
				console.log "--------------------------------------"
			result = heredoc.map(block)
			assert isString(result), "mapHereDoc(): result not a string"
			return result

	croak "No valid heredoc type found"

# ---------------------------------------------------------------------------

export addHereDocType = (obj, name='Unknown') ->

	lAllHereDocs.unshift obj
	lAllHereDocNames.unshift name
	return

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------

export class BaseHereDoc

	isMyHereDoc: (block) ->
		return true

	# --- If the returned string will represent a string, then
	#     you can get away with just returning the represented string
	#     here, which will be surrounded with quote marks and
	#     have internal special characters escaped

	mapToString: (block) ->
		return block

	# --- map() MUST return a string
	#     that string will replace '<<<' in your code

	map: (block) ->
		return '"' + qesc(@mapToString(block)) + '"'

# ---------------------------------------------------------------------------

export class BlockHereDoc extends BaseHereDoc

	isMyHereDoc: (block) ->
		return firstLine(block) == '==='

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

# --- last one is checked first
addHereDocType new BaseHereDoc(),    'default block'
addHereDocType new FuncHereDoc(),    'function'         #  (args) ->
addHereDocType new OneLineHereDoc(), 'one line'         #  ...
addHereDocType new TAMLHereDoc(),    'taml'             #  ---
addHereDocType new BlockHereDoc(),   'explicit block'   #  ===
