perl6-Native-Packing
===============

## Description

Native::Packing is a simple solution for structured reading
and writing of binary data.

## Example

```
use v6;
use Native::Packing :Endian;

# open a GIF read the header
my class LogicalDescriptor
    does Native::Packing[Endian::Vax] {
    has uint16 $.width;
    has uint16 $.height;
    has uint8 $.flags;
    has uint8 $.bgColorIndex;
    has uint8 $.aspect;
}

my $fh = "t/lightbulb.gif".IO.open( :r :bin);

my LogicalDescriptor $screen .= read: $fh;

say "GIF has size {$screen.width} X {$screen.height}";
```

## Description

This module is a simple solution for the reading and writing
or serialization of binary structures. It currently handles records
that are comprised of natives integers (int8, uint8, int16, etc) and
numerics (num32, num64).

This module provides `read` and `write` methods for reading and
writing data to binary files and `unpack` and `pack` methods.

## Endianess

This defines the order of bytes in multibyte quantitys. There are two modes for binary
formats:

- Network (little endian) - least significant byte on the right
- Vax (big endian) - least significant byte on the right

You will need to determine the endianess of the binary format to correctly
read and write it.

There is also a `Host` mode. This will read and write binary data in the
same endiness as the host computer.

Examples:

```
use Native::Packing :Endian;
class C { has int16 $.a }
my $c = C.new: :a(42);
say ($c but Native::Packing[Vax]).pack;     # Buf[uint8]:0x<2a 00>
say ($c but Native::Packing[Network]).pack; # Buf[uint8]:0x<00 2a>
say ($c but Native::Packing[Host]).pack;    # Depends on your host

```

