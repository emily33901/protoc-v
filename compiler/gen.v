module compiler

// TODO this file needs a massive refactor and clean
// So much code just everywhere with functions that dont
// make any sense
// Please just fix it before its too late...

// Other things that would be nice

// Functions for getting names / types consistently
// instead of manually creating m_name and m_full_name
// in each of the places that they are used!

struct Gen {
	type_table &TypeTable

	w Writer

mut: 
	current_package string
}

fn (mut g Gen) gen_file_header(f &File) {
	// TODO figure out an appropriate module
	// if the file doesnt have an explicit package set

	g.w.l('
// Generated by vproto - Do not modify
module main

import vproto

pub const (
	v_package = \'$g.current_package\'
)
')
}

fn (mut g Gen) gen_enum_definition(type_context []string, e &Enum) {
	names := message_names(type_context, e.name)
	
	e_name := names.struct_name
	e_full_name := names.lowercase_name

	g.w.l('enum ${e_name} {')

	for _, field in e.fields {
		g.w.l('${to_v_field_name(field.name)} = $field.value.value')
	}

	g.w.l('}')

	// generate packing and unpacking functions

	g.w.l('fn pack_${e_full_name}(e $e_name, num u32) []byte {')
	g.w.l('return vproto.pack_int32_field(int(e), num)')
	g.w.l('}')

	g.w.l('fn unpack_${e_full_name}(buf []byte, tag_wiretype vproto.WireType) (int, $e_name) {')
	g.w.l('i, v := vproto.unpack_int32_field(buf, tag_wiretype)')
	g.w.l('return i, ${e_name}(v)')
	g.w.l('}')

	// TODO helper functions here 
	// https://developers.google.com/protocol-buffers/docs/reference/cpp-generated#enum
}

// TODO When type_to_type changes name change this name too ! 
fn (mut g Gen) type_to_type(context []string, t string) (string, TypeType) {
	mut full_context := [g.current_package]
	full_context << context

	// TODO revert when vlang #5028 is resolved
	x, y := type_to_type(g.current_package, g.type_table, full_context, t)


	return x, y
}

fn (g &Gen) type_pack_name(pack_or_unpack string, field_proto_type string, field_v_type string, field_type_type TypeType) string {
	match field_type_type {
		.other {
			match field_proto_type {
				'fixed32' {
					return 'vproto.${pack_or_unpack}_32bit_field'
				}

				'sfixed32' {
					return 'vproto.${pack_or_unpack}_s32bit_field'
				}

				'float' {
					return 'vproto.${pack_or_unpack}_float_field'
				}

				'fixed64' {
					return 'vproto.${pack_or_unpack}_64bit_field'
				}

				'sfixed64' {
					return 'vproto.${pack_or_unpack}_s64bit_field'
				}

				'double' {
					return 'vproto.${pack_or_unpack}_double_field'
				}

				'int32' {
					return 'vproto.${pack_or_unpack}_int32_field'
				}

				'sint32' {
					return 'vproto.${pack_or_unpack}_sint32_field'
				}

				'sint64' {
					return 'vproto.${pack_or_unpack}_sint64_field'
				}

				'uint32' {
					return 'vproto.${pack_or_unpack}_uint32_field'
				}

				'int64' {
					return 'vproto.${pack_or_unpack}_int64_field'
				}

				'uint64' {
					return 'vproto.${pack_or_unpack}_uint64_field'
				}

				'bool' {
					return 'vproto.${pack_or_unpack}_bool_field'
				}

				'string' {
					return 'vproto.${pack_or_unpack}_string_field'
				}

				'bytes' {
					return 'vproto.${pack_or_unpack}_bytes_field'
				}

				else {
					panic('unknown type `$field_proto_type`')
				}
			}
		}

		.enum_, .message {
			return '${pack_or_unpack}_$field_v_type'
		}
	}
}

fn (g &Gen) gen_field_pack_text(label string, field_proto_type string, field_v_type string, field_TypeType TypeType, name, number string) (string, string) {
	// This needs to be fixed up so that the indentation is on the correct level!

	mut pack_text := ''
	mut unpack_text := ''

	match label {
		'optional', 'required' {
			pack_inside := g.type_pack_name('pack', field_proto_type, field_v_type, field_TypeType)
			unpack_inside := g.type_pack_name('unpack', field_proto_type, field_v_type, field_TypeType)

			unpack_text += '$number {\n'

			if label == 'optional' {
				pack_text += 'if o.has_$name {\n'

				unpack_text += 'res.has_$name = true\n'
			}

			pack_text += 'res << ${pack_inside}(o.$name, $number)\n'

			if label == 'optional' {
				pack_text += '}\n'
			}

			// unpack text at this point is inside of a match statement checking tag numbers

			// TODO make this into a oneliner again once match bug is fixed

			unpack_text += 'ii, v := ${unpack_inside}(cur_buf, tag_wiretype.wire_type)\n'
			unpack_text += 'res.$name = v\n'
			unpack_text += 'i = ii\n'
			unpack_text += '}\n'
		}
 
		'repeated' {
			pack_inside := g.type_pack_name('pack', field_proto_type, field_v_type[1..], field_TypeType)
			unpack_inside := g.type_pack_name('unpack', field_proto_type, field_v_type[1..], field_TypeType)

			// TODO we need to handle the packed case here aswell!
			pack_text += 'for _, x in o.$name {\n'
			pack_text += 'res << ${pack_inside}(x, $number)\n'
			pack_text += '}\n'

			unpack_text += '$number {\n'
			unpack_text += 'ii, v := ${unpack_inside}(cur_buf, tag_wiretype.wire_type)\n'
			unpack_text += 'res.$name << v\n'
			unpack_text += 'i = ii\n'
			unpack_text += '}\n'
		}

		else {
			// This should never happen...
			println('Unknown label $label')
		}
	}

	return pack_text, unpack_text
}

fn (mut g Gen) gen_message_internal(type_context []string, m &Message) {
	// m_names := type_to_names(m.typ)

	// TODO replace with message_namess
	m_name := to_v_message_name(type_context, m.name)
	m_full_name := (type_context.join('') + m.name).to_lower()

	mut this_type_context := type_context.clone()
	this_type_context << m.name

	// Generate for submessages
	for _, sub in m.messages {
		g.gen_message_internal(this_type_context, sub)
	}
	
	// Generate for subenums
	for _, sub in m.enums {
		g.gen_enum_definition(this_type_context, sub)
	}

	pack_unpack_mut := if m.fields.len > 0 {
		'mut '
	} else {
		''
	}

	mut field_pack_text := new_writer()
	mut field_unpack_text := new_writer()

	field_pack_text.l('pub fn (o &$m_name) pack() []byte {')
	field_pack_text.l('${pack_unpack_mut}res := []byte{}') // TODO allocate correct size statically
	
	field_unpack_text.l('pub fn ${m_full_name}_unpack(buf []byte) ?$m_name {')
	field_unpack_text.l('${pack_unpack_mut}res := $m_name{}')

	if m.fields.len > 0 {
		field_unpack_text.l('mut total := 0')
		field_unpack_text.l('for total < buf.len {')
		field_unpack_text.l('mut i := 0')
		field_unpack_text.l('buf_before_wire_type := buf[total..]')
		field_unpack_text.l('tag_wiretype := vproto.unpack_tag_wire_type(buf_before_wire_type) or { return error(\'malformed protobuf (couldnt parse tag & wire type)\') }')
		field_unpack_text.l('cur_buf := buf_before_wire_type[tag_wiretype.consumed..]')
		field_unpack_text.l('match tag_wiretype.tag {')
	}

	g.w.l('pub struct $m_name {')

	g.w.l('mut:')
	g.w.l('unknown_fields []vproto.UnknownField')

	if m.fields.len > 0 {
		g.w.l('pub mut:')
	}

	for _, field in m.fields {
		field_type, field_type_type := g.type_to_type(field.type_context, field.t)
		name := escape_name(field.name)

		if field.label == 'optional' {
			g.w.l('${name} ${field_type}')
			g.w.l('has_${name} bool')

		} else if field.label == 'required' {
			g.w.l('${name} ${field_type}')
		} else if field.label == 'repeated' {
			g.w.l('${name} []${field_type}')
		}

		// Seperate fields nicer
		g.w.l('')

		mut pack_text := ''
		mut unpack_text := ''

		if field_type_type == .enum_ || field_type_type == .message {
			names := message_names([], field.t)
			// n := (field.type_context.join('') + names.lowercase_name).to_lower()
			pack_text, unpack_text = g.gen_field_pack_text(field.label, field.t, names.lowercase_name, field_type_type, name, field.number)
		} else {
			pack_text, unpack_text = g.gen_field_pack_text(field.label, field.t, field_type, field_type_type, name, field.number)
		}

		field_pack_text.l(pack_text)
		field_unpack_text.l(unpack_text)
	}

	// TODO oneofs maps extensions and similar

	g.w.l('}')

	field_pack_text.l('return res')
	field_pack_text.l('}')

	if m.fields.len > 0 {
		// close match then for then func
		field_unpack_text.l('else {')
		field_unpack_text.l('ii, v := vproto.unpack_unknown_field(cur_buf, tag_wiretype.wire_type)')
		field_unpack_text.l('res.unknown_fields << vproto.UnknownField{tag_wiretype.wire_type, tag_wiretype.tag, v}')
		field_unpack_text.l('i = ii')
		field_unpack_text.l('}')
		field_unpack_text.l('}')

		// TODO we need to actually implement parsing of unknown fields otherwise this will
		// always trigger if we hit one
		field_unpack_text.l('if i == 0 { return error(\'malformed protobuf (didnt unpack a field)\') }')
		field_unpack_text.l('total += tag_wiretype.consumed + i')
		field_unpack_text.l('}')
	}
	field_unpack_text.l('return res')
	field_unpack_text.l('}')

	// Function for creating a new of that message

	g.w.l('pub fn new_${m_full_name}() $m_name {')
	g.w.l('return $m_name{}')
	g.w.l('}')

	g.w.l(field_pack_text.text())
	g.w.l(field_unpack_text.text())

	// pack and unpack wrappers for when its called as a submessage
	g.w.l('fn pack_${m_full_name}(o $m_name, num u32) []byte {')
	g.w.l('return vproto.pack_message_field(o.pack(), num)')
	g.w.l('}')
	
	g.w.l('fn unpack_${m_full_name}(buf []byte, tag_wiretype vproto.WireType) (int, $m_name) {')
	g.w.l('i, v := vproto.unpack_message_field(buf, tag_wiretype)')
	g.w.l('unpacked := ${m_full_name}_unpack(v) or { panic(\'\') }')
	g.w.l('return i, unpacked')
	g.w.l('}')

	// TODO oneof, maps and similar
}

pub fn (mut g Gen) gen_file_text(f &File) string {
	g.current_package = f.package
	g.gen_file_header(f)

	for _, e in f.enums {
		g.gen_enum_definition([], e)
	}

	// Then generate the actual structs that back the messages
	for _, m in f.messages {
		g.gen_message_internal([], m)
	}

	return g.w.text()
}

pub fn new_gen(p &Parser) Gen {
	return Gen{type_table: p.type_table, w: new_writer()}
}