# Janet Language Server

## Building

### Building for Linux

```shell
jpm clean && jpm build --lflags=-export-dynamic
```

`export-dynamic` is required for the server to load arbitrary Janet native
modules when it evaluates user documents. Otherwise the symbols for Janet would
not be visible to the newly loaded modules and they would fail to load.

### Building for Windows

```
"c:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x64
```

```shell
jpm clean && jpm build --lflags=/OPT:NOREF
```

## Installing

The following command should copy the `janet-language-server` binary to a location that can be executed via the command line.

```
jpm install
```

