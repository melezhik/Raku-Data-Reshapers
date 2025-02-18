# Raku Data::Reshapers

[![SparkyCI](http://ci.sparrowhub.io/project/gh-antononcube-Raku-Data-Reshapers/badge)](http://ci.sparrowhub.io)
[![Build Status](https://app.travis-ci.com/antononcube/Raku-Data-Reshapers.svg?branch=main)](https://app.travis-ci.com/github/antononcube/Raku-Data-Reshapers)
[![License: Artistic-2.0](https://img.shields.io/badge/License-Artistic%202.0-0298c3.svg)](https://opensource.org/licenses/Artistic-2.0)

This Raku package has data reshaping functions for different data structures that are 
coercible to full arrays.

The supported data structures are:
  - Positional-of-hashes
  - Positional-of-arrays
 
The five data reshaping provided by the package over those data structures are:

- Cross tabulation, `cross-tabulate`
- Long format conversion, `to-long-format`
- Wide format conversion, `to-wide-format`
- Join across (aka `SQL JOIN`), `join-across`
- Transpose, `transpose`

The first four operations are fundamental in data wrangling and data analysis; 
see [AA1, Wk1, Wk2, AAv1-AAv2].

(Transposing of tabular data is, of course, also fundamental, but it also can be seen as a
basic functional programming operation.)

------

## Usage examples

### Cross tabulation

Making contingency tables -- or cross tabulation -- is a fundamental statistics and data analysis operation,
[Wk1, AA1]. 

Here is an example using the 
[Titanic](https://en.wikipedia.org/wiki/Titanic) 
dataset (that is provided by this package through the function `get-titanic-dataset`):

```perl6
use Data::Reshapers;

my @tbl = get-titanic-dataset();
my $res = cross-tabulate( @tbl, 'passengerSex', 'passengerClass');
say $res;
```
```
# {female => {1st => 144, 2nd => 106, 3rd => 216}, male => {1st => 179, 2nd => 171, 3rd => 493}}
```

```perl6
to-pretty-table($res);
```
```
# +--------+-----+-----+-----+
# |        | 3rd | 1st | 2nd |
# +--------+-----+-----+-----+
# | female | 216 | 144 | 106 |
# | male   | 493 | 179 | 171 |
# +--------+-----+-----+-----+
```

### Long format

Conversion to long format allows column names to be treated as data.

(More precisely, when converting to long format specified column names of a tabular dataset become values
in a dedicated column, e.g. "Variable" in the long format.)

```perl6
my @tbl1 = @tbl.roll(3);
.say for @tbl1;
```
```
# {id => 822, passengerAge => 30, passengerClass => 3rd, passengerSex => male, passengerSurvival => died}
# {id => 684, passengerAge => 40, passengerClass => 3rd, passengerSex => male, passengerSurvival => died}
# {id => 1243, passengerAge => -1, passengerClass => 3rd, passengerSex => male, passengerSurvival => died}
```

```perl6
.say for to-long-format( @tbl1 );
```
```
# {AutomaticKey => 0, Value => died, Variable => passengerSurvival}
# {AutomaticKey => 0, Value => 3rd, Variable => passengerClass}
# {AutomaticKey => 0, Value => male, Variable => passengerSex}
# {AutomaticKey => 0, Value => 30, Variable => passengerAge}
# {AutomaticKey => 0, Value => 822, Variable => id}
# {AutomaticKey => 1, Value => died, Variable => passengerSurvival}
# {AutomaticKey => 1, Value => 3rd, Variable => passengerClass}
# {AutomaticKey => 1, Value => male, Variable => passengerSex}
# {AutomaticKey => 1, Value => 40, Variable => passengerAge}
# {AutomaticKey => 1, Value => 684, Variable => id}
# {AutomaticKey => 2, Value => died, Variable => passengerSurvival}
# {AutomaticKey => 2, Value => 3rd, Variable => passengerClass}
# {AutomaticKey => 2, Value => male, Variable => passengerSex}
# {AutomaticKey => 2, Value => -1, Variable => passengerAge}
# {AutomaticKey => 2, Value => 1243, Variable => id}
```

```perl6
my @lfRes1 = to-long-format( @tbl1, 'id', [], variablesTo => "VAR", valuesTo => "VAL2" );
.say for @lfRes1;
```
```
# {VAL2 => male, VAR => passengerSex, id => 1243}
# {VAL2 => -1, VAR => passengerAge, id => 1243}
# {VAL2 => died, VAR => passengerSurvival, id => 1243}
# {VAL2 => 3rd, VAR => passengerClass, id => 1243}
# {VAL2 => male, VAR => passengerSex, id => 684}
# {VAL2 => 40, VAR => passengerAge, id => 684}
# {VAL2 => died, VAR => passengerSurvival, id => 684}
# {VAL2 => 3rd, VAR => passengerClass, id => 684}
# {VAL2 => male, VAR => passengerSex, id => 822}
# {VAL2 => 30, VAR => passengerAge, id => 822}
# {VAL2 => died, VAR => passengerSurvival, id => 822}
# {VAL2 => 3rd, VAR => passengerClass, id => 822}
```

### Wide format

Here we transform the long format result `@lfRes1` above into wide format -- 
the result has the same records as the `@tbl1`:

```perl6
to-pretty-table( to-wide-format( @lfRes1, 'id', 'VAR', 'VAL2' ) );
```
```
# +----------------+-------------------+--------------+------+--------------+
# | passengerClass | passengerSurvival | passengerSex |  id  | passengerAge |
# +----------------+-------------------+--------------+------+--------------+
# |      3rd       |        died       |     male     | 1243 |      -1      |
# |      3rd       |        died       |     male     | 684  |      40      |
# |      3rd       |        died       |     male     | 822  |      30      |
# +----------------+-------------------+--------------+------+--------------+
```

### Transpose

Using cross tabulation result above:

```perl6
my $tres = transpose( $res );

to-pretty-table($res, title => "Original");
```
```
# +--------------------------+
# |         Original         |
# +--------+-----+-----+-----+
# |        | 2nd | 1st | 3rd |
# +--------+-----+-----+-----+
# | female | 106 | 144 | 216 |
# | male   | 171 | 179 | 493 |
# +--------+-----+-----+-----+
```

```perl6
to-pretty-table($tres, title => "Transposed");
```
```
# +---------------------+
# |      Transposed     |
# +-----+--------+------+
# |     | female | male |
# +-----+--------+------+
# | 1st |  144   | 179  |
# | 2nd |  106   | 171  |
# | 3rd |  216   | 493  |
# +-----+--------+------+
```

------

## Type system

There is a type "deduction" system in place. The type system conventions follow
those of Mathematica's 
[`Dataset`](https://reference.wolfram.com/language/ref/Dataset.html) 
-- see the presentation 
["Dataset improvements"](https://www.wolfram.com/broadcast/video.php?c=488&p=4&disp=list&v=3264).

Here we get the Titanic dataset, change the "passengerAge" column values to be numeric, 
and show dataset's dimensions:

```perl6
my @dsTitanic = get-titanic-dataset(headers => 'auto');
@dsTitanic = @dsTitanic.map({$_<passengerAge> = $_<passengerAge>.Numeric; $_}).Array;
dimensions(@dsTitanic)
```
```
# (1309 5)
```

Here is a sample of dataset's records:

```perl6
to-pretty-table(@dsTitanic.pick(5), field-names => <id passengerAge passengerClass passengerSex passengerSurvival>)
```
```
# +------+--------------+----------------+--------------+-------------------+
# |  id  | passengerAge | passengerClass | passengerSex | passengerSurvival |
# +------+--------------+----------------+--------------+-------------------+
# | 1305 |      10      |      3rd       |    female    |        died       |
# | 684  |      40      |      3rd       |     male     |        died       |
# | 721  |      20      |      3rd       |     male     |        died       |
# |  40  |      50      |      1st       |     male     |        died       |
# | 399  |      10      |      2nd       |     male     |      survived     |
# +------+--------------+----------------+--------------+-------------------+
```

Here is the type of a single record:

```perl6
deduce-type(@dsTitanic[12])
```
```
# Struct([id, passengerAge, passengerClass, passengerSex, passengerSurvival], [Str, Int, Str, Str, Str])
```

Here is the type of single record's values:

```perl6
deduce-type(@dsTitanic[12].values.List)
```
```
# Tuple([Atom((Str)), Atom((Str)), Atom((Str)), Atom((Str)), Atom((Int))])
```

Here is the type of the whole dataset:

```perl6
deduce-type(@dsTitanic)
```
```
# Vector(Struct([id, passengerAge, passengerClass, passengerSex, passengerSurvival], [Str, Int, Str, Str, Str]), 1309)
```

------

## TODO

1. [X] Simpler more convenient interface.

   - ~~Currently, a user have to specify four different namespaces
     in order to be able to use all package functions.~~
    
2. [ ] More extensive long format tests.

3. [ ] More extensive wide format tests.

4. [ ] Implement verifications for
   
    - [X] Positional-of-hashes
      
    - [X] Positional-of-arrays
       
    - [X] Positional-of-key-to-array-pairs
    
    - [ ] Positional-of-hashes, each record of which has:
      
       - [ ] Same keys 
       - [ ] Same type of values of corresponding keys
      
    - [ ] Positional-of-arrays, each record of which has:
    
       - [ ] Same length
       - [ ] Same type of values of corresponding elements

5. [X] Implement "nice tabular visualization" using 
   [Pretty::Table](https://gitlab.com/uzluisf/raku-pretty-table)
   and/or
   [Text::Table::Simple](https://github.com/ugexe/Perl6-Text--Table--Simple).

6. [X] Document examples using pretty tables.

7. [X] Implement transposing operation for:
    - [X] hash of hashes
    - [X] hash of arrays
    - [X] array of hashes
    - [X] array of arrays
    - [X] array of key-to-array pairs 

8. [X] Implement to-pretty-table for:
   - [X] hash of hashes
   - [X] hash of arrays
   - [X] array of hashes
   - [X] array of arrays
   - [X] array of key-to-array pairs

9. [ ] Implemented join-across:
   - [X] inner, left, right, outer
   - [X] single key-to-key pair
   - [ ] multiple key-to-key pairs
   - [ ] optional fill-in of missing values
   - [ ] handling collisions
   
10. [ ] Implement to long format conversion for:
    - [ ] hash of hashes
    - [ ] hash of arrays

11. [ ] Speed/performance profiling.
    - [ ] Come up with profiling tests
    - [ ] Comparison with R
    - [ ] Comparison with Python
   
12. [ ] Type system.
    - [X] Base type (Int, Str, Numeric)
    - [X] Homogenous list detection
    - [X] Association detection
    - [X] Struct discovery
    - [ ] Enumeration detection
    - [X] Dataset detection
       - [X] List of hashes
       - [X] Hash of hashes
       - [X] List of lists

13. [ ] "Simple" or fundamental functions 
    - [X] `flatten`
    - [X] `take-drop`
    - [ ] `tally`
       - Currently in "Data::Summarizers".
    
------

## References

### Articles

[AA1] Anton Antonov,
["Contingency tables creation examples"](https://mathematicaforprediction.wordpress.com/2016/10/04/contingency-tables-creation-examples/), 
(2016), 
[MathematicaForPrediction at WordPress](https://mathematicaforprediction.wordpress.com).

[Wk1] Wikipedia entry, [Contingency table](https://en.wikipedia.org/wiki/Contingency_table).

[Wk2] Wikipedia entry, [Wide and narrow data](https://en.wikipedia.org/wiki/Wide_and_narrow_data).

### Functions, repositories

[AAf1] Anton Antonov,
[CrossTabulate](https://resources.wolframcloud.com/FunctionRepository/resources/CrossTabulate),
(2019),
[Wolfram Function Repository](https://resources.wolframcloud.com/FunctionRepository).

[AAf2] Anton Antonov,
[LongFormDataset](https://resources.wolframcloud.com/FunctionRepository/resources/LongFormDataset),
(2020),
[Wolfram Function Repository](https://resources.wolframcloud.com/FunctionRepository).

[AAf3] Anton Antonov,
[WideFormDataset](https://resources.wolframcloud.com/FunctionRepository/resources/WideFormDataset),
(2021),
[Wolfram Function Repository](https://resources.wolframcloud.com/FunctionRepository).

[AAf4] Anton Antonov,
[RecordsSummary](https://resources.wolframcloud.com/FunctionRepository/resources/RecordsSummary),
(2019),
[Wolfram Function Repository](https://resources.wolframcloud.com/FunctionRepository).


### Videos

[AAv1] Anton Antonov,
["Multi-language Data-Wrangling Conversational Agent"](https://www.youtube.com/watch?v=pQk5jwoMSxs),
(2020),
[YouTube channel of Wolfram Research, Inc.](https://www.youtube.com/channel/UCJekgf6k62CQHdENWf2NgAQ).
(Wolfram Technology Conference 2020 presentation.)

[AAv2] Anton Antonov,
["Data Transformation Workflows with Anton Antonov, Session #1"](https://www.youtube.com/watch?v=iXrXMQdXOsM),
(2020),
[YouTube channel of Wolfram Research, Inc.](https://www.youtube.com/channel/UCJekgf6k62CQHdENWf2NgAQ).

[AAv3] Anton Antonov,
["Data Transformation Workflows with Anton Antonov, Session #2"](https://www.youtube.com/watch?v=DWGgFsaEOsU),
(2020),
[YouTube channel of Wolfram Research, Inc.](https://www.youtube.com/channel/UCJekgf6k62CQHdENWf2NgAQ).
