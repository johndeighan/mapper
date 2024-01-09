# TamlMapper.test.coffee

import {undef, isNumber, DUMP} from '@jdeighan/base-utils'
import {utest, UnitTester} from '@jdeighan/unit-tester'
import {slurp, mkpath} from '@jdeighan/base-utils/fs'
import {mydir} from '@jdeighan/coffee-utils/fs'
import {map} from '@jdeighan/mapper'
import {parseValue, TamlMapper} from '@jdeighan/mapper/taml'

# ---------------------------------------------------------------------------

utest.equal 12, parseValue('undef'), undef
utest.equal 13, parseValue("null"), null
utest.equal 14, parseValue("true"), true
utest.equal 15, parseValue("false"), false

utest.truthy 17, isNumber(parseValue('2'))
utest.truthy 18, isNumber(parseValue('2.5'))
utest.truthy 19, isNumber(parseValue('2a'))
utest.falsy  20, isNumber('2a')
utest.falsy  21, isNumber(parseValue('a2'))

utest.equal 23, parseValue("«undef»"), 'undef'
utest.equal 24, parseValue("«null»"),  'null'
utest.equal 25, parseValue("«true»"),  'true'
utest.equal 26, parseValue("«false»"), 'false'

# ---------------------------------------------------------------------------
# --- Test that the correct user objects are created

class ObjTester extends UnitTester

	transformValue: (block) ->

		mapper = new TamlMapper(block)
		lItems = []
		while (hNode = mapper.get())
			lItems.push hNode.uobj
		return lItems

obj_tester = new ObjTester()

# ---------------------------------------------------------------------------

obj_tester.equal 45, """
	---
	- undef
	- null
	- true
	- false
	- 42
	- 3.14159
	""", [
		{ type: 'listItem', value: undef }
		{ type: 'listItem', value: null }
		{ type: 'listItem', value: true }
		{ type: 'listItem', value: false }
		{ type: 'listItem', value: 42 }
		{ type: 'listItem', value: 3.14159 }
		]

# ---------------------------------------------------------------------------

obj_tester.equal 64, """
	---
	- «undef»
	- «null»
	- «true»
	- «false»
	- «42»
	- «3.14159»
	""", [
		{ type: 'listItem', value: 'undef' }
		{ type: 'listItem', value: 'null' }
		{ type: 'listItem', value: 'true' }
		{ type: 'listItem', value: 'false' }
		{ type: 'listItem', value: '42' }
		{ type: 'listItem', value: '3.14159' }
		]

# ---------------------------------------------------------------------------

obj_tester.equal 83, """
	---
	- abc
	-
		- a
		- b
	""", [
		{ type: 'listItem', value: 'abc' }
		{ type: 'listItem' }
		{ type: 'listItem', value: 'a'}
		{ type: 'listItem', value: 'b'}
		]

# ---------------------------------------------------------------------------

obj_tester.equal 98, """
	---
	fName: John
	lName: Deighan
	fullName:
		- John Deighan
	""", [
		{ type: 'hashItem', key: 'fName', value: 'John' }
		{ type: 'hashItem', key: 'lName', value: 'Deighan' }
		{ type: 'hashItem', key: 'fullName'}
		{ type: 'listItem', value: 'John Deighan' }
		]

# ---------------------------------------------------------------------------
# --- Test that the correct result object is obtained

class ResultTester extends UnitTester

	transformValue: (block) ->

		mapper = new TamlMapper(block)
		return mapper.getResult()

tester = new ResultTester()

# ---------------------------------------------------------------------------

tester.equal 125, """
	---
	- abc
	- def
	""", ['abc', 'def']

tester.equal 131, """
	---
	fName: John
	lName: Deighan
	fullName: John Deighan
	""", {
		fName: 'John'
		lName: 'Deighan'
		fullName: 'John Deighan'
		}

tester.equal 142, """
	---
	-
		- a
		- b
	- def
	""", [['a','b'], 'def']

tester.equal 150, """
	---
	-
		x: 1
		y: 2
	- def
	""", [{x:1, y:2}, 'def']

tester.equal 158, """
	---
	title:
		en: Aladdin and the magic lamp
		zh: 阿拉丁和神灯
		pinyin: Ā lādīng hé shén dēng
	author:
		en: Hanna Diyab
	lCharacters:
		-
			en: Aladdin
			zh: 阿拉丁
			pinyin: Ā lādīng
	lParagraphs:
		-
			lSentences:
				-
					en: "We can share the gems in the cave."
					zh: “我们可以分享洞穴里的宝石。”
					pinyin: “Wǒmen kěyǐ fēnxiǎng dòngxué lǐ de bǎoshí.”
	""", {
		title: {
			en: 'Aladdin and the magic lamp'
			zh: '阿拉丁和神灯'
			pinyin: 'Ā lādīng hé shén dēng'
			}
		author: {
			en: 'Hanna Diyab'
			}
		lCharacters: [
			{
				en: 'Aladdin'
				zh: '阿拉丁'
				pinyin: 'Ā lādīng'
				}
			]
		lParagraphs: [
			{
				lSentences: [
					{
						en: '"We can share the gems in the cave."'
						zh: '“我们可以分享洞穴里的宝石。”'
						pinyin: '“Wǒmen kěyǐ fēnxiǎng dòngxué lǐ de bǎoshí.”'
						}
					]
				}
			]
		}

# ---------------------------------------------------------------------------

utest.succeeds 209, () =>
	dir = mydir(import.meta.url)
	block = slurp(dir, 'beauty_and_the_beast.taml')
	mapper = new TamlMapper(block)
	result = mapper.getResult()
