# Section.test.coffee

import {UnitTester, simple} from '@jdeighan/unit-tester'
import {undef, isEmpty, nonEmpty} from '@jdeighan/coffee-utils'
import {log, LOG, DEBUG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'
import {joinBlocks} from '@jdeighan/coffee-utils/block'

import {doMap} from '@jdeighan/mapper'
import {Section} from '@jdeighan/mapper/section'

# ---------------------------------------------------------------------------

section = new Section()
simple.equal 15, section.length(), 0
simple.truthy 16, section.isEmpty()
simple.falsy 17, section.nonEmpty()

section.add('abc')
simple.equal 20, section.length(), 1
simple.falsy 21, section.isEmpty()
simple.truthy 22, section.nonEmpty()

section.add('def')
simple.equal 25, section.length(), 2
simple.falsy 26, section.isEmpty()
simple.truthy 27, section.nonEmpty()

section.prepend('aaa')
simple.equal 30, section.length(), 3
simple.equal 31, section.getBlock(), "aaa\nabc\ndef"

section.add(['A','B','C'])
simple.equal 34, section.length(), 6
simple.falsy 35, section.isEmpty()
simple.truthy 36, section.nonEmpty()
