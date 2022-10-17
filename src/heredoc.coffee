# heredoc.coffee

import {
	LOG, debug, assert, croak, isTAML, fromTAML,
	} from '@jdeighan/exceptions'
import {
	undef, defined, notdefined, pass,
	isString, isHash, isEmpty, nonEmpty,
	escapeStr, CWS, OL, className,
	} from '@jdeighan/coffee-utils'
import {
	firstLine, remainingLines, joinBlocks,
	} from '@jdeighan/coffee-utils/block'
import {indented} from '@jdeighan/coffee-utils/indent'

lHereDocs = []   # checked in this order - list of type names
hHereDocs = {}   # {type: obj}

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
# ---------------------------------------------------------------------------
# --- To extend,
#        define map(block) that:
#           returns undef if it's not your HEREDOC type
#           else returns a CieloScript expression

export class BaseHereDoc

	map: (block) ->

		return undef

# ---------------------------------------------------------------------------
# Returns a CieloScript expression or undef

export mapHereDoc = (block) ->

	debug "enter mapHereDoc()", block
	assert isString(block), "not a string"
	for type in lHereDocs
		debug "CHECK FOR #{type} HEREDOC"
		heredoc = hHereDocs[type]
		if defined(str = heredoc.map(block))
			debug "   - FOUND #{type} HEREDOC"
			debug "return from mapHereDoc()", str
			return str
		else
			debug "   - NOT A #{type} HEREDOC"

	debug "HEREDOC type 'default'"
	result = JSON.stringify(block)    # can directly replace <<<
	debug "return from mapHereDoc()", result
	return result

# ---------------------------------------------------------------------------

export isHereDocType = (type) ->

	return defined(hHereDocs[type])

# ---------------------------------------------------------------------------

export addHereDocType = (type, inputClass) ->

	assert inputClass?, "Missing input class"
	name = className(inputClass)
	debug "enter addHereDocType()", type, name
	if defined(hHereDocs[type])
		# --- Already installed, but OK if it's the same class
		installed = className(hHereDocs[type])
		if (installed != name)
			croak "type #{OL(type)}: add #{name}, installed is #{installed}"
		debug "return from addHereDocType() - already installed"
		return

	oHereDoc = new inputClass()
	assert oHereDoc instanceof BaseHereDoc,
		"addHereDocType() requires a BaseHereDoc subclass"

	lHereDocs.push type
	hHereDocs[type]  = oHereDoc
	debug "return from addHereDocType()"
	return

# ---------------------------------------------------------------------------

export class ExplicitBlockHereDoc extends BaseHereDoc

	map: (block) ->

		if firstLine(block) != '==='
			return undef
		return JSON.stringify(remainingLines(block))

# ---------------------------------------------------------------------------

export class OneLineHereDoc extends BaseHereDoc

	map: (block) ->

		if (block.indexOf('...') != 0)
			return undef
		return JSON.stringify(block.substring(3).trim().replace(/\s+/gs, ' '))

# ---------------------------------------------------------------------------

export class TAMLHereDoc extends BaseHereDoc

	map: (block) ->

		if ! isTAML(block)
			return undef
		result = fromTAML(block)
		return JSON.stringify(result)

# ---------------------------------------------------------------------------

export class FuncHereDoc extends BaseHereDoc

	map: (block) ->
		if ! @isFunctionDef(block)
			return undef
		return block

	# ........................................................................

	isFunctionDef: (block) ->

		debug "enter isFunctionDef()", block
		lMatches = block.match(///^
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
				\s*
				\)
				\s*
				->
				[\ \t]*
				\n?
				(.*)
				$///s)
		if lMatches
			# --- HERE, we should check if it compiles
			[_, strParms, strBody] = lMatches

			debug "return from isFunctionDef - OK"
			return true
		else
			debug "return from isFunctionDef - no match"
			return false

# ---------------------------------------------------------------------------

# --- Add the standard HEREDOC types
addHereDocType 'one line', OneLineHereDoc
addHereDocType 'block', ExplicitBlockHereDoc
addHereDocType 'taml', TAMLHereDoc
addHereDocType 'func', FuncHereDoc
