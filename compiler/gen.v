module compiler

// TODO this file needs a massive refactor and clean
// So much code just everywhere with functions that dont
// make any sense
// Please just fix it before its too late...

// Other things that would be nice

// Functions for getting names / types consistently
// instead of manually creating m_name and m_full_name
// in each of the places that they are used!

import strings

struct Gen {
	type_table &TypeTable

mut: 
	text strings.Builder
	syntax ProtoSyntax

	// Maps proto packages to v packages
	package_lookup map[string]string

	current_package string

}

fn (mut g Gen) gen_file_header(f &File) {

	mod := if f.package_override != '' {
		f.package_override
	} else {
		f.package
	}

	g.text.writeln('
// Generated by vproto - Do not modify
module ${mod}

import emily33901.vproto

')

	for _, i in f.imports {
		x := i.package
		pkg := g.package_lookup[x]
		if pkg == '' {
			continue
		}
		g.text.writeln('import $pkg')
	}

// g.text.writeln('
// pub const (
// 	v_package = \'$g.current_package\'
// )')

}

fn (mut g Gen) gen_enum_definition(type_context []string, e &Enum) {
	names := g.message_names(type_context, e.name)
	
	e_name := names.struct_name
	e_full_name := names.lowercase_name

	g.text.writeln('enum ${e_name} {')

	for _, field in e.fields {
		escaped_name := escape_name(to_v_field_name(field.name))
		g.text.writeln('$escaped_name = $field.value.value')
	}

	g.text.writeln('}')

	// generate packing and unpacking functions

	g.text.writeln('fn pack_${e_full_name}(e $e_name, num u32) []byte {')
	g.text.writeln('return vproto.pack_int32_field(int(e), num)')
	g.text.writeln('}')

	g.text.writeln('fn unpack_${e_full_name}(buf []byte, tag_wiretype vproto.WireType) (int, $e_name) {')
	g.text.writeln('i, v := vproto.unpack_int32_field(buf, tag_wiretype)')
	g.text.writeln('return i, ${e_name}(v)')
	g.text.writeln('}')

	// TODO helper functions here 
	// https://developers.google.com/protocol-buffers/docs/reference/cpp-generated#enum
}

// TODO When type_to_type changes name change this name too ! 
fn (mut g Gen) type_to_typename(context []string, t string) (string, TypeType) {

	// mut full_context := []string{}
	// full_context << g.current_package.split('.')
	// full_context << context

	return type_to_typename(g.current_package, g.type_table, context, t)
}

fn (g Gen) message_names(context []string, t string) MessageNames {
	return message_names(g.current_package, g.type_table, context, t)
}

fn (g &Gen) type_pack_name(pack_or_unpack string, field_proto_type string, field_v_type string, field_type_type TypeType) string {
	// TODO clean up this whackness :(
	match field_type_type {
		.other, .scalar {
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

fn (g &Gen) gen_field_pack_text(
	label, field_proto_type, field_v_type string, 
	field_TypeType TypeType, 
	name, raw_name, number string, 
	is_packed bool
) (string, string) {
	mut pack := strings.new_builder(100)
	mut unpack := strings.new_builder(100)

	field_v_type_no_mod := field_v_type.all_after_last('.')
	field_v_type_mod := if field_v_type.contains('.') { field_v_type.all_before_last('.') + '.' } else { '' }

	pack_inside := g.type_pack_name('${field_v_type_mod}pack', field_proto_type, field_v_type_no_mod, field_TypeType)
	unpack_inside := g.type_pack_name('${field_v_type_mod}unpack', field_proto_type, field_v_type_no_mod, field_TypeType)

	match label {
		'optional', 'required' {
			unpack.writeln('$number {')

			if label == 'optional' {
				pack.writeln('if o.has_$raw_name {')

				unpack.writeln('res.has_$raw_name = true')
			}

			pack.writeln('res << ${pack_inside}(o.$name, $number)')

			if label == 'optional' {
				pack.writeln('}')
			}

			// unpack text at this point is inside of a match statement checking tag numbers

			// TODO make this into a oneliner again once match bug is fixed

			unpack.writeln('ii, v := ${unpack_inside}(cur_buf, tag_wiretype.wire_type)')
			unpack.writeln('res.$name = v')
			unpack.writeln('i = ii')
			unpack.writeln('}')
		}
 
		'repeated' {
			if !is_packed {
				pack.writeln('// [packed=false]')
				pack.writeln('for _, x in o.$name {')
				pack.writeln('res << ${pack_inside}(x, $number)')
				pack.writeln('}')

				unpack.writeln('$number {')
				unpack.writeln('// [packed=false]')
				unpack.writeln('ii, v := ${unpack_inside}(cur_buf, tag_wiretype.wire_type)')
				unpack.writeln('res.$name << v')
				unpack.writeln('i = ii')
				unpack.writeln('}')
			} else {
				pack.writeln('// [packed=true]')
				pack.writeln('res << ${pack_inside}_packed(o.$name, $number)')
				
				unpack.writeln('$number {')
				unpack.writeln('// [packed=true]')
				unpack.writeln('ii, v := ${unpack_inside}_packed(cur_buf, tag_wiretype.wire_type)')
				unpack.writeln('res.$name << v')
				unpack.writeln('i = ii')
				unpack.writeln('}')
			}
		}

		else {
			// This should never happen...
			println('Unknown label $label')
		}
	}

	return pack.str(), unpack.str()
}

fn key_default_value(v_type string) string {
	match v_type {
		'string' {
			return '\'\''
		}

		'[]byte' {
			// Keys cant be this type but value_default_value uses this for
			// its .other case
			return '[]byte{}'
		}

		else {
			return '${v_type}(0)'
		}
	}
}

fn value_default_value(v_type string, type_type TypeType) string {
	match type_type {
		.other {
			return key_default_value(v_type)
		}

		else {
			return 'new_${v_type}()'
		}
	}
}

fn (g &Gen) gen_map_field_pack_text(
	key_proto_type, key_v_type, value_proto_type, value_v_type string,
	value_type_type TypeType, 
	name, number string
) (string, string){
	// TODO this isnt ideal

	value_v_type_no_mod := value_v_type.all_after_last('.')
	value_v_type_mod := if value_v_type.contains('.') { value_v_type.all_before_last('.') + '.' } else { '' }

	value_pack_inside := g.type_pack_name('${value_v_type_mod}pack', value_proto_type, value_v_type_no_mod, value_type_type)
	value_unpack_inside := g.type_pack_name('${value_v_type_mod}unpack', value_proto_type, value_v_type_no_mod, value_type_type)

	key_pack_inside := g.type_pack_name('pack', key_proto_type, key_v_type, .other)
	key_unpack_inside := g.type_pack_name('unpack', key_proto_type, key_v_type, .other)

	mut pack := strings.new_builder(100)
	mut unpack := strings.new_builder(100)
	// Essentially the same as a repeated field of a message
	// where the message first contains the key
	// and then the value
	pack.writeln(
		'for k, v in o.$name {
			mut bytes := ${key_pack_inside}(k, 1)
			bytes << ${value_pack_inside}(v, 2)
			res << vproto.pack_bytes_field(bytes, $number)
		}'
	)

	unpack.writeln(
		'$number {
			ii, bytes := vproto.unpack_message_field(cur_buf, tag_wiretype.wire_type)
			mut k := ${key_default_value(key_v_type)}
			mut v := ${value_default_value(value_v_type, value_type_type)}
			mut bytes_offset := 0
			for j := 0; j < 2; j++ {
				map_tag_wiretype := vproto.unpack_tag_wire_type(bytes[bytes_offset..]) or { return error(\'malformed protobuf (couldnt parse tag & wire type)\') }
				match map_tag_wiretype.tag {
					1 {
						map_ii, kk := ${key_unpack_inside}(bytes[bytes_offset..],  map_tag_wiretype.wire_type)
						bytes_offset += map_ii
						k = kk
					}
					2 {
						map_ii, vv := ${value_unpack_inside}(bytes[bytes_offset..], map_tag_wiretype.wire_type) 
						bytes_offset += map_ii
						v = vv
					}
					else { 
						return error(\'malformed map field (didnt unpack a key/value)\')
					}
				}
			}
			res.$name[k] = v
			i = ii
		}'
	)

	return pack.str(), unpack.str()
}

fn (mut g Gen) gen_message_internal(type_context []string, m &Message) {
	m_names := g.message_names(type_context, m.name)

	m_name := m_names.struct_name
	m_full_name := m_names.lowercase_name

	// Generate for submessages
	for _, sub in m.messages {
		g.gen_message_internal(m_names.this_type_context, sub)
	}
	
	// Generate for subenums
	for _, sub in m.enums {
		g.gen_enum_definition(m_names.this_type_context, sub)
	}

	// TODO make sure to update this for oneofs and similar
	// when they are added
	has_fields := 0 < m.fields.len + m.map_fields.len

	pack_unpack_mut := if has_fields {
		'mut '
	} else {
		''
	}

	mut field_pack_text := strings.new_builder(100)
	mut field_unpack_text := strings.new_builder(100)

	field_pack_text.writeln('pub fn (o &$m_name) pack() []byte {')
	field_pack_text.writeln('${pack_unpack_mut}res := []byte{}') // TODO allocate correct size statically
	
	field_unpack_text.writeln('pub fn ${m_full_name}_unpack(buf []byte) ?$m_name {')
	field_unpack_text.writeln('${pack_unpack_mut}res := $m_name{}')

	if has_fields {
		field_unpack_text.writeln('mut total := 0
		for total < buf.len {
			mut i := 0
			buf_before_wire_type := buf[total..]
			tag_wiretype := vproto.unpack_tag_wire_type(buf_before_wire_type) or { return error(\'malformed protobuf (couldnt parse tag & wire type)\') }
			cur_buf := buf_before_wire_type[tag_wiretype.consumed..]
			match tag_wiretype.tag {')
	}

	g.text.writeln('pub struct $m_name {')

	g.text.writeln('mut:')
	g.text.writeln('unknown_fields []vproto.UnknownField')


	if has_fields {
		g.text.writeln('pub mut:')
	}

	for field in m.fields {
		// simple_context := simplify_type_context(field.type_context, type_context)
		// println('$type_context - $field.type_context = $simple_context')
		field_type, field_type_type := g.type_to_typename(field.type_context, field.t)

		name := escape_name(field.name)

		if field.label == 'optional' {
			g.text.writeln('${name} ${field_type}')
			g.text.writeln('has_${field.name} bool')

		} else if field.label == 'required' {
			g.text.writeln('${name} ${field_type}')
		} else if field.label == 'repeated' {
			g.text.writeln('${name} []${field_type}')
		}

		// in proto3 these are packed by default
		mut is_packed := g.syntax == .proto3 && field_type_type == .scalar

		if field.label == 'repeated' {
			for o in field.options {
				if o.ident == 'packed' {
					is_packed = o.value.value == 'true'
				}
			}
		}

		mut pack_text := ''
		mut unpack_text := ''

		if field_type_type == .enum_ || field_type_type == .message {
			names := g.message_names(field.type_context, field.t)

			// n := (field.type_context.join('') + names.lowercase_name).to_lower()
			pack_text, unpack_text = g.gen_field_pack_text(field.label, field.t, names.lowercase_name, field_type_type, name, field.name, field.number, is_packed)
		} else {
			pack_text, unpack_text = g.gen_field_pack_text(field.label, field.t, field_type, field_type_type, name, field.name, field.number, is_packed)
		}

		field_pack_text.writeln(pack_text)
		field_unpack_text.writeln(unpack_text)
	}

	for map_field in m.map_fields {
		mut key_type, _ := g.type_to_typename(map_field.type_context, map_field.key_type)
		value_type, value_type_type := g.type_to_typename(map_field.type_context, map_field.value_type)

		name := escape_name(map_field.name)

		// TODO revert when there is support for non-key types in maps!
		if key_type != 'string' {
			println('Warning: V doesnt support map keys that arent strings right now.\nThis will generate bad code!')
			key_type = 'string'
		}

		g.text.writeln('${name} map[$key_type]$value_type')

		mut pack_text := ''
		mut unpack_text := ''

		if value_type_type == .enum_ || value_type_type == .message {
			names := g.message_names(map_field.type_context, map_field.value_type)

			pack_text, unpack_text = g.gen_map_field_pack_text(map_field.key_type, key_type, map_field.value_type, names.lowercase_name, value_type_type, name, map_field.number)
		} else {
			pack_text, unpack_text = g.gen_map_field_pack_text(map_field.key_type, key_type, map_field.value_type, value_type, value_type_type, name, map_field.number)
		}

		field_pack_text.writeln(pack_text)
		field_unpack_text.writeln(unpack_text)
	}

	// TODO oneofs maps extensions and similar

	g.text.writeln('}')

	field_pack_text.writeln('return res')
	field_pack_text.writeln('}')

	if has_fields {
		// Try and match unknowns
		field_unpack_text.writeln('else {')
		field_unpack_text.writeln('ii, v := vproto.unpack_unknown_field(cur_buf, tag_wiretype.wire_type)')
		field_unpack_text.writeln('res.unknown_fields << vproto.UnknownField{tag_wiretype.wire_type, tag_wiretype.tag, v}')
		field_unpack_text.writeln('i = ii')
		field_unpack_text.writeln('}')
		field_unpack_text.writeln('}')

		field_unpack_text.writeln('if i == 0 { return error(\'malformed protobuf (didnt unpack a field)\') }')
		field_unpack_text.writeln('total += tag_wiretype.consumed + i')
		field_unpack_text.writeln('}')
	}
	field_unpack_text.writeln('return res')
	field_unpack_text.writeln('}')

	// Function for creating a new of that message

	g.text.writeln('pub fn new_${m_full_name}() $m_name {')
	g.text.writeln('return $m_name{}')
	g.text.writeln('}')

	g.text.writeln(field_pack_text.str())
	g.text.writeln(field_unpack_text.str())

	// pack and unpack wrappers for when its called as a submessage
	g.text.writeln('pub fn pack_${m_full_name}(o $m_name, num u32) []byte {')
	g.text.writeln('return vproto.pack_message_field(o.pack(), num)')
	g.text.writeln('}')
	
	g.text.writeln('pub fn unpack_${m_full_name}(buf []byte, tag_wiretype vproto.WireType) (int, $m_name) {')
	g.text.writeln('i, v := vproto.unpack_message_field(buf, tag_wiretype)')
	g.text.writeln('unpacked := ${m_full_name}_unpack(v) or { panic(\'\') }')
	g.text.writeln('return i, unpacked')
	g.text.writeln('}')

	// TODO oneof, maps and similar
}

pub fn (mut g Gen) gen_file_text(f &File) string {
	g.current_package = f.package
	g.syntax = f.syntax
	g.gen_file_header(f)

	for _, e in f.enums {
		g.gen_enum_definition([f.package], e)
	}

	// Then generate the actual structs that back the messages
	for _, m in f.messages {
		g.gen_message_internal([f.package], m)
	}

	return g.text.str()
}

pub fn new_gen(p &Parser) Gen {
	mut g := Gen{type_table: p.type_table, text: strings.new_builder(100)}

	for _, f in p.files {
		mod := f.package

		g.package_lookup[f.filename] = mod
	}

	return g
}