# utils.test.coffee

import {UnitTester, utest} from '@jdeighan/unit-tester'
import {isHashComment} from '@jdeighan/mapper/utils'

utest.truthy 6, isHashComment('# abc')
utest.truthy 7, isHashComment('   # abc')
utest.falsy  8, isHashComment('#abc')
