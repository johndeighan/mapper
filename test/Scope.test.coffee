# Scope.test.coffee

import {truthy, falsy} from '@jdeighan/base-utils/utest'
import {Scope} from '@jdeighan/mapper/scope'

scope = new Scope('global', ['main'])
scope.add('func')

truthy scope.has('main')
truthy scope.has('func')
falsy  scope.has('notthere')

