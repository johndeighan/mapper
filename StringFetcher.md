class StringFetcher
=================

A StringFetcher object allows you to fetch one line at a time
from a **block**, i.e. a multi-line string. You must tell the
constructor where the text came from. For example:

```coffeescript
fetcher = new StringFetcher("""
	abc
	def
	ghi
	""", "c:/Users/johnd/temp.txt")

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
subdirectory of c:/Users/johnd, then:

```coffeescript
fetcher = new StringFetcher("""
	abc
		#include file.txt
	""", "c:/Users/johnd/source.txt")

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

The method getBlock() will fetch all lines from a StringFetcher,
maintaining indentation, and return a **block**, i.e. a string
with lines joined using newline characters.
