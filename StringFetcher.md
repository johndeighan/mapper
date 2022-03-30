class StringFetcher
=================

A StringFetcher object allows you to fetch one line at a time
from a **block**, i.e. a multi-line string. For example:

```coffeescript
fetcher = new StringFetcher("""
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

__LINE, __FILE and __DIR
------------------------
Also, any instances of the string "__LINE" will be replaced by
the line number within the block, any instances of the string
"__FILE" will be replaced by the name of the current file, and
any instances of the string "__DIR" will be replaced by the
directory containing the current file. The latter 2 replacements
are only performed if a source is passed to the constructor.
For example:

```coffeescript
fetcher = new StringFetcher("""
	__DIR
	__FILE
	__LINE: abc
	__LINE: def
	__LINE: ghi
	""", "c:/Users/johnd/sample.txt")
nLines = 0
while line = fetcher.fetch()
	console.log "#{line}"
console.log "#{fetcher.lineNum} total lines"
```

will output:
```text
c:/Users/johnd
sample.txt
3: abc
4: def
5: ghi
5 total lines
```

unfetch()
---------
There is also a method named unfetch() where you can provide
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
subdirectory, then:

```coffeescript
fetcher = new StringFetcher("""
	__FILE
	abc
		#include file.txt
	""", "c:/Users/johnd/source.txt")
while line = fetcher.fetch()
	console.log "#{fetcher.lineNum}: #{line}"
console.log "#{fetcher.lineNum} total lines"
```

will output:
```text
1: source.txt
2: abc
3:      def
4:      ghi
4 total lines
```

Note that any indentation of the #include statement is carried
over to all lines in the included text.

`__END__`
-------

Also, if a line containing only `__END__` is encountered, that
line is ignored and the file is terminated, as if neither the
line containing `__END__`, nor any following lines were present
