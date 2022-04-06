class Mapper
=================

A Mapper object is a subclass of StringFetcher, and is therefore
constructed from a block (i.e. a multi-line string) and an optional source.
It has the following features:

1. Methods get(), unget(), peek() and skip(), which deal with
	pairs `[<item>, <level>]` instead of only pure strings. `<level>` is the
	level of indentation in the line (by default, number of TAB characters)
	while `<item>` will not include that indentation.

2. Although `<item>` is by default the string following the indentation,
	you can override the method mapLine() to return a modified string,
	return undef to indicate that the line should be ignored, or even
	return anything you wish, e.g. a hash or object.

3. Additionally, the mapLine() function can fetch additional lines from
	the input while constructing the item to return. The method fetchBlock()
	is particularly useful here.

In summary, commonly used methods of this class include:

	get()
	unget()
	peek()
	skip()
	fetchBlock(atLevel)
	getAll()
	getAllText()
