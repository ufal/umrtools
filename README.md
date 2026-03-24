# Tools for Uniform Meaning Representation data

## File format validator

See `doc/umr_file_format_specification.pdf` for a quick description of the `.umr` file format. Use this script
to check that a UMR file follows the specification and the
[UMR annotation guidelines](https://github.com/ufal/umr-guidelines/blob/master/guidelines.md).

```
python validate.py --help
```

## UMR file comparing

Use this to compare two UMR files, e.g., manual annotations of the same sentences by two different annotators,
or gold standard compared with the output of a UMR parser. Get juːmæʧ F₁ score along with detailed analysis of
mismatches.

```
perl compare_umr.pl --help
```
