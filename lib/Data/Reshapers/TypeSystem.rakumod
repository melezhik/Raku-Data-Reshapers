use v6.d;

use Data::Reshapers::Predicates;

#===========================================================
role Data::Reshapers::TypeSystem::Type {
    has $.type is rw;
    has $.count is rw;
    submethod BUILD(:$!type = Any, :$!count = 1) {}
    multi method new($type, $count) {
        self.bless(:$type, :$count)
    }
    method Str(-->Str) {
        self.gist;
    }
};

class Data::Reshapers::TypeSystem::Atom
        does Data::Reshapers::TypeSystem::Type {
    method gist(-->Str) {
        'Atom(' ~ $.type.gist ~ ')'
    }
};

class Data::Reshapers::TypeSystem::Pair
        does Data::Reshapers::TypeSystem::Type {
    has $.keyType;

    submethod BUILD(:$!keyType = Any, :$!type = Any, :$!count = Any) {}
    multi method new($keyType, $type) {
        self.bless(:$keyType, :$type)
    }
    method gist(-->Str) {
        'Pair(' ~ $.keyType.gist ~ ', ' ~ $.type.gist ~ ')'
    }
};


class Data::Reshapers::TypeSystem::Vector
        does Data::Reshapers::TypeSystem::Type {
    method gist(-->Str) {
        if $.type.elems == 1 {
            'Vector(' ~ $.type>>.gist.join(', ') ~ ', ' ~ $.count.gist ~ ')'
        } else {
            'Vector([' ~ $.type>>.gist.join(', ') ~ '], ' ~ $.count.gist ~ ')'
        }
    }
};

class Data::Reshapers::TypeSystem::Tuple
        does Data::Reshapers::TypeSystem::Type {
    method gist(-->Str) {
        if $!count == 1 {
            'Tuple([' ~ $.type>>.gist.join(', ') ~ '])'
        } else {
            'Tuple([' ~ $.type>>.gist.join(', ') ~ '], ' ~ $.count.gist ~ ')'
        }
    }
};

class Data::Reshapers::TypeSystem::Assoc
        does Data::Reshapers::TypeSystem::Type {
    has $.keyType;

    submethod BUILD(:$!keyType = Any, :$!type = Any, :$!count = Any) {}
    multi method new($keyType, $type, $count) {
        self.bless(:$keyType, :$type, :$count)
    }

    method gist(-->Str) {
        if $!keyType eq 'Tally' {
            'Assoc([' ~ $.type>>.gist.join(', ') ~ '], ' ~ $.count.gist ~ ')'
        } else {
            'Assoc(' ~ $.keyType.gist ~ ', ' ~ $.type.gist ~ ', ' ~ $.count.gist ~ ')'
        }
    }
};

class Data::Reshapers::TypeSystem::Struct
        does Data::Reshapers::TypeSystem::Type {
    has $.keys;
    has $.values;

    submethod BUILD(:$!keys = Any, :$!values = Any) {}
    multi method new($keys, $values) {
        self.bless(:$keys, :$values)
    }

    method gist(-->Str) {
        'Struct([' ~ $!keys.join(', ') ~ '], [' ~ $!values.map({ $_.^name }).join(', ') ~ '])';
    }
};

#===========================================================

#multi sub circumfix:<%O( )> (@p) { Hash::Ordered.new.STORE: @p }

#===========================================================
class Data::Reshapers::TypeSystem {

    has UInt $.max-enum-elems is rw = 6;
    has UInt $.max-struct-elems is rw = 16;
    has UInt $.max-tuple-elems is rw = 16;

    #------------------------------------------------------------
    method has-homogeneous-shape($l) {
        so $l[*].&{ $_».elems.all == $_[0].elems }
    }

    #------------------------------------------------------------
    method has-homogeneous-type($l) {
        if $l.elems > 0 && ($l[0] ~~ Map || $l[0] ~~ List) {
            so $l[*].&{ $_».are.all eqv $_[0]>>.are }
        } else {
            so $l[*].&{ $_».are.all eqv $_[[0,]].are }
        }
    }

    #------------------------------------------------------------
    proto method is-reshapable(|) {*}

    multi method is-reshapable($data, :$iterable-type = Positional, :$record-type = Hash) {
        $data ~~ $iterable-type and ([and] $data.map({ $_ ~~ $record-type }))
    }

    multi method is-reshapable($iterable-type, $record-type, $data) {
        self.is-reshapable($data, :$iterable-type, :$record-type)
    }

    #------------------------------------------------------------
    method record-types($data) {

        my $types;

        given $data {
            when is-array-of-pairs($_) {
                $types = $data>>.are.map({ $_.map({ $_.key => $_.value }).Hash });
            }

            when self.is-reshapable(Positional, Map, $_) {
                $types = $data>>.are.map({ $_.map({ $_.key => $_.value }).Hash });
            }

            when is-hash-of-hashes($_) {
                return %( $_.keys Z=> self.record-types($_.values));
            }

            when $_ ~~ List {
                $types = $_.map({ $_.are });
            }

            when $_ ~~ Map {
                $types = $_.map({ $_.key => $_.value }).Hash;
            }

            default {
                warn 'Do not know how to find the type(s) of the given record(s).';
            }
        }

        return $types;
    }

    #------------------------------------------------------------
    multi method deduce-type($data, Bool :$tally = False) {
        given $data {
            when $_ ~~ Int { return Data::Reshapers::TypeSystem::Atom.new(Int, 1) }
            when $_ ~~ Numeric { return Data::Reshapers::TypeSystem::Atom.new(Numeric, 1) }
            when $_ ~~ Str { return Data::Reshapers::TypeSystem::Atom.new(Str, 1) }
            when $_ ~~ Pair { return Data::Reshapers::TypeSystem::Pair.new(self.deduce-type($_.key), self.deduce-type($_.value)) }

            when $_ ~~ Seq { return self.deduce-type($data.List); }

            when $_ ~~ List && self.has-homogeneous-type($_) && !($_[0] ~~ Pair) {
                return Data::Reshapers::TypeSystem::Vector.new(self.deduce-type($_[0]), $_.elems)
            }

            when $_ ~~ List {
                my @t = $_.map({ self.deduce-type($_) }).List;
                my $tbag = @t>>.gist.BagHash;
                if $tbag.elems == 1 && !$tally {
                    return Data::Reshapers::TypeSystem::Vector.new(@t[0], $_.elems)
                } elsif $tally {
                    return Data::Reshapers::TypeSystem::Tuple.new($tbag.pairs.sort({ $_.key }), $_.elems)
                }
                if $_.elems ≤ self.max-tuple-elems {
                    return Data::Reshapers::TypeSystem::Tuple.new(@t, 1)
                } else {
                    return Data::Reshapers::TypeSystem::Vector.new(Nil, $_.elems)
                }
            }

            when is-hash-of-hashes($_) {
                my $kType = self.deduce-type($_.keys[0]);
                my $vType = self.deduce-type($_.values.List);

                if $vType ~~ Data::Reshapers::TypeSystem::Vector {
                    return Data::Reshapers::TypeSystem::Assoc.new( keyType => $kType, type => $vType.type, count => $_.elems)
                }
                return Data::Reshapers::TypeSystem::Assoc.new( keyType => $kType, type => $vType, count => $_.elems)
            }

            when $_ ~~ Hash {
                my @res = |$_>>.are.sort({ $_.key });
                if !self.has-homogeneous-type($_.values) && $_.elems ≤ self.max-struct-elems  {
                    return Data::Reshapers::TypeSystem::Struct.new(keys => @res>>.key.List, values => @res>>.value.List);
                } elsif self.has-homogeneous-type($_.values) {
                    return Data::Reshapers::TypeSystem::Assoc.new(keyType => self.deduce-type($_.keys[0]), type => self.deduce-type($_.values[0]), count => $_.elems);
                } elsif $tally {
                    my @t = $_.pairs.map({ self.deduce-type($_) });
                    my $tbag = @t>>.gist.BagHash;
                    return Data::Reshapers::TypeSystem::Assoc.new(keyType => 'Tally', type => $tbag.pairs.sort(*.key), count => $_.elems );
                } else {
                    return Data::Reshapers::TypeSystem::Assoc.new(keyType => self.deduce-type($_.keys.List):tally, type => self.deduce-type($_.values.List):tally, count => $_.elems);
                }
            }

            default { Any }
        }
    }
}