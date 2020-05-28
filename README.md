# protoc-v

This is the compiler code for [vproto](https://github.com/emily33901/vproto).

vproto can parse most (or maybe all...) of the proto2 spec. It compiles the [Steam Protobufs](https://github.com/SteamDatabase/Protobufs) properly. It can parse options, extensions and extends definitions but does not generate relevent code for it.

## Usage

```
vproto --filename file.proto --out_dir output/ --import xyz/ --import abc/
```

## Other notes
Because imported files are parsed after the file that they are imported from you may (almost certainly)
end up with silly `unable to find type` errors which whilst are true at the time of parsing may not be
at the time of generating V code becuase the compiler is straight up lying to you. 

This will be fixed in a later update.