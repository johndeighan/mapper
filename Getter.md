class Getter
=================

A Getter object is a subclass of Fetcher, and is therefore
constructed from a block (i.e. a multi-line string) and a source.

It has the following features:

- replace variables in strings. set variables via method setVar()

- Methods get(), unget(), peek() and skip(), which return mapped
	items, i.e. @mapItem(line), where line is an item gotten via @fetch
	(). The default @mapItem is just the identify function.

- Although `<item>` is by default the string following the
	indentation, you can override the method map() to return a modified
	string, return undef to indicate that the line should be ignored,
	or even return anything you wish, e.g. a hash or object.

- The map() function can fetch additional lines from the input while
	mapping fetched items via @map() before returning them. The method
	fetchBlock() is particularly useful here.

- The unmap() function maps items fetched via @get(), etc. to strings.
	It is used in getBlock() on each item to construct a block.
Interface
---------

The full interface to a Getter object is:

```text
getter = Getter(
		source: string
		collection: block | iterator
		hOptions: hash
		)
	# --- args are the same as for Fetcher()

line = @fetch()   # same as for Fetcher
@unfetch(line)    # same as for Fetcher

obj = @get()    # returns mapped item
@skip()         # same as @get, but doesn't return anything
@eof()          # returns true if at end of input, else false
@peek()         # returns next mapped item without consuming it

override @getItemType to detect "special" item types
override @handleItemType to handle "special" items
override @map to specify how to map (non-special) items

@allMapped()      - a generator for all mapped items in input
@getAll()         - a function returning array of all mapped items
@getUntil(end)    - a function returning array of all mapped items
	until (but not including) the item matching end
@getBlock()       - returns block corresponding to getAll()
```

- trailing whitespace is removed from each line
- #include <filename> is handled
- __END__ denotes end of input
- unfetch() may be called multiple times
- fetch() returns undef at end of input

