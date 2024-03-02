# TamlMapper.test.coffee

import {undef, isNumber, DUMP} from '@jdeighan/base-utils'
import {
	UnitTester, equal, truthy, falsy, succeeds,
	} from '@jdeighan/base-utils/utest'
import {slurp, mkpath, mydir} from '@jdeighan/base-utils/fs'
import {map} from '@jdeighan/mapper'
import {parseValue, TamlMapper} from '@jdeighan/mapper/taml'

# ---------------------------------------------------------------------------

equal parseValue('undef'), undef
equal parseValue("null"), null
equal parseValue("true"), true
equal parseValue("false"), false

truthy isNumber(parseValue('2'))
truthy isNumber(parseValue('2.5'))
truthy isNumber(parseValue('2a'))
falsy  isNumber('2a')
falsy  isNumber(parseValue('a2'))

equal parseValue("«undef»"), 'undef'
equal parseValue("«null»"),  'null'
equal parseValue("«true»"),  'true'
equal parseValue("«false»"), 'false'

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

obj_tester.equal """
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

obj_tester.equal """
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

obj_tester.equal """
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

obj_tester.equal """
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

tester.equal """
	---
	- abc
	- def
	""", ['abc', 'def']

tester.equal """
	---
	fName: John
	lName: Deighan
	fullName: John Deighan
	""", {
		fName: 'John'
		lName: 'Deighan'
		fullName: 'John Deighan'
		}

tester.equal """
	---
	-
		- a
		- b
	- def
	""", [['a','b'], 'def']

tester.equal """
	---
	-
		x: 1
		y: 2
	- def
	""", [{x:1, y:2}, 'def']

tester.equal """
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

succeeds () =>
	dir = mydir(import.meta.url)
	block = slurp(mkpath(dir, 'beauty_and_the_beast.taml'))
	mapper = new TamlMapper(block)
	result = mapper.getResult()
