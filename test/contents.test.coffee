# contents.test.coffee

import {undef} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {UnitTester} from '@jdeighan/coffee-utils/test'
import {getFileContents} from '@jdeighan/string-input'

root = process.env.DIR_ROOT = mydir(`import.meta.url`)
process.env.DIR_DATA = "#{root}/data"
process.env.DIR_MARKDOWN = "#{root}/markdown"
simple = new UnitTester()

# ---------------------------------------------------------------------------
# --- test getFileContents without conversion

simple.equal 16, getFileContents('file.md'), """
		title
		=====

		subtitle
		--------

		"""

simple.equal 25, getFileContents('file.taml'), """
		---
		-
			first: 1
			second: 2
		-
			kind: cmd
			cmd: include

		"""

simple.equal 36, getFileContents('file.txt'), """
		abc
		def

		"""

# ---------------------------------------------------------------------------
# --- test getFileContents with conversion

simple.equal 45, getFileContents('file.md', true), """
		<h1>title</h1>
		<h2>subtitle</h2>
		"""

simple.equal 50, getFileContents('file.taml', true), [
		{first: 1, second: 2},
		{kind: 'cmd', cmd: 'include'},
		]

simple.equal 55, getFileContents('file.txt', true), """
		abc
		def
		"""
