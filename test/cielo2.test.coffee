# cielo2.test.coffee

import {UnitTesterNorm, UnitTester} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {mydir, mkpath} from '@jdeighan/coffee-utils/fs'
import {log, LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap} from '@jdeighan/mapper'
import {CieloMapper} from '@jdeighan/mapper/cielomapper'
import {convertCoffee} from '@jdeighan/mapper/coffee'
import {cieloCodeToJS, convertCielo} from '@jdeighan/mapper/cielo'

simple = new UnitTesterNorm(import.meta.url)
# convertCoffee false

# ---------------------------------------------------------------------------
# --- Features:
#        - REMOVE blank lines
#        - #include <file>
#        - handle continuation lines
#        - replace FILE, LINE and DIR
#        - stop on __END__
#        - handle HEREDOC - various types
#        - add auto-imports
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------

(() ->

	class CieloTester extends UnitTesterNorm

		transformValue: (text) ->
			return cieloCodeToJS(text, import.meta.url)

	tester = new CieloTester('cielo.test')

	# --- Should auto-import mydir & mkpath from @jdeighan/coffee-utils/fs

	tester.equal 340, """
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			import {mydir,mkpath} from '@jdeighan/coffee-utils/fs';
			var dir, filepath;
			dir = mydir(import.meta.url);
			filepath = mkpath(dir, 'test.txt');
			"""

	# --- But not if we're already importing them

	tester.equal 352, """
			import {mkpath,mydir} from '@jdeighan/coffee-utils/fs'
			dir = mydir(import.meta.url)
			filepath = mkpath(dir, 'test.txt')
			""", """
			var dir, filepath;
			import {
				mkpath,
				mydir
				} from '@jdeighan/coffee-utils/fs';
			dir = mydir(import.meta.url);
			filepath = mkpath(dir, 'test.txt');
			"""

	tester.equal 366, """
			x = undef
			""", """
			import {undef} from '@jdeighan/coffee-utils';
			var x;
			x = undef;
			"""

	tester.equal 374, """
			x = undef
			contents = 'this is a file'
			fs.writeFileSync('temp.txt', contents, {encoding: 'utf8'})
			""", """
			import fs from 'fs';
			import {undef} from '@jdeighan/coffee-utils';
			var contents, x;
			x = undef;
			contents = 'this is a file';
			fs.writeFileSync('temp.txt', contents, {
				encoding: 'utf8'
				});
			"""

	tester.equal 389, """
			x = 23
			logger x
			""", """
			import {log as logger} from '@jdeighan/coffee-utils/log';
			var x;
			x = 23;
			logger(x);
			"""

	)()
