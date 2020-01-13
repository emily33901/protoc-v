# protoc-v

This is the compiler code for [vproto](https://github.com/emily33901/vproto).

vproto can parse most (or maybe all...) of the proto2 spec. It compiles the [Steam Protobufs](https://github.com/SteamDatabase/Protobufs) properly. It can parse options, extensions and extends definitions but does not generate relevent code for it.

Right now it uses module main for all generated file but at some point that will be assigned to either a protobuf option or a command line option or maybe by the package declaration in protobuf.

## Usage

```
vproto --filename file.proto --out_dir output/ --import xyz/ --import abc/
```