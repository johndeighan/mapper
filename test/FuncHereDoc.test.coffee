# FuncHereDoc.test.coffee

import {UnitTesterNorm} from '@jdeighan/unit-tester'

import {setDebugging} from '@jdeighan/coffee-utils/debug'

import {mapHereDoc, addHereDocType} from '@jdeighan/mapper/heredoc'
import {FuncHereDoc} from '@jdeighan/mapper/func'

addHereDocType new FuncHereDoc()    # --- CoffeeScript function

# ---------------------------------------------------------------------------

(() ->

	class HereDocMapper extends UnitTesterNorm

		transformValue: (block) ->
			return mapHereDoc(block).str

	tester = new HereDocMapper()

	# ------------------------------------------------------------------------

	tester.equal 28, """
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

	tester.equal 41, """
			() ->
				return true
			""", """
			(function() {
				return true;
				});
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal 53, """
			(evt) ->
				console.log 'click'
			""", """
			(function(evt) {
				return console.log('click');
				});
			"""

	# ------------------------------------------------------------------------
	# Function block, with no name but one parameter

	tester.equal 65, """
			(  evt  )     ->
				log 'click'
			""", """
			(function(evt) {
				return log('click');
				});
			"""
	)()

