# protoc-v

This is the compiler code for [vproto](https://github.com/emily33901/vproto).

vproto can parse most (or maybe all...) of the proto2 spec. It compiles the [Steam Protobufs](https://github.com/SteamDatabase/Protobufs) generating valid code and also parses the `protoc` plugin protobufs (which can be found in `plugin/google/protobuf`). It can parse options, extensions, map fields and extends definitions but does not generate relevent code for it.


## Usage

```
vproto v0.0.1
-----------------------------------------------
Usage: vproto [options] [ARGS]

Description:
V protocol buffers parser

Options:
  -f, --filename <string>   Filename of proto to parse
  -o, --out_dir <string>    Output folder of V file
  -i, --import <multiple strings>
                            Add a directory to imports
  -q, --quiet               Supress warnings and messages

```