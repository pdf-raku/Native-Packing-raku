use NativeCall;
use NativeCall::Types;

my enum Native::Packing::Endian is export(:Endian) <Network Vax>;

role Native::Packing[Native::Packing::Endian $endian] {

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

    #| convert between differing architectures
    method unpack-foreign(\buf) {
        # ensure we're working at the byte level
        my $buf = nativecast(CArray[uint8], buf);
        my uint $off = 0;
        my %args = self.^attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
            my uint $byte-count = $type.^nativesize div 8;
            my buf8 $native .= new: buf.subbuf($off, $byte-count).reverse;
            $off += $byte-count;
            my $cval = nativecast(CArray[$type], $native);
            $name => $cval[0];
        };
        self.new(|%args);
    }

    #| convert between differing architectures
    method read-foreign(\fh) {
        # ensure we're working at the byte level
        my %args = self.^attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
            my uint $byte-count = $type.^nativesize div 8;
            my buf8 $native = fh.read($byte-count);
            my $cval = nativecast(CArray[$type], $native);
            $name => $cval[0];
        };
        self.new(|%args);
    }

    #| matching architecture - straight copy
    method unpack-host(\buf) {
        # ensure we're working at the byte level
        my $buf = nativecast(CArray[uint8], buf);
        my uint $off = 0;
        my %args = self.^attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
            my uint $byte-count = $type.^nativesize div 8;
            my Buf $raw = buf.subbuf($off, $byte-count);
            my $cval = nativecast(CArray[$type], $raw);
            $off += $byte-count;
            $name => $cval[0];
        }
        self.new(|%args);
    }

    #| matching architecture - straight copy
    method read-host(\fh) {
        # ensure we're working at the byte level
        my %args = self.^attributes.map: {
            my str $name = .name.substr(2);
            my $type = .type;
            my uint $byte-count = $type.^nativesize div 8;
            my buf8 $raw = fh.read( $byte-count);
            my $cval = nativecast(CArray[$type], $raw);
            $name => $cval[0];
        }
        self.new(|%args);
    }

    method unpack(\buf) {
        $endian == HostEndian
            ?? self.unpack-host(buf)
            !! self.unpack-foreign(buf)
    }

    method read(\fh) {
        $endian == HostEndian
            ?? self.read-host(fh)
            !! self.read-foreign(fh)
    }

    #| convert between differing architectures
    method pack-foreign {
        # ensure we're working at the byte level
        my buf8 $buf .= new;
        my uint $off = 0;
        for self.^attributes {
            my str $name = .name.substr(2);
            my $type = .type;
            my uint $byte-count = $type.^nativesize div 8;
            my $cval = CArray[$type].new;
            $cval[0] = self."$name"();
            my $bytes = nativecast(CArray[uint8], $cval);
            loop (my int $i = 1; $i <= $byte-count; $i++) {
                $buf.append: $bytes[$byte-count - $i];
            }
        };
        $buf;
    }

    method pack-host {
        # ensure we're working at the byte level
        my buf8 $buf .= new;
        my uint $off = 0;
        for self.^attributes {
            my str $name = .name.substr(2);
            my $type = .type;
            my uint $byte-count = $type.^nativesize div 8;
            my $cval = CArray[$type].new;
            $cval[0] = self."$name"();
            my $bytes = nativecast(CArray[uint8], $cval);
            loop (my int $i = 0; $i < $byte-count; $i++) {
                $buf.append: $bytes[$i];
            }
        };
        $buf;
    }

    method pack {
        $endian == HostEndian
            ?? self.pack-host
            !! self.pack-foreign
    }

    method write(\fh) {
        $endian == HostEndian
            ?? self.write-host(fh)
            !! self.write-foreign(fh)
    }

}


