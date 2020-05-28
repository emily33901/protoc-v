module main

import os

import google.protobuf
import google.protobuf.compiler

fn main() {
	mut proto := ''

	for {
		l := proto.len
		proto += os.get_raw_line()
	
		if l == proto.len { break }
	}

	as_bytes := []byte{}(proto)

	request := compiler.codegeneratorrequest_unpack(as_bytes) or {
		panic('Failed to decode protobufs')
	}
}