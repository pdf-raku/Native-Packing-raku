use Test;
use Native::Packing :Endian;
plan 1;

class BaseStruct {
    has uint16 $.a;
    has uint8  $.b;
    has uint8  $.c;
}

class Struct is BaseStruct is repr('CStruct') does Native::Packing[Network] {
    has uint16 $.c;
}

my $s = Struct.new: :a(42), :b(99), :c(69);
my $n-buf = $s.pack;
is-deeply $n-buf.list, (
    0,42,
    99,
    0,69), 'network packing with inheritance';

done-testing;
