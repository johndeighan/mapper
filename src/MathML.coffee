# MathML.coffee

import {assert, error, croak} from '@jdeighan/unit-tester/utils'
import {
	undef, pass, isEmpty, isArray, isNumber, isString, escapeStr, OL,
	} from '@jdeighan/coffee-utils'
import {
	isSimpleFileName, fileExt, isFile, isDir, slurp, pathTo,
	} from '@jdeighan/coffee-utils/fs'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug} from '@jdeighan/coffee-utils/debug'

import {TreeWalker} from '@jdeighan/mapper/tree'

# --- commands, with allowed # of args, allowed # of children
hCommands = {
	expr:  [ undef,  undef]
	group: [ [0,2],  undef]
	svg:   [   1,    0]
	sub:   [   0,    2]
	sup:   [   0,    2]
	frac:  [   0,    2]
	SIGMA: [ [0,1],  [2,undef]]
	}
export isCommand = (str) -> hCommands[str]?

# ---------------------------------------------------------------------------

export mapMath = (line) ->

	debug "enter mapMath('#{escapeStr(line)}')"
	if isEmpty(line)
		debug "return undef from mapMath() - empty string"
		return undef

	# --- These should not be needed
	assert line.indexOf("\n")==-1, "mapper(): line contains newline char"
	assert line.indexOf("\r")==-1, "mapper(): line contains return char"

	lWords = line.split(/\s+/)    # split on whitespace
	assert lWords?, "lWords is not defined!"
	assert lWords.length > 0, "lWords is empty!"

	if isCommand(lWords[0])
		cmd = lWords[0]
		debug "Command '#{cmd}' found"
		hNode = getNode(cmd, lWords.slice(1))
	else
		debug "expression found"
		hNode = getNode('expr', lWords)

	debug "return from mapMath()", hNode
	return hNode

# ---------------------------------------------------------------------------

getNode = (cmd, lArgs) ->
	# --- Converts lArgs to array of atoms lAtoms
	#     If no args, don't include key lAtoms
	#     except that the 'group' command automatically supplies default atoms

	debug "enter getNode('#{cmd}', lArgs", lArgs
	assert isCommand(cmd), "getNode(): Not a command: '#{cmd}'"
	assert isArray(lArgs), "getNode(): lArgs not an array"

	nArgs = lArgs.length
	if cmd == 'group'
		# --- if cmd 'group', fill in missing values with default values
		assert (nArgs <= 2), "Invalid 'group', #{nArgs} args"
		[left, right] = lArgs

		if !left
			left = '('
		if !right
			right = matching(left)
		lArgs = [left, right]
		debug 'lArgs', lArgs
	else if cmd == 'SIGMA'
		assert (nArgs <= 1), "Invalid 'SIGMA', #{nArgs} args"
		if (lArgs.length == 0)
			lArgs = ['&#x03A3;']
		debug 'lArgs', lArgs

	if lArgs.length == 0
		hNode = {cmd}
	else
		hNode = {
			cmd
			lAtoms: atomList(lArgs)
			}

	checkArgs cmd, hNode.lAtoms
	debug "return from getNode()", hNode
	return hNode

# ---------------------------------------------------------------------------

checkArgs = (cmd, lAtoms) ->

	assert isCommand(cmd), "Not a command: '#{cmd}'"
	if lAtoms?
		assert isArray(lAtoms), "checkArgs(): lAtoms not an array"
		nAtoms = lAtoms.length
	else
		nAtoms = 0

	check = hCommands[cmd][0]
	if isNumber(check)
		assert nAtoms==check, \
				"cmd #{cmd} has #{nAtoms} args, should be #{check}"
	else if isArray(check)
		[min, max] = check
		if min?
			assert nAtoms >= min, \
					"cmd #{cmd} has #{nAtoms} args, min = #{min}"
		if max?
			assert nAtoms <= max, \
					"cmd #{cmd} has #{nAtoms} args, max = #{max}"
	return

# ---------------------------------------------------------------------------

atom = (str) ->

	assert isString(str), "atom(): not a string"
	if isIntegerStr(str)
		return {
			type: 'number'
			value: str
			}
	else if isIdentifier(str)
		return {
			type: 'ident'
			value: str
			}
	else
		return {
			type: 'op'
			value: str
			}

# ---------------------------------------------------------------------------

atomList = (lItems) ->

	if !lItems? || (lItems.length==0) then return undef
	lAtoms = for str,i in lItems
		assert isString(str), "atomList(): not a string: #{OL(str)} at #{i}"
		atom(str)
	return lAtoms

# ---------------------------------------------------------------------------

matching = (bracket) ->
	assert bracket?, "matching(): bracket is not defined"
	switch bracket
		when '(' then return ')'
		when '[' then return ']'
		when '{' then return '}'
		else
			return bracket

# ===========================================================================

export class MathTreeWalker extends TreeWalker
	# --- The @dir parameter is required if you use svg

	constructor: (tree, @dir=undef) ->
		super tree
		@mathml = ''

	visit: (superNode) ->
		debug "enter visit()"
		node = superNode.node
		switch node.cmd
			when 'expr'
				debug "cmd: #{node.cmd}"
				@mathml += "<mrow>"
				for atom in node.lAtoms
					switch atom.type
						when 'number'
							@mathml += "<mn>#{atom.value}</mn>"
						when 'ident'
							@mathml += "<mi>#{atom.value}</mi>"
						when 'op'
							@mathml += "<mo>#{atom.value}</mo>"
			when 'svg'
				debug "cmd: #{node.cmd}"
				left = node.lAtoms[0]
				right = node.lAtoms[1]
				@mathml += "<semantics><annotation-xml encoding='SVG1.1'>\n"
				@mathml += getSVG(left, @dir)
				@mathml += "\n</annotation-xml></semantics>\n"
			when 'group'
				debug "cmd: #{node.cmd}"
				@mathml += "<mrow>"
				@mathml += node.lAtoms[0].value
			when 'sub'
				debug "cmd: #{node.cmd}"
				@mathml += "<msub>"
			when 'SIGMA'
				debug "cmd: #{node.cmd}"
				@mathml += "<munderover>"
				@mathml += "<mo class='large'> &#x03A3; </mo>"
			else
				croak "visit(): Not a command: '#{node.cmd}'"
		debug "return from visit()"
		return

	endVisit: (superNode) ->
		debug "enter endVisit()"
		node = superNode.node
		switch node.cmd
			when 'expr'
				debug "cmd: #{node.cmd}"
				@mathml += "</mrow>"
			when 'group'
				debug "cmd: #{node.cmd}"
				@mathml += node.lAtoms[1].value
				@mathml += "</mrow>"
			when 'sub'
				debug "cmd: #{node.cmd}"
				@mathml += "</msub>"
			when 'SIGMA'
				debug "cmd: #{node.cmd}"
				@mathml += "</munderover>"
			when 'svg'
				pass
			else
				croak "endVisit(): Not a command: '#{node.cmd}'"
		debug "return from endVisit()"
		return

	getMathML: () ->

		debug "CALL getMathML()"
		return @mathml

# ---------------------------------------------------------------------------

getSVG = (fname, dir) ->

	assert dir && isDir(dir), "getSVG(): No search dir set"
	debug "getSVG(): fname: #{fname}"
	assert isSimpleFileName(fname),\
			"getSVG(): svg file should be simple file name"
	assert fileExt(fname)=='.svg', "getSVG(): svg file should end with .svg"
	assert isFile(fname),\
		"getSVG(): file '#{fname}' does not exist or is not a file"
	fullpath = pathTo(fname, dir)
	debug "getSVG(): fullpath: '#{fullpath}'"
	contents = slurp(fullpath)
	return """
			<semantics><annotation-xml encoding='SVG1.1'>
	     	#{contents}
	     	</annotation-xml></semantics>
	     	"""

# ===========================================================================
#   Utilities
# ===========================================================================

isIntegerStr = (str) ->

	assert isString(str), "isIntegerStr(): not a string"
	if lMatches = str.match(///^ \d+ (.*) $///)
		[_, tail] = lMatches
		assert !tail || tail.length==0, "Invalid number"
		return true
	else
		return false

# ---------------------------------------------------------------------------

isIdentifier = (str) ->

	assert isString(str), "isIdentifier(): not a string"
	if lMatches = str.match(///^ [A-Za-z_] [A-Za-z0-9_]* (.*) $///)
		[_, tail] = lMatches
		assert !tail, "Invalid identifier"
		return true
	else
		return false

# ---------------------------------------------------------------------------
