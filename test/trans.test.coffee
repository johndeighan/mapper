# trans.test.coffee

import {UnitTester, UnitTesterNoNorm} from '@jdeighan/unit-tester'
import {undef} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {setDebugging} from '@jdeighan/coffee-utils/debug'

import {Translator} from '@jdeighan/mapper/trans'

dir = mydir(import.meta.url)
dictPath = mkpath(dir, 'dictionary.taml')

simple = new UnitTester()

# ---------------------------------------------------------------------------

class DictionaryTester extends UnitTester

	constructor: () ->
		super()
		@dict = new Translator(dictPath)

	transformValue: ([sent, hPhrases]) ->
		return @dict.findWords(sent, hPhrases)

tester = new DictionaryTester()

# ---------------------------------------------------------------------------

tester.equal 30, ["in the attic"], [
	['attic', '阁楼 gé lóu', 7, 12]
	]

tester.equal 34, ["he was afraid, so he agreed"], [
	['afraid', '害怕 hài pà', 7, 13]
	['agreed', '同意 tóng yì', 21, 27]
	]

tester.equal 39, ["Don't pass out"], [
	['pass', '过去 guò qù', 6, 10]
	]

tester.equal 39, ["Don't pass out", {'pass out': '昏倒 hūn dǎo'}], [
	['pass out', '昏倒 hūn dǎo', 6, 14]
	]
