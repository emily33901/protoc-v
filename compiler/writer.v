module compiler

// Helper struct for outputing formatted files

import strings

struct Writer {

mut:
	builder strings.Builder

	indent int
}

fn new_writer() Writer {
	return Writer{
		builder: strings.new_builder(100)
		indent: 0
	}
}

// l writes a line to the output
pub fn (mut w Writer) l(l string) {
	w.builder.writeln(l)
}

// text gets the current text of the writer
pub fn (mut w Writer) text() string {
	return w.builder.str()
}