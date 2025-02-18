=begin pod

=head1 Data::Reshapers::ToPrettyTable

C<Data::Reshapers::ToPrettyTable> package module has data transformation functions over
different data structures coercible to full-arrays.

=head1 Synopsis

    use Data::Reshapers;
    use Data::Reshapers::ToPrettyTable;

    my @tbl = get-titanic-dataset(headers => "auto");
    say ToPrettyTable(@tbl);

=end pod

use Pretty::Table;
use Data::Reshapers::Adapters;
use Data::Reshapers::Predicates;
use Hash::Merge;

unit module Data::Reshapers::ToPrettyTable;

constant %tblParamDefaults =
horizontal-char => '-', # |'─',
vertical-char => '|', #'│',
junction-char => '+', #'O', # '┼',
float-format=> '.6f';

#===========================================================
#| Complete column names
our proto CompleteColumnNames(|) is export {*}

multi sub CompleteColumnNames($dataset, :$missing-value = '') {

    my @allColnames;
    if is-array-of-hashes($dataset) {

        @allColnames = $dataset>>.keys.flat.unique;
        my %emptyRow = @allColnames X=> $missing-value;
        return $dataset.map({ merge-hash(%emptyRow, $_) }).Array;

    } elsif is-hash-of-hashes($dataset) {

        @allColnames = $dataset.values>>.keys.flat.unique;
        my %emptyRow = @allColnames X=> $missing-value;
        return $dataset.map({ $_.key => merge-hash(%emptyRow, $_.value) }).Hash;

    } else {
        warn 'Do not know how to process the dataset argument.';
        return $dataset;
    }
}

#===========================================================
#| Convert into a pretty table object.
our proto ToPrettyTable(|) is export {*}

my Str $hashArgErrMsg =
        'If the first argument is a hash then it is expected that it can be coerced into a' ~
        ' hash-of-hashes or hash-of-positionals,' ~
        ' which in turn can be coerced into a full two dimensional array.';;

my Str $arrayArgErrMsg =
        'If the first argument is an array then it is expected that it can be coerced into a' ~
        ' array-of-hashes, array-of-positionals, or hash-of-hashes,' ~
        ' which in turn can be coerced into a full two dimensional array.';

#-----------------------------------------------------------
multi ToPrettyTable(%tbl, *%args) {

    my $missing-value = %args<missing-value>:exists ?? %args<missing-value> !! '';

    my Hash %hash-of-hashes;
    my Positional %hash-of-arrays;

    # Coerces into hash of hashes
    try {
        %hash-of-hashes = %tbl;
    }

    if $! {

        # Coerce into array-of-hashes
        try {
            %hash-of-arrays = %tbl
        }

        if $! {
            #fail $hashArgErrMsg;
            return ToPrettyTable( %tbl.map({ %( Key => $_.key, Value => $_.value ) }).Array, |%args);
        }
    }

    if %hash-of-hashes.defined and %hash-of-hashes {

        %hash-of-hashes = CompleteColumnNames(%hash-of-hashes, :$missing-value);

        # Column names of the pretty table
        my @colnames = %hash-of-hashes{%hash-of-hashes.keys[0]}.keys;
        if %args<field-names>:exists {
            if ! %args<field-names>.isa(Whatever) {
                @colnames = %args<field-names>.grep({ $_ ∈ @colnames }).List;

                if @colnames.elems == 0 {
                    warn 'None of the specified field names are known.'
                } elsif @colnames.elems < %args<field-names>.elems {
                    warn 'Some of the specified field names are not known.'
                }
            }
        }

        # Initialize the pretty table object
        my $tableObj = Pretty::Table.new:
                field-names => ['', |@colnames],
                sort-by => '',
                align => %('' => 'l'),
                |%tblParamDefaults,
                |%args.grep({ $_.key ne 'field-names' }).Hash;

        # Add each hash into the pretty table as table row
        %hash-of-hashes.map({ $tableObj.add-row([$_.key, |$_.value{|@colnames}]) });

        # Result
        return $tableObj;

    } else {

        # Column names of the pretty table
        my @colnames = ^%hash-of-arrays{%hash-of-arrays.keys[0]}.elems;

        # Initialize the pretty table object
        my $tableObj = Pretty::Table.new:
                field-names => ['', |@colnames>>.Str],
                sort-by => '',
                align => %('' => 'l'),
                |%tblParamDefaults,
                |%args;

        # Add each hash into the pretty table as table row
        %hash-of-arrays.map({ $tableObj.add-row([$_.key, |$_.value[|@colnames]]) });

        # Result
        return $tableObj;

    }

    return Nil;
}

#-----------------------------------------------------------
multi ToPrettyTable(@tbl, *%args) {

    my $missing-value = %args<missing-value>:exists ?? %args<missing-value> !! '';

    my Hash @arr-of-hashes;
    my Positional @arr-of-arrays;

    # Coerce into array-of-hashes
    try {
        @arr-of-hashes = @tbl
    }

    if $! {

        # Coerce into array-of-hashes
        try {
            @arr-of-arrays = @tbl;

            if not has-homogeneous-shape(@arr-of-arrays) {
                fail $arrayArgErrMsg;
            }
        }

        if $! {
            # Check for an array of key-array pairs
            if is-array-of-key-array-pairs(@tbl) or is-array-of-key-hash-pairs(@tbl) {

                # Convert an array of key-[array|hash] pairs into a hash of hashes
                my %res = convert-to-hash-of-hashes(@tbl);

                return ToPrettyTable(%res, |%args)
            } elsif is-array-of-pairs(@tbl) {
                return ToPrettyTable(@tbl.map({ %( Key => $_.key, Value => $_.value ) }).Array, |%args)
            }

            fail $arrayArgErrMsg;
        }
    }

    # Convert to table
    if @arr-of-hashes.defined and @arr-of-hashes {

        @arr-of-hashes = CompleteColumnNames(@arr-of-hashes, :$missing-value);

        # Column names of the pretty table
        my @colnames = @arr-of-hashes[0].keys;
        if %args<field-names>:exists {
            if ! %args<field-names>.isa(Whatever) {
                @colnames = %args<field-names>.grep({ $_ ∈ @colnames }).List;

                if @colnames.elems == 0 {
                    warn 'None of the specified field names are known.'
                } elsif @colnames.elems < %args<field-names>.elems {
                    warn 'Some of the specified field names are not known.'
                }
            }
        }


        # Initialize the pretty table object
        my $tableObj = Pretty::Table.new:
                field-names => @colnames,
                |%tblParamDefaults,
                |%args.grep({ $_.key ne 'field-names' }).Hash;

        # Add each hash into the pretty table as table row
        @arr-of-hashes.map({ $tableObj.add-row($_{|@colnames}) });

        return $tableObj;

    } else {

        # Column names of the pretty table
        my @colnames = ^@arr-of-arrays.values[0].elems;

        # Initialize the pretty table object
        my $tableObj = Pretty::Table.new:
                field-names => @colnames>>.Str,
                |%tblParamDefaults,
                |%args;

        # Add each hash into the pretty table as table row
        @arr-of-arrays.map({ $tableObj.add-row($_[|@colnames]>>.gist) });

        return $tableObj;

    }

    # Result
    return Nil;
}