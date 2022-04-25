// Generated by CoffeeScript 2.7.0
// getter.test.coffee
var simple;

import assert from 'assert';

import {
  UnitTester,
  UnitTesterNorm
} from '@jdeighan/unit-tester';

import {
  undef,
  error,
  warn,
  rtrim
} from '@jdeighan/coffee-utils';

import {
  LOG
} from '@jdeighan/coffee-utils/log';

import {
  setDebugging
} from '@jdeighan/coffee-utils/debug';

import {
  Getter
} from '@jdeighan/mapper/get';

simple = new UnitTester();

// ---------------------------------------------------------------------------
(function() {
  var getter;
  getter = new Getter([1, 2, 3]);
  simple.equal(21, getter.peek(), 1);
  simple.equal(22, getter.peek(), 1);
  simple.falsy(23, getter.eof());
  simple.equal(24, getter.get(), 1);
  simple.equal(25, getter.get(), 2);
  simple.falsy(27, getter.eof());
  simple.succeeds(28, function() {
    return getter.unget(5);
  });
  simple.succeeds(29, function() {
    return getter.unget(6);
  });
  simple.equal(30, getter.get(), 6);
  simple.equal(31, getter.get(), 5);
  simple.falsy(32, getter.eof());
  simple.equal(34, getter.get(), 3);
  simple.truthy(35, getter.eof());
  simple.succeeds(36, function() {
    return getter.unget(13);
  });
  simple.falsy(37, getter.eof());
  simple.equal(38, getter.get(), 13);
  return simple.truthy(39, getter.eof());
})();

// ---------------------------------------------------------------------------
(function() {
  var generator, getter;
  // --- A generator is a function that, when you call it,
  //     it returns an iterator
  generator = function*() {
    yield 1;
    yield 2;
    yield 3;
  };
  // --- You can pass any iterator to the Getter() constructor
  getter = new Getter(generator());
  simple.equal(21, getter.peek(), 1);
  simple.equal(22, getter.peek(), 1);
  simple.falsy(23, getter.eof());
  simple.equal(24, getter.get(), 1);
  simple.equal(25, getter.get(), 2);
  simple.falsy(27, getter.eof());
  simple.succeeds(28, function() {
    return getter.unget(5);
  });
  simple.succeeds(29, function() {
    return getter.unget(6);
  });
  simple.equal(30, getter.get(), 6);
  simple.equal(31, getter.get(), 5);
  simple.falsy(32, getter.eof());
  simple.equal(34, getter.get(), 3);
  simple.truthy(35, getter.eof());
  simple.succeeds(36, function() {
    return getter.unget(13);
  });
  simple.falsy(37, getter.eof());
  simple.equal(38, getter.get(), 13);
  return simple.truthy(39, getter.eof());
})();

// ---------------------------------------------------------------------------
