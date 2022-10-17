# utils.test.coffee

import {UnitTester, tester} from '@jdeighan/unit-tester'
import {isHashComment} from '@jdeighan/mapper/utils'

tester.truthy 6, isHashComment('# abc')
tester.truthy 7, isHashComment('   # abc')
tester.falsy  8, isHashComment('#abc')
