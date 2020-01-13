module main

import flag
import os
import filepath

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

	args.filename = fp.string('filename', '', 'Filename of proto to parse')
	args.out_folder = fp.string('out_dir', '', 'Output folder of V file')

	im := fp.string_multi('import', `i`, 'Add a directory to imports')

	args.imports << im

	args.quiet = fp.bool('quiet', false, 'Supress warnings and messages')

	args.additional = fp.finalize() or {
		// Just make sure we get a usage message
		return Args{fp: fp}
	}

	return args
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

	mut p := compiler.Parser{file_inputs: [args.filename], imports: args.imports, quiet: args.quiet}

	p.parse()
	p.validate()

	mut g := compiler.new_gen(&p)

	for _, f in p.files[..1] {
		filename := os.realpath(f.filename).all_after(os.path_separator).all_before_last('.') + '.pb.v'

		path := filepath.join(os.realpath(args.out_folder), filename)

		println('$path')

		os.write_file(path, g.gen_file_text(f))
		// println('$f.filename:\n=====\n${g.gen_file_text(f)}')
	}
}
