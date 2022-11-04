# dumpAST.coffee

import {
	assert, croak, setDebugging, LOG, LOGVALUE,
	} from '@jdeighan/exceptions'
import {
	undef, defined, notdefined, isEmpty,
	} from '@jdeighan/coffee-utils'
import {ASTWalker} from '@jdeighan/mapper/ast'

# ---------------------------------------------------------------------------

filepath = "c:\\Users\\johnd\\mapper\\test\\ast.coffee"
coffeeCode = slurp(filepath)

walker = new ASTWalker(coffeeCode)
# setDebugging 'getSymbols'
info = walker.walk(true)

if isEmpty(info)
	LOG "Nothing needed or exported"
else
	LOG info

walker.barfAST("./test/ast.txt")
