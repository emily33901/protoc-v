module main

import os

import google.protobuf
import google.protobuf.compiler

fn main() {
	as_bytes := os.get_raw_stdin()

	// Wait for debugger so i can maintain my sanity
	for !os.debugger_present() {
	}

	request := compiler.codegeneratorrequest_unpack(as_bytes) or {
		panic('Failed to decode protobufs')
	}

	os.write_file('test-output/result.txt', '$request')
}