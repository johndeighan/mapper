# builtins.test.coffee

import {tester} from '@jdeighan/unit-tester'
import {isBuiltin} from '@jdeighan/mapper/builtins'

tester.truthy 6, isBuiltin('parseInt')
tester.falsy  7, isBuiltin('nothing')
