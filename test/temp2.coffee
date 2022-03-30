# temp2.coffee

import {undef, escapeStr} from '@jdeighan/coffee-utils'
import {LOG} from '@jdeighan/coffee-utils/log'
import {debug, setDebugging} from '@jdeighan/coffee-utils/debug'

import {StringFetcher} from '@jdeighan/string-input'

# ---------------------------------------------------------------------------

fetcher = new StringFetcher("""
	__FILE
	abc
		#include file.txt
	""", "c:/Users/johnd/source.txt")
while line = fetcher.fetch()
	console.log "#{fetcher.lineNum}: #{line}"
console.log "#{fetcher.lineNum} total lines"
