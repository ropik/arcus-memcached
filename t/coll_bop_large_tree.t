#!/usr/bin/perl

use strict;
use Test::More tests => 450460;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;

# set environment variable
$ENV{'ARCUS_MAX_BTREE_SIZE'}='100000';

my $server = new_memcached();
my $sock = $server->sock;

# BOP test sub routines
sub bop_insert {
    my ($key, $from_bkey, $to_bkey, $width, $create, $flags, $exptime, $maxcount) = @_;
    my $bkey;
    my $eflag = "";
    my $value;
    my $vleng;
    my $cmd;
    my $msg;
    my @array = ("0x0000", "0x0001", "0x0002", "0x0003", "0x0004", "0x0005", "0x0006", "0x0007", "0x0008", "0x0009");

    $value = "$key-data-$from_bkey";
    $vleng = length($value);
    $eflag = $array[$from_bkey%10];
    if ($create eq "create") {
        $cmd = "bop insert $key $from_bkey $eflag $vleng $create $flags $exptime $maxcount\r\n$value\r\n";
        $msg = "bop insert $key $from_bkey $eflag $vleng $create $flags $exptime $maxcount : $value";
        print $sock "$cmd"; is(scalar <$sock>, "CREATED_STORED\r\n", "$msg");
        $cmd = "setattr $key maxcount=100000\r\n"; $msg = "OK";
        print $sock "$cmd"; is(scalar <$sock>, "OK\r\n", "$cmd: $msg");
    } else {
        $cmd = "bop insert $key $from_bkey $eflag $vleng\r\n$value\r\n";
        $msg = "bop insert $key $from_bkey $eflag $vleng : $value";
        print $sock "$cmd"; is(scalar <$sock>, "STORED\r\n", "$msg");
    }

    if ($from_bkey <= $to_bkey) {
        for ($bkey = $from_bkey + $width; $bkey <= $to_bkey; $bkey = $bkey + $width) {
            $eflag = $array[$bkey%10];
            $value = "$key-data-$bkey";
            $vleng = length($value);
            $cmd = "bop insert $key $bkey $eflag $vleng\r\n$value\r\n";
            $msg = "bop insert $key $bkey $eflag $vleng : $value";
            print $sock "$cmd"; is(scalar <$sock>, "STORED\r\n", "$msg");
        }
    } else {
        for ($bkey = $from_bkey - $width; $bkey >= $to_bkey; $bkey = $bkey - $width) {
            $eflag = $array[$bkey%10];
            $value = "$key-data-$bkey";
            $vleng = length($value);
            $cmd = "bop insert $key $bkey $eflag $vleng\r\n$value\r\n";
            $msg = "bop insert $key $bkey $eflag $vleng : $value";
            print $sock "$cmd"; is(scalar <$sock>, "STORED\r\n", "$msg");
        }
    }
}

sub assert_bop_get {
    my ($key, $width, $flags, $from_bkey, $to_bkey, $offset, $count, $delete, $tailstr) = @_;
    my $ecnt = 0;
    my $bkey;
    my $data;
    my @res_bkey = ();
    my @res_data = ();

    if ($from_bkey <= $to_bkey) {
        if ($offset eq 0) {
            $bkey = $from_bkey;
        } else {
            $bkey = $from_bkey + ($offset * $width);
        }
        for ( ; $bkey <= $to_bkey; $bkey = $bkey + $width) {
            $data = "$key-data-$bkey";
            push(@res_bkey, $bkey);
            push(@res_data, $data);
            $ecnt = $ecnt + 1;
            if (($count > 0) and ($ecnt >= $count)) {
                last;
            }
        }
    } else {
        if ($offset eq 0) {
            $bkey = $from_bkey;
        } else {
            $bkey = $from_bkey - ($offset * $width);
        }
        for ( ; $bkey >= $to_bkey; $bkey = $bkey - $width) {
            $data = "$key-data-$bkey";
            push(@res_bkey, $bkey);
            push(@res_data, $data);
            $ecnt = $ecnt + 1;
            if (($count > 0) and ($ecnt >= $count)) {
                last;
            }
        }
    }
    my $bkey_list = join(",", @res_bkey);
    my $data_list = join(",", @res_data);
    my $args = "$key $from_bkey..$to_bkey $offset $count $delete";
    bop_get_is($sock, $args, $flags, $ecnt, $bkey_list, $data_list, $tailstr);
}

# bop gbp (get by position)
sub assert_bop_gbp {
    my ($key, $order, $from_posi, $to_posi, $flags, $ecount, $from_bkey, $to_bkey, $width) = @_;
    my $ecnt = 0;
    my $bkey;
    my $data;
    my @res_bkey = ();
    my @res_data = ();

    if ($from_bkey <= $to_bkey) {
        for ($bkey = $from_bkey; $bkey <= $to_bkey; $bkey = $bkey + $width) {
            $data = "$key-data-$bkey";
            push(@res_bkey, $bkey);
            push(@res_data, $data);
            $ecnt = $ecnt + 1;
        }
    } else {
        for ($bkey = $from_bkey; $bkey >= $to_bkey; $bkey = $bkey - $width) {
            $data = "$key-data-$bkey";
            push(@res_bkey, $bkey);
            push(@res_data, $data);
            $ecnt = $ecnt + 1;
        }
    }
    my $bkey_list = join(",", @res_bkey);
    my $data_list = join(",", @res_data);
    my $args = "$key $order $from_posi..$to_posi";
    my $reshead = "$flags $ecount";
    bop_gbp_is($sock, $args, $reshead, $bkey_list, $data_list);
}

# bop pwg (position with get)
sub assert_bop_pwg {
    my ($key, $find_bkey, $order, $count, $position, $flags, $ecount, $rindex, $from_bkey, $to_bkey, $width) = @_;
    my $ecnt = 0;
    my $bkey;
    my $data;
    my @res_bkey = ();
    my @res_data = ();

    if ($from_bkey <= $to_bkey) {
        for ($bkey = $from_bkey; $bkey <= $to_bkey; $bkey = $bkey + $width) {
            $data = "$key-data-$bkey";
            push(@res_bkey, $bkey);
            push(@res_data, $data);
            $ecnt = $ecnt + 1;
        }
    } else {
        for ($bkey = $from_bkey; $bkey >= $to_bkey; $bkey = $bkey - $width) {
            $data = "$key-data-$bkey";
            push(@res_bkey, $bkey);
            push(@res_data, $data);
            $ecnt = $ecnt + 1;
        }
    }
    my $bkey_list = join(",", @res_bkey);
    my $data_list = join(",", @res_data);
    my $args = "$key $find_bkey $order $count";
    my $reshead = "$position $flags $ecount $rindex";
    bop_pwg_is($sock, $args, $reshead, $bkey_list, $data_list);
}

# BOP test global variables
my $flags = 11;
my $width = 2;
my $min = 2;
my $max = 200000;
my $cnt = 0;
my $cmd;
my $val;
my $rst;
my $key;

for (4..6) {
    $key = "joon:key$cnt";
    $cmd = "get $key"; $rst = "END";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    if ($cnt == 0) {
        bop_insert("$key", $min, $max, $width, "create", 11, 0, -1);
    } elsif ($cnt == 1) {
        bop_insert("$key", $max, $min, $width, "create", 11, 0, -1);
    } elsif ($cnt == 2) {
        bop_insert("$key", $min, $max, ($width*2), "create", 11, 0, 0);
        bop_insert("$key", ($min+$width), $max, ($width*2), "", 11, 0, 0);
    } elsif ($cnt == 3) {
        bop_insert("$key", $max, $min, ($width*2), "create", 11, 0, 0);
        bop_insert("$key", ($max-$width), $min, ($width*2), "", 11, 0, 0);
    } elsif ($cnt == 4) {
        bop_insert("$key", ($min+(0*$width)), $max, ($width*3), "create", 11, 0, -1);
        bop_insert("$key", ($min+(1*$width)), $max, ($width*3), "", 11, 0, -1);
        bop_insert("$key", ($min+(2*$width)), $max, ($width*3), "", 11, 0, -1);
    } elsif ($cnt == 5) {
        bop_insert("$key", ($max-(0*$width)), $min, ($width*3), "create", 11, 0, -1);
        bop_insert("$key", ($max-(1*$width)), $min, ($width*3), "", 11, 0, -1);
        bop_insert("$key", ($max-(2*$width)), $min, ($width*3), "", 11, 0, -1);
    } else {
        bop_insert("$key", $min, $max, ($width*4), "create", 11, 0, -1);
        bop_insert("$key", (($min+$max)-(1*$width)), $min, ($width*4), "", 11, 0, -1);
        bop_insert("$key", (($min)+(2*$width)), $max, ($width*4), "", 11, 0, -1);
        bop_insert("$key", (($min+$max)-(3*$width)), $min, ($width*4), "", 11, 0, -1);
    }
    getattr_is($sock, "$key count maxcount", "count=100000 maxcount=100000");
    # bop get
    assert_bop_get("$key", $width, 11,  22222,  22222, 0, 0, "", "END");
    assert_bop_get("$key", $width, 11,  88888,  88888, 0, 0, "", "END");
    assert_bop_get("$key", $width, 11,  20000,  20222, 0, 0, "", "END");
    assert_bop_get("$key", $width, 11,  20000,  20222, 10, 50, "", "END");
    assert_bop_get("$key", $width, 11,  20000,  20222, 50, 0, "", "END");
    assert_bop_get("$key", $width, 11,  20000,  20222, 100, 0, "", "END");
    assert_bop_get("$key", $width, 11, 180222, 180000, 0, 0, "", "END");
    assert_bop_get("$key", $width, 11, 180222, 180000, 10, 50, "", "END");
    assert_bop_get("$key", $width, 11, 180222, 180000, 50, 50, "", "END");
    assert_bop_get("$key", $width, 11, 180222, 180000, 100, 50, "", "END");
    assert_bop_get("$key", $width, 11,  10000, 190000, 0, 100, "", "END");
    assert_bop_get("$key", $width, 11,  10000, 190000, 2000, 100, "", "END");
    assert_bop_get("$key", $width, 11, 190000, 10000, 0, 100, "", "END");
    assert_bop_get("$key", $width, 11, 190000, 10000, 2000, 100, "", "END");
    $cmd = "bop get $key 55555"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop get $key 0..1"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop get $key 210000..200001"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    # bop position
    $cmd = "bop position $key 2 asc"; $rst = "POSITION=0";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 2 desc"; $rst = "POSITION=99999";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 200000 asc"; $rst = "POSITION=99999";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 200000 desc"; $rst = "POSITION=0";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 20000 asc"; $rst = "POSITION=9999";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 20000 desc"; $rst = "POSITION=90000";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 180000 asc"; $rst = "POSITION=89999";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 180000 desc"; $rst = "POSITION=10000";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 33333 asc"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 77777 desc"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    # bop bgp(get bp position)
    $cmd = "bop gbp $key asc -1"; $rst = "CLIENT_ERROR bad command line format";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key asc -1..-100"; $rst = "CLIENT_ERROR bad command line format";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key asc -1..100"; $rst = "CLIENT_ERROR bad command line format";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key desc -1"; $rst = "CLIENT_ERROR bad command line format";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key desc -1..-100"; $rst = "CLIENT_ERROR bad command line format";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key desc -1..100"; $rst = "CLIENT_ERROR bad command line format";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key asc 400000"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key asc 400000..500000"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key asc 500000..400000"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key desc 400000"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key desc 400000..500000"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop gbp $key desc 500000..400000"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    assert_bop_gbp("$key", "asc",      0,    99, $flags, 100,      2,    200, $width);
    assert_bop_gbp("$key", "asc",     99,     0, $flags, 100,    200,      2, $width);
    assert_bop_gbp("$key", "desc",     0,   100, $flags, 101, 200000, 199800, $width);
    assert_bop_gbp("$key", "desc",   100,     0, $flags, 101, 199800, 200000, $width);
    assert_bop_gbp("$key", "asc",  10000, 10099, $flags, 100,  20002,  20200, $width);
    assert_bop_gbp("$key", "asc",  10099, 10000, $flags, 100,  20200,  20002, $width);
    assert_bop_gbp("$key", "desc", 10000, 10100, $flags, 101, 180000, 179800, $width);
    assert_bop_gbp("$key", "desc", 10100, 10000, $flags, 101, 179800, 180000, $width);
    assert_bop_gbp("$key", "asc",  25000, 25000, $flags,   1,  50002,  50002, $width);
    assert_bop_gbp("$key", "desc", 25000, 25000, $flags,   1, 150000, 150000, $width);
    # bop pwg(position with get)
    $cmd = "bop pwg $key 10 asc -1"; $rst = "CLIENT_ERROR bad command line format";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop pwg $key 10 both"; $rst = "CLIENT_ERROR bad command line format";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop pwg $key 33333 asc"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop pwg $key 77777 desc"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop pwg $key 33333 asc 10"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop pwg $key 77777 desc 10"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    assert_bop_pwg("$key",      2,  "asc",  0,      0, $flags,  1,  0,      2,      2, $width);
    assert_bop_pwg("$key",      2, "desc",  0,  99999, $flags,  1,  0,      2,      2, $width);
    assert_bop_pwg("$key", 200000,  "asc",  0,  99999, $flags,  1,  0, 200000, 200000, $width);
    assert_bop_pwg("$key", 200000, "desc",  0,      0, $flags,  1,  0, 200000, 200000, $width);
    assert_bop_pwg("$key",  44444,  "asc",  0,  22221, $flags,  1,  0,  44444,  44444, $width);
    assert_bop_pwg("$key",  44444, "desc",  0,  77778, $flags,  1,  0,  44444,  44444, $width);
    assert_bop_pwg("$key",      2,  "asc", 10,      0, $flags, 11,  0,      2,     22, $width);
    assert_bop_pwg("$key",      2, "desc", 10,  99999, $flags, 11, 10,     22,      2, $width);
    assert_bop_pwg("$key", 200000,  "asc", 10,  99999, $flags, 11, 10, 199980, 200000, $width);
    assert_bop_pwg("$key", 200000, "desc", 10,      0, $flags, 11,  0, 200000, 199980, $width);
    assert_bop_pwg("$key",  44444,  "asc", 10,  22221, $flags, 21, 10,  44424,  44464, $width);
    assert_bop_pwg("$key",  44444, "desc", 10,  77778, $flags, 21, 10,  44464,  44424, $width);
    assert_bop_pwg("$key",     10,  "asc", 10,      4, $flags, 15,  4,      2,     30, $width);
    assert_bop_pwg("$key",     10, "desc", 10,  99995, $flags, 15, 10,     30,      2, $width);
    assert_bop_pwg("$key", 199990,  "asc", 10,  99994, $flags, 16, 10, 199970, 200000, $width);
    assert_bop_pwg("$key", 199990, "desc", 10,      5, $flags, 16,  5, 200000, 199970, $width);
    if ($cnt == 0 or $cnt == 2) {
        $cmd = "bop delete $key 10002..19998"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 79998..50002"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop position $key 10000 asc"; $rst = "POSITION=4999";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop position $key 90000 desc"; $rst = "POSITION=55000";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        assert_bop_gbp("$key", "asc",   4999,  5000, $flags,   2,  10000,  20000, 10000);
        assert_bop_gbp("$key", "desc", 60000, 60001, $flags,   2,  80000,  50000, 30000);
        assert_bop_gbp("$key", "asc",    100,   199, $flags, 100,    202,    400,     2);
        assert_bop_gbp("$key", "asc",    199,   100, $flags, 100,    400,    202,     2);
        assert_bop_gbp("$key", "desc",     0,   100, $flags, 101, 200000, 199800,     2);
        assert_bop_gbp("$key", "desc",   100,     0, $flags, 101, 199800, 200000,     2);
        $cmd = "bop delete $key 0..200000 0 EQ 0x0002,0x0004,0x0006,0x0008"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        bop_insert("$key", 1, 49999, $width, "", 11, 0, -1);
        $cmd = "bop delete $key 0..200000 0 EQ 0x0000"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        bop_insert("$key", 99999, 50001, $width, "", 11, 0, -1);
    } elsif ($cnt == 1 or $cnt == 3) {
        $cmd = "bop delete $key 0..50000"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop position $key 50002 asc"; $rst = "POSITION=0";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        assert_bop_gbp("$key", "asc",  5000, 5100, $flags, 101, 60002, 60202, 2);
        assert_bop_gbp("$key", "desc", 5000, 5100, $flags, 101, 190000, 189800, 2);
        $cmd = "bop delete $key 100001..200000"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 100000..0 0 NE 0x0002,0x0004"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 90000..10000 0 EQ 0x0002"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        bop_insert("$key", 1, 19999, $width, "", 11, 0, -1);
        $cmd = "bop delete $key 90000..10000 0 EQ 0x0004"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 90000..20000"; $rst = "NOT_FOUND_ELEMENT";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 0..100000 0 EQ 0x0002,0x0004"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        bop_insert("$key", 99999, 80001, $width, "", 11, 0, -1);
        bop_insert("$key", 40001, 49999, $width, "", 11, 0, -1);
        bop_insert("$key", 59999, 50001, $width, "", 11, 0, -1);
        bop_insert("$key", 20001, 39999, $width, "", 11, 0, -1);
        bop_insert("$key", 79999, 60001, $width, "", 11, 0, -1);
    } else {
        my $small;
        my $large;
        for ($small = 0; $small < 200000; $small = $small + 10000) {
            $large = $small + int(rand(9000));
            $cmd = "bop delete $key $small..$large"; $rst = "DELETED";
            print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        }
        $cmd = "bop delete $key 0..100000 0 GT 0x0001"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 200000..100000 0 GT 0x0001"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop get $key 0..200000 0 GE 0x0002"; $rst = "NOT_FOUND_ELEMENT";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        bop_insert("$key", 99999, 50001, $width, "", 11, 0, -1);
        $cmd = "bop delete $key 0..200000 0 EQ 0x0000"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        bop_insert("$key", 1, 19999, $width, "", 11, 0, -1);
        bop_insert("$key", 49999, 20001, $width, "", 11, 0, -1);
    }
    # the second phase: get, position, gbp
    getattr_is($sock, "$key count maxcount", "count=50000 maxcount=100000");
    $cmd = "bop delete $key 0..100000 0 EQ 0x0000,0x0002,0x0004,0x0006,0x0008"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    # bop get
    assert_bop_get("$key", $width, 11, 33333, 33333, 0, 0, "", "END");
    assert_bop_get("$key", $width, 11, 77777, 77777, 0, 0, "", "END");
    assert_bop_get("$key", $width, 11, 10001, 10223, 0, 0, "", "END");
    assert_bop_get("$key", $width, 11, 10001, 10223, 10, 50, "", "END");
    assert_bop_get("$key", $width, 11, 10001, 10223, 50, 50, "", "END");
    assert_bop_get("$key", $width, 11, 10001, 10223, 100, 50, "", "END");
    assert_bop_get("$key", $width, 11, 10001, 10223, 100, 50, "", "END");
    assert_bop_get("$key", $width, 11, 90223, 90001, 0, 0, "", "END");
    assert_bop_get("$key", $width, 11, 90223, 90001, 10, 50, "", "END");
    assert_bop_get("$key", $width, 11, 90223, 90001, 50, 50, "", "END");
    assert_bop_get("$key", $width, 11, 90223, 90001, 100, 50, "", "END");
    assert_bop_get("$key", $width, 11, 11111, 77777, 0, 100, "", "END");
    assert_bop_get("$key", $width, 11, 11111, 77777, 2000, 100, "", "END");
    assert_bop_get("$key", $width, 11, 77777, 11111, 0, 100, "", "END");
    assert_bop_get("$key", $width, 11, 77777, 11111, 2000, 100, "", "END");
    $cmd = "bop get $key 50000"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop get $key 0..0"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop get $key 100001..100000"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    # bop position
    $cmd = "bop position $key 1 asc"; $rst = "POSITION=0";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 1 desc"; $rst = "POSITION=49999";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 99999 asc"; $rst = "POSITION=49999";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 99999 desc"; $rst = "POSITION=0";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 20001 asc"; $rst = "POSITION=10000";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 20001 desc"; $rst = "POSITION=39999";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 79999 asc"; $rst = "POSITION=39999";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 79999 desc"; $rst = "POSITION=10000";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 20000 desc"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "bop position $key 80000 desc"; $rst = "NOT_FOUND_ELEMENT";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    # bop bgp(get by position)
    assert_bop_gbp("$key", "asc",      0,    99, $flags, 100,     1,   199, $width);
    assert_bop_gbp("$key", "asc",     99,     0, $flags, 100,   199,     1, $width);
    assert_bop_gbp("$key", "desc",     0,   100, $flags, 101, 99999, 99799, $width);
    assert_bop_gbp("$key", "desc",   100,     0, $flags, 101, 99799, 99999, $width);
    assert_bop_gbp("$key", "asc",  10000, 10099, $flags, 100, 20001, 20199, $width);
    assert_bop_gbp("$key", "asc",  10099, 10000, $flags, 100, 20199, 20001, $width);
    assert_bop_gbp("$key", "desc", 10000, 10100, $flags, 101, 79999, 79799, $width);
    assert_bop_gbp("$key", "desc", 10100, 10000, $flags, 101, 79799, 79999, $width);
    assert_bop_gbp("$key", "asc",  25000, 25000, $flags,   1, 50001, 50001, $width);
    assert_bop_gbp("$key", "desc", 25000, 25000, $flags,   1, 49999, 49999, $width);
    # bop pwg(position with get)
    assert_bop_pwg("$key",      1,  "asc",  0,     0, $flags,  1,  0,     1,      1, $width);
    assert_bop_pwg("$key",      1, "desc",  0, 49999, $flags,  1,  0,     1,      1, $width);
    assert_bop_pwg("$key",  99999,  "asc",  0, 49999, $flags,  1,  0, 99999,  99999, $width);
    assert_bop_pwg("$key",  99999, "desc",  0,     0, $flags,  1,  0, 99999,  99999, $width);
    assert_bop_pwg("$key",  33333,  "asc",  0, 16666, $flags,  1,  0, 33333,  33333, $width);
    assert_bop_pwg("$key",  33333, "desc",  0, 33333, $flags,  1,  0, 33333,  33333, $width);
    assert_bop_pwg("$key",      1,  "asc", 10,     0, $flags, 11,  0,     1,     21, $width);
    assert_bop_pwg("$key",      1, "desc", 10, 49999, $flags, 11, 10,    21,      1, $width);
    assert_bop_pwg("$key",  99999,  "asc", 10, 49999, $flags, 11, 10, 99979,  99999, $width);
    assert_bop_pwg("$key",  99999, "desc", 10,     0, $flags, 11,  0, 99999,  99979, $width);
    assert_bop_pwg("$key",  33333,  "asc", 10, 16666, $flags, 21, 10, 33313,  33353, $width);
    assert_bop_pwg("$key",  33333, "desc", 10, 33333, $flags, 21, 10, 33353,  33313, $width);
    assert_bop_pwg("$key",      9,  "asc", 10,     4, $flags, 15,  4,     1,     29, $width);
    assert_bop_pwg("$key",      9, "desc", 10, 49995, $flags, 15, 10,    29,      1, $width);
    assert_bop_pwg("$key",  99989,  "asc", 10, 49994, $flags, 16, 10, 99969,  99999, $width);
    assert_bop_pwg("$key",  99989, "desc", 10,     5, $flags, 16,  5, 99999,  99969, $width);

    if ($cnt == 0 or $cnt == 1) {
        $cmd = "bop delete $key 10001..19999"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 79999..50001"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop position $key 9999 asc"; $rst = "POSITION=4999";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop position $key 89999 desc"; $rst = "POSITION=5000";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        assert_bop_gbp("$key", "asc",  4999,  5000, $flags,   2,  9999, 20001, 10002);
        assert_bop_gbp("$key", "desc", 9999, 10000, $flags,   2, 80001, 49999, 30002);
        assert_bop_gbp("$key", "asc",   100,   199, $flags, 100,   201,   399,     2);
        assert_bop_gbp("$key", "asc",   199,   100, $flags, 100,   399,   201,     2);
        assert_bop_gbp("$key", "desc",    0,   100, $flags, 101, 99999, 99799,     2);
        assert_bop_gbp("$key", "desc",  100,     0, $flags, 101, 99799, 99999,     2);
        $cmd = "bop delete $key 0..100000 0 NE 0x0005,0x0001"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    } elsif ($cnt == 2 or $cnt == 3) {
        $cmd = "bop delete $key 0..50000"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop position $key 50001 asc"; $rst = "POSITION=0";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        assert_bop_gbp("$key", "asc",  5000, 5100, $flags, 101, 60001, 60201, 2);
        assert_bop_gbp("$key", "desc", 5000, 5100, $flags, 101, 89999, 89799, 2);
        $cmd = "bop delete $key 100000..0 0 NE 0x0001,0x0003"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 90000..10000 0 EQ 0x0001"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 90000..10000 0 EQ 0x0003"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 90000..20000"; $rst = "NOT_FOUND_ELEMENT";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    } else {
        my $small;
        my $large;
        for ($small = 0; $small < 100000; $small = $small + 10000) {
            $large = $small + int(rand(9000));
            $cmd = "bop delete $key $small..$large"; $rst = "DELETED";
            print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        }
        $cmd = "bop delete $key 0..50000 0 GT 0x0002"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop delete $key 100000..50000 0 GT 0x0002"; $rst = "DELETED";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
        $cmd = "bop get $key 0..100000 0 GE 0x0003"; $rst = "NOT_FOUND_ELEMENT";
        print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    }
    $cmd = "bop delete $key 0..100000000 drop"; $rst = "DELETED_DROPPED";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cmd = "get $key"; $rst = "END";
    print $sock "$cmd\r\n"; is(scalar <$sock>, "$rst\r\n", "$cmd: $rst");
    $cnt = $cnt+1;
}

# unset environment variable
delete $ENV{'ARCUS_MAX_BTREE_SIZE'};
