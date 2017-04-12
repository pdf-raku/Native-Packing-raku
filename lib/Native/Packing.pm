use NativeCall;
use NativeCall::Types;

my enum Native::Packing::Endian is export(:Endian) <Network Vax>;

role Native::Packing {
    my constant HostIsNetworkEndian = do {
        my $i = CArray[uint16].new(0x1234);
        my $j = nativecast(CArray[uint16], $i);
        $i[0] == 0x12;
    }

    my constant HostEndian = HostIsNetworkEndian
        ?? Network !! Vax;

    method host-endian {
        HostEndian
    }

    multi sub unpack-foreign-attribute(Int $type, Buf $buf, uint $off is rw) {
        my uint $byte-count = $type.^nativesize div 8;
        my buf8 $native .= new: $buf.subbuf($off, $byte-count).reverse;
        $off += $byte-count;
        my $cval = nativecast(CArray[$type], $native);
        $cval[0];
    }

    #| convert between differing architectures
    method unpack-foreign(\buf) {
        # ensure we're working at the byte level
        my uint $off = 0;
        my %args = self.^attributes.map: {
            my $type = .type;
            my str $name = .name.substr(2);
            $name => unpack-foreign-attribute($type, buf, $off);
        }
        self.new(|%args);
    }

    multi sub read-foreign-attribute(Int $type, IO::Handle \fh) {
        my uint $byte-count = $type.^nativesize div 8;
        my $native = CArray[uint8].new: fh.read($byte-count).reverse;
        my $cval = nativecast(CArray[$type], $native);
        $cval[0];
    }

    #| convert between differing architectures
    method read-foreign(IO::Handle \fh) {
        # ensure we're working at the byte level
        my %args = self.^attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
           
            $name => read-foreign-attribute($type, fh);
        }
        self.new(|%args);
    }

    multi sub unpack-host-attribute(Int $type, Buf $buf, uint $off is rw) {
        my uint $byte-count = $type.^nativesize div 8;
        my Buf $raw = $buf.subbuf($off, $byte-count);
        my $cval = nativecast(CArray[$type], $raw);
        $off += $byte-count;
        $cval[0];
    }

    #| matching architecture - straight copy
    method unpack-host(\buf) {
        # ensure we're working at the byte level
        my uint $off = 0;
        my %args = self.^attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
            $name => unpack-host-attribute($type, buf, $off);
        }
        self.new(|%args);
    }

    multi sub read-host-attribute(Int $type, IO::Handle \fh) {
        my uint $byte-count = $type.^nativesize div 8;
        my buf8 $raw = fh.read( $byte-count);
        my $cval = nativecast(CArray[$type], $raw);
        $cval[0];
    }

    #| matching architecture - straight copy
    method read-host(\fh) {
        # ensure we're working at the byte level
        my %args = self.^attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
            $name => read-host-attribute($type, fh);
        }
        self.new(|%args);
    }

    multi sub pack-foreign-attribute(Int $type, Buf $buf, $val) {
        my uint $byte-count = $type.^nativesize div 8;
        my $cval = CArray[$type].new;
        $cval[0] = $val;
        my $bytes = nativecast(CArray[uint8], $cval);
        loop (my int $i = 1; $i <= $byte-count; $i++) {
            $buf.append: $bytes[$byte-count - $i];
        }
    }

    #| convert between differing architectures
    method pack-foreign {
        # ensure we're working at the byte level
        my buf8 $buf .= new;
        my uint $off = 0;
        for self.^attributes {
            my $type = .type;
            my str $name = .name.substr(2);
            my $val = self."$name"();
            pack-foreign-attribute($type, $buf,  $val);
        }
        $buf;
    }

    #| convert between differing architectures
    method write-foreign($fh) {
        $fh.write: self.pack-foreign;
    }

    multi sub pack-host-attribute(Int $type, Buf $buf, $val) {
        my uint $byte-count = $type.^nativesize div 8;
        my $cval = CArray[$type].new;
        $cval[0] = $val;
        my $bytes = nativecast(CArray[uint8], $cval);
        loop (my int $i = 0; $i < $byte-count; $i++) {
            $buf.append: $bytes[$i];
        }
    }

    method pack-host {
        # ensure we're working at the byte level
        my buf8 $buf .= new;
        my uint $off = 0;
        for self.^attributes {
            my $type = .type;
            my str $name = .name.substr(2);
            my $val = self."$name"();
            pack-host-attribute($type, $buf,  $val);
        }
        $buf;
    }

    #| convert between differing architectures
    method write-host($fh) {
        $fh.write: self.pack-host;
    }

}

role Native::Packing[Native::Packing::Endian $endian]
    does Native::Packing {

    method unpack(\buf) {
        $endian == self.host-endian
            ?? self.unpack-host(buf)
            !! self.unpack-foreign(buf)
    }

    method read(\fh) {
        $endian == self.host-endian
            ?? self.read-host(fh)
            !! self.read-foreign(fh)
    }

    method pack {
        $endian == self.host-endian
            ?? self.pack-host
            !! self.pack-foreign
    }

    method write(\fh) {
        $endian == self.host-endian
            ?? self.write-host(fh)
            !! self.write-foreign(fh)
    }

}


