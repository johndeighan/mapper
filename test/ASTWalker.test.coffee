# ASTWalker.test.coffee

import {defined, nonEmpty, toBlock, OL} from '@jdeighan/base-utils'
import {
	LOG, LOGVALUE, clearMyLogs, getMyLog, dumpLog,
	} from '@jdeighan/base-utils/log'
import {
	setDebugging, getDebugLog,
	} from '@jdeighan/base-utils/debug'
import {slurp} from '@jdeighan/base-utils/fs'
import {utest, UnitTester} from '@jdeighan/unit-tester'
import {indented} from '@jdeighan/coffee-utils/indent'
import {projRoot} from '@jdeighan/coffee-utils/fs'

import {ASTWalker} from '@jdeighan/mapper/ast'

rootDir = projRoot import.meta.url

# ---------------------------------------------------------------------------

class ASTTester extends UnitTester

	transformValue: (coffeeCode) ->

		walker = new ASTWalker(coffeeCode)
		result = walker.walk('asText')
		return result

tester = new ASTTester()

# ---------------------------------------------------------------------------
# Test keeping track of imported symbols

tester.equal 28, """
	LOG someSymbol
	""", """
	lMissing: LOG someSymbol
	"""

tester.equal 34, """
	import {toArray, toBlock} from '@jdeighan/coffee-utils'
	import {LOG} from '@jdeighan/coffee-utils/log'
	LOG someSymbol
	""", """
	lImported: toArray toBlock LOG
	lMissing: someSymbol
	"""

# ---------------------------------------------------------------------------
# Test keeping track of exported symbols

# --- list of symbols
tester.equal 47, """
	import {toArray, toBlock} from '@jdeighan/coffee-utils'
	import {arrayToBlock} from '@jdeighan/coffee-utils/block'
	export {toArray, arrayToBlock}
	""", """
	lImported: toArray toBlock arrayToBlock
	lExported: toArray arrayToBlock
	"""

# --- class
tester.equal 57, """
	import {toArray, toBlock} from '@jdeighan/coffee-utils'
	import {arrayToBlock} from '@jdeighan/coffee-utils/block'
	export class ASTWalker
		constructor: (from) ->
			debug "enter ASTWalker()"
	""", """
	lImported: toArray toBlock arrayToBlock
	lExported: ASTWalker
	lMissing: debug
	"""

# --- function
tester.equal 70, """
	export toBlock = (lItems) ->
		return lItems.join("\n")
	""", """
	lExported: toBlock
	"""

# --- variable
tester.equal 78, """
	export meaning = 42
	""", """
	lExported: meaning
	"""

# ---------------------------------------------------------------------------

tester.equal 86, """
	import {undef} from '@jdeighan/coffee-utils'
	x = undef
	""", """
	lImported: undef
	"""

tester.equal 93, """
	x = undef
	""", """
	lMissing: undef
	"""

tester.equal 99, """
	func = () ->
		return undef
	x = func()
	""", """
	lMissing: undef
	"""


# ---------------------------------------------------------------------------

tester.equal 110, """
	x = toArray("abc")
	""", """
	lMissing: toArray
	"""

# ---------------------------------------------------------------------------

tester.equal 118, """
	import {undef, toArray} from '@jdeighan/coffee-utils'
	x = toArray("abc")
	""", """
	lImported: undef toArray
	"""

# ---------------------------------------------------------------------------

tester.equal 127, """
	import {undef, toArray} from '@jdeighan/coffee-utils'
	x = str + toArray("abc")
	""", """
	lImported: undef toArray
	lMissing: str
	"""

# ---------------------------------------------------------------------------

tester.equal 137, """
	func = (x,y) ->
		z = x+y
		return z
	w = func(1,2)
	""", ""

# ---------------------------------------------------------------------------

tester.equal 146, """
	func = (x,y) ->
		z = sum(x+y)
		return z
	""", """
	lMissing: sum
	"""

# ---------------------------------------------------------------------------

tester.equal 156, """
	export isHashComment = (line) =>

		return defined(line)
	""",

	"""
	lExported: isHashComment
	lMissing: defined
	"""

# ---------------------------------------------------------------------------

tester.equal 169, """
	export isHashComment = (line) ->

		return defined(line)
	""",

	"""
	lExported: isHashComment
	lMissing: defined
	"""

# ---------------------------------------------------------------------------

tester.equal 182, """
	export isSubclassOf = (subClass, superClass) ->

		return (subClass == superClass) \
			|| (subClass.prototype instanceof superClass)
	""",

	"""
	lExported: isSubclassOf
	"""

# ---------------------------------------------------------------------------

tester.equal 195, """
	export patchStr = (bigstr, pos, str) ->

		endpos = pos + str.length
		if (endpos < bigstr.length)
			return bigstr.substring(0, pos) + str + bigstr.substring(endpos)
		else
			return bigstr.substring(0, pos) + str
	""",

	"""
	lExported: patchStr
	"""

# ---------------------------------------------------------------------------

tester.equal 211, """
	export removeKeys = (h, lKeys) =>

		for key in lKeys
			delete h[key]
		for own key,value of h
			if defined(value)
				if isArray(value)
					for item in value
						if isHash(item)
							removeKeys(item, lKeys)
				else if (typeof value == 'object')
					removeKeys value, lKeys
		return
	""",

	"""
	lExported: removeKeys
	lMissing: defined isArray isHash
	"""

# ---------------------------------------------------------------------------

tester.equal 234, """
	export isNonEmptyString = (x) ->

		if typeof x != 'string' && x ! instanceof String
			return false
		if x.match(/^\\s*$/)
			return false
		return true
	""",

	"""
	lExported: isNonEmptyString
	"""

# ---------------------------------------------------------------------------

tester.equal 250, """
	export isNonEmptyArray = (x) ->

		return isArray(x) && (x.length > 0)
	""",

	"""
	lExported: isNonEmptyArray
	lMissing: isArray
	"""

# ---------------------------------------------------------------------------

tester.equal 263, """
	export hashHasKey = (x, key) ->

		assert isHash(x), "hashHasKey(): not a hash"
		assert isString(key), "hashHasKey(): key not a string"
		return x.hasOwnProperty(key)
	""",

	"""
	lExported: hashHasKey
	lMissing: assert isHash isString
	"""

# ---------------------------------------------------------------------------

tester.equal 278, """
	export pushCond = (lItems, item, doPush=notInArray) ->

		if doPush(lItems, item)
			lItems.push item
			return true
		else
			return false
	""",

	"""
	lExported: pushCond
	lMissing: notInArray
	"""

# ---------------------------------------------------------------------------

tester.equal 295, '''
	export isUniqueList = (lItems, func=undef) ->

		if notdefined(lItems)
			return true     # empty list is unique
		if defined(func)
			assert isFunction(func), "Not a function: #{OL(func)}"
		h = {}
		for item in lItems
			if defined(func) && !func(item)
				return false
			if defined(h[item])
				return false
			h[item] = 1
		return true
	''',

	"""
	lExported: isUniqueList
	lMissing: undef notdefined defined assert isFunction OL
	"""

# ---------------------------------------------------------------------------

tester.equal 319, '''
	export isUniqueTree = (lItems, func=undef, hFound={}) ->

		if isEmpty(lItems)
			return true     # empty list is unique
		if defined(func)
			assert isFunction(func), "Not a function: #{OL(func)}"
		for item in lItems
			if isArray(item)
				if ! isUniqueTree(item, func, hFound)
					return false
			else
				if defined(func) && !func(item)
					return false
				if defined(hFound[item])
					return false
				hFound[item] = 1
		return true
	''',

	"""
	lExported: isUniqueTree
	lMissing: undef isEmpty defined assert isFunction OL isArray
	"""

# ---------------------------------------------------------------------------

tester.equal 346, '''
	export uniq = (lItems) ->

		return [...new Set(lItems)]
	''',

	'''
	lExported: uniq
	'''

# ---------------------------------------------------------------------------

tester.equal 358, '''
	export test_try = (lItems) ->

		try
			x = toString(lItems)
		catch err
			LOG err.message
		finally
			GOTO 23
	''',

	'''
	lExported: test_try
	lMissing: toString LOG GOTO
	'''

# ---------------------------------------------------------------------------

tester.equal 376, '''
	x = toString(y)
	z = a + b
	m = 4
	''',

	'''
	lMissing: toString y a b
	'''

# ---------------------------------------------------------------------------

tester.equal 388, '''
	for y in blockToArray(code)
		LOG y
		output y
	''',

	'''
	lMissing: blockToArray code LOG output
	'''

# ---------------------------------------------------------------------------

tester.equal 400, '''
	for y,i in blockToArray(code)
		LOG i
		output y
	''',

	'''
	lMissing: blockToArray code LOG output
	'''

# ---------------------------------------------------------------------------

tester.equal 412, '''
	import {LOG} from '@jdeighan/coffee-utils/log'
	x = 42
	LOG "x is #{OL(x)}"
	''',

	'''
	lImported: LOG
	lMissing: OL
	'''

# ---------------------------------------------------------------------------

tester.equal 425, '''
	export say = (x) ->

		if isHash(x)
			LOG hashToStr(x)
		else
			LOG x
		return
	export warn = (message) ->

		say "WARNING: #{message}"
	''',

	'''
	lExported: say warn
	lMissing: isHash LOG hashToStr
	'''

# ---------------------------------------------------------------------------

tester.equal 445, '''
	nLeft = MMath.floor(3.5)
	''',

	'''
	lMissing: MMath
	'''

# ---------------------------------------------------------------------------

tester.equal 455, '''
	nLeft = Math.floor(3.5)
	''',

	''

# ---------------------------------------------------------------------------

tester.equal 463, '''
	export titleLine = (title, char='=', padding=2, linelen=42) ->
		# --- used in logger

		if ! title
			return char.repeat(linelen)

		titleLen = title.length + 2 * padding
		nLeft = Math.floor((linelen - titleLen) / 2)
		nRight = linelen - nLeft - titleLen
		strLeft = char.repeat(nLeft)
		strMiddle = ' '.repeat(padding) + title + ' '.repeat(padding)
		strRight = char.repeat(nRight)
		return strLeft + strMiddle + strRight
	''',

	'''
	lExported: titleLine
	'''

# ---------------------------------------------------------------------------

tester.equal 485, '''
	export extractMatches = (line, regexp, convertFunc=undef) ->

		lStrings = [...line.matchAll(regexp)]
		lStrings = for str in lStrings
			str[0]
		if defined(convertFunc)
			lConverted = for str in lStrings
				convertFunc(str)
			return lConverted
		else
			return lStrings
	''',

	'''
	lExported: extractMatches
	lMissing: undef defined
	'''

# ---------------------------------------------------------------------------

tester.equal 506, '''
	export envVarsWithPrefix = (prefix, hOptions={}) ->
		# --- valid options:
		#        stripPrefix

		assert prefix, "envVarsWithPrefix: empty prefix!"
		plen = prefix.length
		h = {}
		for key in Object.keys(process.env)
			if key.indexOf(prefix) == 0
				if hOptions.stripPrefix
					h[key.substr(plen)] = process.env[key]
				else
					h[key] = process.env[key]
		return h
	''',

	'''
	lExported: envVarsWithPrefix
	lMissing: assert
	'''

# ---------------------------------------------------------------------------

tester.equal 530, '''
	export getTimeStr = (date=undef) ->

		if date == undef
			date = new Date()
		return date.toLocaleTimeString('en-US')
	''',

	'''
	lExported: getTimeStr
	lMissing: undef
	'''

# ---------------------------------------------------------------------------

tester.equal 545, '''
	export replaceVars = (line, hVars) ->

		assert isHash(hVars), "replaceVars() hVars is not a hash"
	''',

	'''
	lExported: replaceVars
	lMissing: assert isHash
	'''

# ---------------------------------------------------------------------------

tester.equal 558, '''
	export replaceVars = (line, hVars, rx) ->

		func = (value) =>
			if defined(value)
				return value

		return line.replace(line)
	''',

	'''
	lExported: replaceVars
	lMissing: defined
	'''

# ---------------------------------------------------------------------------

tester.equal 575, '''
	export replaceVars = (line, hVars={}, rx) ->

		assert isString(line)
		replacerFunc = (match, prefix, name) =>
			if prefix
				return process.env[name]
			else
				value = hVars[name]
				if defined(value)
					return value
				else
					return name
		return line.replace(rx, replacerFunc)
	''',

	'''
	lExported: replaceVars
	lMissing: assert isString defined
	'''

# ---------------------------------------------------------------------------

tester.equal 598, '''
	export replaceVars = (line, hVars={}, rx=/__(env\.)?([A-Za-z_]\w*)__/g) ->

		assert isHash(hVars), "replaceVars() hVars is not a hash"

		replacerFunc = (match, prefix, name) =>
			if prefix
				return process.env[name]
			else
				value = hVars[name]
				if defined(value)
					if isString(value)
						return value
					else
						return JSON.stringify(value)
				else
					return "__#{name}__"
		return line.replace(rx, replacerFunc)
	''',

	'''
	lExported: replaceVars
	lMissing: assert isHash defined isString
	'''

# ---------------------------------------------------------------------------

tester.equal 625, '''
	export isIterable = (obj) ->

		if (obj == undef) || (obj == null)
			return false
		return typeof obj[Symbol.iterator] == 'function'
	''',

	'''
	lExported: isIterable
	lMissing: undef
	'''

# ---------------------------------------------------------------------------

tester.equal 640, '''
	export className = (aClass) ->

		if lMatches = aClass.toString().match(/class\s+(\w+)/)
			return lMatches[1]
		else
			croak "className(): Bad input class"

	export range = (n) ->

		return [0..n-1]

	export timestamp = () ->

		return new Date().toLocaleTimeString("en-US")
	''',

	'''
	lExported: className range timestamp
	lMissing: croak
	'''

# ---------------------------------------------------------------------------

tester.equal 664, slurp(rootDir, 'test', 'utils_utest.coffee'),

	'''
	lExported: isHashComment
	'''

# ---------------------------------------------------------------------------

coffeeCode = '''
	export mapMath = (line) ->

		debug "enter mapMath('#{escapeStr(line)}')"
		if isEmpty(line)
			debug "return undef from mapMath() - empty string"
			return undef

		# --- These should not be needed
		assert line.indexOf("\\n")==-1, "mapper(): line contains newline char"
		assert line.indexOf("\\r")==-1, "mapper(): line contains return char"

		lWords = line.split(/\s+/)    # split on whitespace
		assert defined(lWords), "lWords is not defined!"
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
	'''

tester.equal 700, coffeeCode,

	'''
	lExported: mapMath
	lMissing: debug escapeStr isEmpty undef assert defined isCommand getNode
	'''

# ---------------------------------------------------------------------------

tester.equal 709, '''
	export charCount = () ->
		return
	export removeKeys = (h, lKeys) =>
		removeKeys(lKeys)
		return
	''',

	'''
	lExported: charCount removeKeys
	'''

# ---------------------------------------------------------------------------
# This tester includes debugging info

(() ->
	setDebugging [
		'ASTWalker.visit'
		'beginScope'
		'endScope'
		'Context.add'
		'Context.addGlobal'
		],
		{
			noecho: true,
			returnFrom: () => return true
			yield: ()      => return true
			resume: ()     => return true
			string: ()     => return true
			value: ()      => return true

			# --- set a custom logger for dbgEnter()

			enter: (level, funcName, lArgs) ->

				switch funcName
					when 'ASTWalker.visit'
						LOG indented(lArgs[0].type, level)
					when 'beginScope'
						LOG indented('BEGIN SCOPE', level)
					when 'endScope'
						LOG indented('END SCOPE', level)
					when 'Context.add'
						LOG indented("ADD #{lArgs[0]}", level)
					when 'Context.addGlobal'
						LOG indented("ADDGLOBAL #{lArgs[0]}", level)
					else
						console.log "ERROR: UNKNOWN funcName #{OL(funcName)}"
						return true
			}

	class ASTTester2 extends UnitTester

		transformValue: (coffeeCode) ->

			clearMyLogs()
			walker = new ASTWalker(coffeeCode)
			result = walker.walk('logCalls')
			return getMyLog()

	tester2 = new ASTTester2()

	# ------------------------------------------------------------------------

	tester2.equal 736, '''
		export charCount = () ->
			return
		export removeKeys = (h, lKeys) =>
			removeKeys(lKeys)
			return
		''', '''
		File
			Program
				ExportNamedDeclaration
					AssignmentExpression
						ADDGLOBAL charCount
						FunctionExpression
							BEGIN SCOPE
							BlockStatement
								ReturnStatement
							END SCOPE
				ExportNamedDeclaration
					AssignmentExpression
						ADDGLOBAL removeKeys
						ArrowFunctionExpression
							BEGIN SCOPE
							Identifier
							Identifier
							BlockStatement
								ExpressionStatement
									CallExpression
								ReturnStatement
							END SCOPE
		'''
	)()
