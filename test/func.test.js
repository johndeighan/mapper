// Generated by CoffeeScript 2.7.0
  // func.test.coffee
import {
  UnitTesterNorm
} from '@jdeighan/unit-tester';

import {
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  debugStack
} from '@jdeighan/coffee-utils/stack';

import {
  CieloMapper,
  doMap
} from '@jdeighan/mapper';

import {
  mapHereDoc,
  doDebugHereDoc,
  addHereDocType
} from '@jdeighan/mapper/heredoc';

import {
  FuncHereDoc
} from '@jdeighan/mapper/func';

addHereDocType(new FuncHereDoc()); // --- CoffeeScript function


  // ---------------------------------------------------------------------------
(function() {
  var HereDocMapper, tester;
  HereDocMapper = class HereDocMapper extends UnitTesterNorm {
    transformValue(block) {
      return mapHereDoc(block).str;
    }

  };
  tester = new HereDocMapper();
  // ------------------------------------------------------------------------
  tester.equal(29, `(evt) ->
	log 'click'`, `(function(evt) {
	return log('click');
	});`);
  // ------------------------------------------------------------------------
  // Function block, with no name or parameters
  tester.equal(42, `() ->
	return true`, `(function() {
	return true;
	});`);
  // ------------------------------------------------------------------------
  // Function block, with no name but one parameter
  tester.equal(54, `(evt) ->
	console.log 'click'`, `(function(evt) {
	return console.log('click');
	});`);
  // ------------------------------------------------------------------------
  // Function block, with no name but one parameter
  return tester.equal(66, `(  evt  )     ->
	log 'click'`, `(function(evt) {
	return log('click');
	});`);
})();

// ---------------------------------------------------------------------------
(function() {
  var HereDocMapper, tester;
  HereDocMapper = class HereDocMapper extends UnitTesterNorm {
    transformValue(block) {
      return doMap(CieloMapper, block, import.meta.url);
    }

  };
  tester = new HereDocMapper();
  // ------------------------------------------------------------------------
  tester.equal(90, `input on:click={<<<}
	(event) ->
		console.log 'click'
`, `input on:click={(function(event) {
	return console.log('click');
	});}`);
  // ------------------------------------------------------------------------
  return tester.equal(103, `input on:click={<<<}
	(event) ->
		callme(x)
		console.log('click')
`, `input on:click={(function(event) {
	callme(x);
	return console.log('click');
	});}`);
})();
