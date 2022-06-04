class LineFetcher
=================

A LineFetcher object allows you to fetch one line at a time
from a source, such as:

	1. A **block**, i.e. multi-line string
	2. A file - given the file's full path or URL
	3. A generator

For example:

```coffeescript
path = "c:/Users/johnd/temp.txt"
fetcher = new LineFetcher(path, """
	abc
	def
	ghi
	""")

while line = fetcher.fetch()
	console.log "LINE #{fetcher.lineNum}: <<<#{line}>>>"
console.log "#{fetcher.lineNum} total lines"
```

will output:
```text
LINE 1: <<<abc>>>
LINE 2: <<<def>>>
LINE 3: <<<ghi>>>
3 total lines
```

Interface
---------

The full interface to a Fetcher object is:

```text
fetcher = Fetcher(
		source: string
		collection: block | iterator
		hOptions: hash
		)
	# --- one or both of source and collection must be provided
	#     source (if defined) must be a file name, file path or URL
	#     collection (if defined) can be a block or iterator
	#     if collection is undef, text is read from source
	#     hOptions may include key 'prefix', which will be
	#        prepended to each line returned

line = @fetch()

@unfetch(line)

@lineNum

@filename    # --- "<unknown>" if not known

hInfo = @getSourceInfo()
	# --- returns {filename, dir, fullpath, stub, ext, purpose, lineNum, prefix}

@all()   - a generator for all lines in input
@fetchAll() - a function returning array of all lines
@fetchUntil(endStr) - a function returning array of all lines
	until (but not including) the line matching endStr
@fetchBlock() - returns block corresponding to fetchAll()
```

- trailing whitespace is removed from each line
- #include <filename> is handled
- __END__ denotes end of input
- unfetch() may be called multiple times
- fetch() returns undef at end of input


Look-ahead
----------

To enable look-ahead in the stream, you can utilize
the following additional method:

**unfetch(str)** - you can provide
a string, which will then be returned by the next call
to fetch()

#include
--------
In addition, the input may contain #include statements, e.g.
if a file named 'file.txt' containing:

```text
def
ghi
```

exists anywhere within directory c:/Users/johnd or inside any
subdirectory of c:/Users/johnd, then:

```coffeescript
path = "c:/Users/johnd/source.txt"
fetcher = new LineFetcher(path, """
	abc
		#include file.txt
	""")

while line = fetcher.fetch()
	console.log "#{fetcher.lineNum}: #{line}"
console.log "#{fetcher.lineNum} total lines"
```

will output:
```text
1: abc
2:    def
3:    ghi
3 total lines
```

Note that any indentation of the #include statement is carried
over to all lines in the included text. Included files may
themselves contain #include statements.

`__END__`
-------

Also, if a line containing only `__END__` is encountered, that
line is ignored and the file is terminated, as if neither the
line containing `__END__`, nor any following lines were present

`getBlock()`
------------

The method getBlock() will fetch all lines from a LineFetcher,
maintaining indentation, and return a **block**, i.e. a string
with lines joined using newline characters.
