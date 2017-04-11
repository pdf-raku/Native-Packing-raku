use v6;
use Test;
use Native::Packing :Endian;

class N does Native::Packing[Network] {
      has uint8 $.a;
      has uint16 $.b;
      has uint8 $.c
}

my $struct = N.new: :a(10), :b(20), :c(30);

my $n-buf = $struct.pack;
is-deeply $n-buf, Buf[uint8].new(10, 0, 20, 30), 'network-packing';

my $n-struct = N.unpack: $n-buf;

is-deeply $n-struct, $struct, 'network round-trip';

class V does Native::Packing[Vax] {
      has uint8 $.a;
      has uint16 $.b;
      has uint8 $.c
}

$struct = V.new: :a(10), :b(20), :c(30);

my $v-buf = $struct.pack;
is-deeply $v-buf, Buf[uint8].new(10, 20, 0, 30), 'vax-packing';

my $v-struct = V.unpack: $v-buf;

is-deeply $v-struct, $struct, 'vax round-trip';

done-testing;


