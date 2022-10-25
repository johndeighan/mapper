# Scope.test.coffee

import {utest} from '@jdeighan/unit-tester'
import {Scope} from '@jdeighan/mapper/scope'

scope = new Scope(['main'])
scope.add('func')

utest.truthy  9, scope.has('main')
utest.truthy 10, scope.has('func')
utest.falsy  11, scope.has('notthere')

