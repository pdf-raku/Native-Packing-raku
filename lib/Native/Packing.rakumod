use v6;
use NativeCall;
use NativeCall::Types;

=begin pod

=head1 NAME

Native::Packing

=head1 DESCRIPTION

This module provides a role for binary serialization of simple structs. At this stage, only scalar native integer and numeric attributes are supported.

This role is applicable to classes that contain only simple native numeric
attributes, representing the structure of the data.

=head1 EXAMPLE

    use v6;
    use Native::Packing :Endian;

    # open a GIF read the 'screen' header
    my class GifHeader
        does Native::Packing[Endian::Vax] {
        has uint16 $.width;
        has uint16 $.height;
        has uint8 $.flags;
        has uint8 $.bgColorIndex;
        has uint8 $.aspect;
    }

    my $fh = "t/lightbulb.gif".IO.open( :r :bin);
    $fh.read(6);  # skip GIF header

    my GifHeader $screen .= read: $fh;

    say "GIF has size {$screen.width} X {$screen.height}";

=head1 METHODS

=head2 unpack(buf8)

Class level method. Unpack bytes from a buffer. Create a struct object.

=head2 pack(buf8?)

Object level method. Serialize the object to a buffer.

=head2 read(fh)

Class level method. Read data from a binary file. Create an object.

=head2 write(fh)

Object level method. Write the object to a file

=head2 bytes

Determine the overall size of the struct. Sum of all its attributes.

=head2 host-endian

Return the endian of the host Endian::Network(0) or Endian::Vax(1).

=end pod

my enum Native::Packing::Endian is export(:Endian) <Network Vax Host>;

role Native::Packing:ver<0.0.6> {

    sub detect-host-endian {
        my $i = CArray[uint16].new(0x1234);
        my $j = nativecast(CArray[uint8], $i);
        if $j[0] == 0x12 {
            warn "unexpected high byte: $j[1]"
                unless $j[1] == 0x34;
            Network
        } else {
            warn "unexpected byte order: {$j>>.fmt('0x%X').join(',')}"
                unless $j[0] == 0x34 && $j[1] == 0x12;
            Vax;
        }
    }

    my constant HostEndian = detect-host-endian();

    method host-endian { HostEndian }

    multi sub unpack-foreign-attribute(Native::Packing $sub-rec, Buf $buf, UInt $off is rw) {
        my $bytes := $sub-rec.bytes;
        my $v := $sub-rec.unpack($buf.subbuf($off, $bytes));
        $off += $bytes;
        $v;
    }

    multi sub unpack-foreign-attribute($type, Buf $buf, UInt $off is rw) is default {
        my uint $byte-count = nativesizeof($type);
        my buf8 $native .= new: $buf.subbuf($off, $byte-count).reverse;
        $off += $byte-count;
        my $cval = nativecast(CArray[$type], $native);
        $cval[0];
    }

    sub storage-atts($class, :%pos, :@atts) {
        storage-atts($_, :%pos, :@atts) for $class.^parents;
        for $class.^attributes(:local) -> $att {
            my $name := $att.name;
            with %pos{$name} {
                @atts[$_] = $att;
            }
            elsif $name {
                %pos{$name} = +@atts;
                @atts.push: $att;
            }
        }
        @atts;
    }
    method !attributes {
        storage-atts(self.WHAT);
    }

    # convert between differing architectures
    method unpack-foreign(\buf, UInt :$offset is copy = 0) {
        # ensure we're working at the byte level
        my %args = self!attributes.map: {
            my $type = .type;
            my str $name = .name.substr(2);
            $name => unpack-foreign-attribute($type, buf, $offset);
        }
        self.new(|%args);
    }

    multi sub read-foreign-attribute(Native::Packing $sub-rec, \fh) {
        $sub-rec.read(fh);
    }

    multi sub read-foreign-attribute($type, \fh) is default {
        my uint $byte-count = nativesizeof($type);
        my $native = CArray[uint8].new: fh.read($byte-count).reverse;
        my $cval = nativecast(CArray[$type], $native);
        $cval[0];
    }

    # convert between differing architectures
    method read-foreign(\fh) {
        # ensure we're working at the byte level
        my %args = self!attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
            $name => read-foreign-attribute($type, fh);
        }
        self.new(|%args);
    }

    multi sub unpack-host-attribute(Native::Packing $sub-rec, Buf $buf, UInt $off is rw) {
        my $bytes := $sub-rec.bytes;
        my $v := $sub-rec.unpack($buf.subbuf($off, $bytes));
        $off += $bytes;
        $v;
    }

    multi sub unpack-host-attribute($type, Buf $buf, UInt $off is rw) is default {
        my uint $byte-count = nativesizeof($type);
        my Buf $raw = $buf.subbuf($off, $byte-count);
        my $cval = nativecast(CArray[$type], $raw);
        $off += $byte-count;
        $cval[0];
    }

    # matching architecture - straight copy
    method unpack-host(\buf, UInt :$offset is copy = 0) {
        # ensure we're working at the byte level
        my %args = self!attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
            $name => unpack-host-attribute($type, buf, $offset);
        }
        self.new(|%args);
    }

    multi sub read-host-attribute(Native::Packing $sub-rec, \fh) {
        $sub-rec.read(fh);
    }

    multi sub read-host-attribute($type, \fh) is default {
        my uint $byte-count = nativesizeof($type);
        my buf8 $raw = fh.read( $byte-count);
        my $cval = nativecast(CArray[$type], $raw);
        $cval[0];
    }

    # matching architecture - straight copy
    method read-host(\fh) {
        # ensure we're working at the byte level
        my %args = self!attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
            $name => read-host-attribute($type, fh);
        }
        self.new(|%args);
    }

    multi sub pack-foreign-attribute(Native::Packing $, Buf $buf, Native::Packing $sub-rec) {
        $sub-rec.pack($buf);
    }

    multi sub pack-foreign-attribute($type, Buf $buf, $val) is default {
        my uint $byte-count = nativesizeof($type);
        my $cval = CArray[$type].new;
        $cval[0] = $val;
        my $bytes = nativecast(CArray[uint8], $cval);
        loop (my int $i = 1; $i <= $byte-count; $i++) {
            $buf.append: $bytes[$byte-count - $i];
        }
        $buf;
    }

    # convert between differing architectures
    method pack-foreign(buf8 $buf = buf8.new) {
        my $pad = 0 without self;
        for self!attributes {
            my $val = $pad // .get_value(self);
            pack-foreign-attribute(.type, $buf, $val);
        }
        $buf;
    }

    # convert between differing architectures
    method write-foreign($fh) {
        $fh.write: self.pack-foreign;
    }

    multi sub pack-host-attribute(Native::Packing $, Buf $buf, Native::Packing $sub-rec) {
        $sub-rec.pack($buf);
    }

    multi sub pack-host-attribute($type, Buf $buf, $val) is default {
        my uint $byte-count = nativesizeof($type);
        my $cval = CArray[$type].new;
        $cval[0] = $val;
        my $bytes = nativecast(CArray[uint8], $cval);
        loop (my int $i = 0; $i < $byte-count; $i++) {
            $buf.append: $bytes[$i];
        }
        $buf;
    }

    method pack-host(buf8 $buf = buf8.new) {
        my $pad = 0 without self;
        for self!attributes {
            my $val = $pad // .get_value(self);
            pack-host-attribute(.type, $buf, $val);
        }
        $buf;
    }

    # convert between differing architectures
    method write-host($fh) {
        $fh.write: self.pack-host;
    }

    method bytes {
        [+] self!attributes.map: {
            given .type {
                when Native::Packing { .bytes }
                default { nativesizeof($_) }
            }
        }
    }
}

role Native::Packing[Native::Packing::Endian $endian]
    does Native::Packing {

    method unpack(\buf, UInt :$offset = 0) {
        $endian == self.host-endian | Host
            ?? self.unpack-host(buf, :$offset)
            !! self.unpack-foreign(buf, :$offset)
    }

    method read(\fh, UInt :$offset) {
        fh.read($_) with $offset;
        $endian == self.host-endian | Host
            ?? self.read-host(fh)
            !! self.read-foreign(fh)
    }

    method pack($buf = buf8.new) {
        $endian == self.host-endian | Host
            ?? self.pack-host($buf)
            !! self.pack-foreign($buf)
    }

    method write(\fh) {
        $endian == self.host-endian | Host
            ?? self.write-host(fh)
            !! self.write-foreign(fh)
    }

}


