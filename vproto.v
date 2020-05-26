module main

import flag
import os

import v.table
import v.parser
import v.pref
import v.fmt
import v.ast

import compiler

struct Args {
mut:
	filename string
	additional []string
	out_folder string
	imports []string
	quiet bool
	fp &flag.FlagParser
}

fn parse_args() Args {
	mut fp := flag.new_flag_parser(os.args)

	mut args := Args{fp: fp}

	fp.application('vproto')
	fp.version('v0.0.1')
	fp.description('V protocol buffers parser')

	fp.skip_executable()

	args.filename = fp.string('filename', `f`, '', 'Filename of proto to parse')
	args.out_folder = fp.string('out_dir', `o`, '', 'Output folder of V file')

	im := fp.string_multi('import', `i`, 'Add a directory to imports')

	args.imports << im

	args.quiet = fp.bool('quiet',`q`, false, 'Supress warnings and messages')

	// TODO revert when vlang #5039 is fixed
	additional := fp.finalize() or { []string{} }

	args.additional = additional

	return args
}

fn format_file(path string) {
	table := table.new_table()
	ast_file := parser.parse_file(path, table, .parse_comments, &pref.Preferences{}, &ast.Scope{
		parent: 0
	})

	result := fmt.fmt(ast_file, table, false)

	os.write_file(path, result)
}

fn main() {
	args := parse_args()

	println(args.imports)

	if args.filename == '' {
		println(args.fp.usage())
		return
	}

	if !os.is_dir(args.out_folder) {
		println('Output path does not exist')
		return
	}

	mut p := compiler.Parser{file_inputs: [args.filename], imports: args.imports, quiet: args.quiet, type_table: &compiler.TypeTable{}}

	println('Before parsing')

	p.parse()

	println('Parsing completed')

	p.validate()

	mut g := compiler.new_gen(&p)

	for _, f in p.files[..1] {
		filename := os.real_path(f.filename).all_after_last(os.path_separator).all_before_last('.') + '.pb.v'

		path := os.join_path(os.real_path(args.out_folder), filename)

		println('$path')

		os.write_file(path, g.gen_file_text(f))
		format_file(path)
	}
}
