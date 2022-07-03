# SectionMap.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {log, LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap} from '@jdeighan/mapper'
import {Section} from '@jdeighan/mapper/section'
import {SectionMap} from '@jdeighan/mapper/sectionmap'

# ---------------------------------------------------------------------------

(() ->
	map = new SectionMap(['top','middle','bottom'])
	simple.equal 17, map.length(), 0

	map.section('middle').add 'line 1'
	map.section('bottom').add 'line 2'
	map.section('bottom').add 'line 3'

	simple.equal 23, map.length(), 3
	simple.equal 24, map.length('top'), 0
	simple.equal 25, map.length('middle'), 1
	simple.equal 26, map.length('bottom'), 2
	simple.equal 27, map.length(['top','middle']), 1
	simple.equal 28, map.length(['top','bottom']), 2
	simple.equal 29, map.length(['middle','bottom']), 3

	simple.equal 31, map.getBlock(), """
			line 1
			line 2
			line 3
			"""
	)()

(() ->
	map = new SectionMap([
			'html'
			[
				'export'
				'import'
				'code'
				]
			'style'
			])
	map.addSet 'Script', ['export','import','code']

	simple.equal 50, map.firstSection('Script'), map.section('export')
	simple.equal 51, map.lastSection('Script'), map.section('code')

	simple.equal 50, map.length(), 0

	map.section('import').add "import {undef} from '@jdeighan/coffee-utils;"
	map.section('html').add   "<body>"
	map.section('code').add   "let meaning = 42;"
	map.section('html').add   "\t<h1>The Hitchhiker's Guide</h1>"
	map.section('export').add "export let answer = 42;"
	map.section('style').add  "h1 {\n\tcolor = 'red';\n\t}"
	map.section('html').add   "</body>"

	simple.equal 60, map.length('Script'), 3
	simple.truthy 61, map.nonEmpty('Script')

	map.enclose 'Script', '<script>', '</script>'
	map.enclose 'style',  '<style>',  '</style>'

	simple.equal 76, map.getBlock(), """
			<body>
				<h1>The Hitchhiker's Guide</h1>
			</body>
			<script>
				export let answer = 42;
				import {undef} from '@jdeighan/coffee-utils;
				let meaning = 42;
			</script>
			<style>
				h1 {
					color = 'red';
					}
			</style>
			"""
	)()
