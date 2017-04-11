use v6;
use Test;
use Native::Packing :Endian;

class N does Native::Packing[Network] {
      has uint8 $.a;
      has uint16 $.b;
      has uint8 $.c
}

note Native::Packing.host-endian;
my $struct = N.new: :a(10), :b(20), :c(30);
my $out-fh = "t/net.bin".IO.open(:bin, :w);
$struct.write: $out-fh;
$out-fh.close;
my $n-buf = "t/net.bin".IO.open(:bin, :r).read(4);
is-deeply $n-buf, Buf[uint8].new(10, 0, 20, 30), 'network write';

my $n-struct = N.read: "t/net.bin".IO.open(:bin, :r);
is-deeply $n-struct, $struct, 'network write/read round-trip';

class V does Native::Packing[Vax] {
      has uint8 $.a;
      has uint16 $.b;
      has uint8 $.c
}

$struct = V.new: :a(10), :b(20), :c(30);
$out-fh = "t/vax.bin".IO.open(:bin, :w);
$struct.write: $out-fh;
$out-fh.close;
my $v-buf = "t/vax.bin".IO.open(:bin, :r).read(4);
is-deeply $v-buf, Buf[uint8].new(10, 20, 0, 30), 'vax write';

my $v-struct = V.read: "t/vax.bin".IO.open(:bin, :r);
is-deeply $v-struct, $struct, 'vax write/read round-trip';

done-testing;


