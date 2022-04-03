# func.test.coffee

import {UnitTester} from '@jdeighan/unit-tester'

import {setDebugging} from '@jdeighan/coffee-utils/debug'
import {debugStack} from '@jdeighan/coffee-utils/stack'

import {SmartMapper, doMap} from '@jdeighan/mapper'
import {
	mapHereDoc, doDebugHereDoc, addHereDocType,
	} from '@jdeighan/mapper/heredoc'
import {FuncHereDoc} from '@jdeighan/mapper/func'

addHereDocType new FuncHereDoc()    # --- CoffeeScript function

# ---------------------------------------------------------------------------

(() ->

	class HereDocMapper extends UnitTester

		transformValue: (block) ->
			return mapHereDoc(block).str

	tester = new HereDocMapper()

	# ------------------------------------------------------------------------

	tester.equal 29, """
			(evt) ->
				log 'click'
			""",
			"""
			(function(evt) {
				return log('click');
				});
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name or parameters

	tester.equal 42, """
			() ->
				return true
			""", """
			(function() {
				return true;
				});
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal 54, """
			(evt) ->
				console.log 'click'
			""", """
			(function(evt) {
				return console.log('click');
				});
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal 66, """
			(  evt  )     ->
				log 'click'
			""", """
			(function(evt) {
				return log('click');
				});
			"""
	)()


# ---------------------------------------------------------------------------

(() ->

	class HereDocMapper extends UnitTester

		transformValue: (block) ->
			return doMap(SmartMapper, block)

	tester = new HereDocMapper()

	# ------------------------------------------------------------------------

	tester.equal 90, """
			input on:click={<<<}
				(event) ->
					console.log 'click'

			""", """
			input on:click={(function(event) {
				return console.log('click');
				});}
			"""

	# ------------------------------------------------------------------------

	tester.equal 103, """
			input on:click={<<<}
				(event) ->
					callme(x)
					console.log('click')

			""", """
			input on:click={(function(event) {
				callme(x);
				return console.log('click');
				});}
			"""
	)()
