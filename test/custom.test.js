// Generated by CoffeeScript 2.6.1
// custom.test.coffee
var SmartTester, UCHereDoc, tester;

import {
  UnitTesterNorm,
  UnitTester
} from '@jdeighan/unit-tester';

import {
  assert,
  undef,
  pass,
  isEmpty,
  isArray,
  isString,
  CWS
} from '@jdeighan/coffee-utils';

import {
  firstLine,
  remainingLines
} from '@jdeighan/coffee-utils/block';

import {
  CieloMapper
} from '@jdeighan/mapper';

import {
  addHereDocType
} from '@jdeighan/mapper/heredoc';

// ---------------------------------------------------------------------------
SmartTester = class SmartTester extends UnitTester {
  transformValue(block) {
    var oInput;
    oInput = new CieloMapper(block, import.meta.url);
    return oInput.getBlock();
  }

};

tester = new SmartTester();

// ---------------------------------------------------------------------------
// --- test creating a custom HEREDOC section

//     e.g. with header line *** we'll create an upper-cased single line string
UCHereDoc = class UCHereDoc {
  myName() {
    return 'upper case';
  }

  isMyHereDoc(block) {
    return firstLine(block) === '***';
  }

  map(block) {
    var str;
    str = CWS(remainingLines(block).toUpperCase());
    return {
      str: JSON.stringify(str),
      obj: str
    };
  }

};

addHereDocType(new UCHereDoc());

// ---------------------------------------------------------------------------
tester.equal(45, `str = <<<
	***
	select ID,Name
	from Users
`, `str = "SELECT ID,NAME FROM USERS"`);
