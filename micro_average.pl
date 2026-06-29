#!/usr/bin/env perl
# Reads outputs from compare_umr.pl --tsv for multiple documents.
# Writes aggregated tsv with counts summed up and P, R, F1 computed over sums.
# The script currently processes only certain predefined metrics.
# Copyright © 2026 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ':utf8';
binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');
use Getopt::Long;

sub usage
{
    print STDERR ("Usage: $0 eval1.tsv eval2.tsv [eval3.tsv ...] > micro-average-eval.tsv\n");
}

my $override_system_output_folder;
my $evaltype = 'eval'; # part of file name to look for, e.g., zh-0036.eval.log
my $pud = 0; # -1: exclude PUD; +1: only PUD; 0 everything including PUD
GetOptions
(
    'sysoutpath=s' => \$override_system_output_folder,
    'evaltype=s'   => \$evaltype,
    'pud=i' => \$pud
);

my $system_unpacked_folder = $override_system_output_folder // $config::config{system_unpacked_folder};
# List of language codes and names.
my %languages = %{$config::config{languages}};
my @languages = sort {$languages{$a} cmp $languages{$b}} (keys(%languages));
# List of documents for each language.
my %test_data = %{$config::config{test_data}};
# Enhancement type selection for each treebank (only for information in the table).
my %enhancements = %{$config::config{enhancements}};

if(scalar(@ARGV)==0)
{
    usage();
    die("Expected at least 1 argument (but running the script makes sense only if there are at least 2)");
}

# Currently there is this fixed list of metrics that we search for and average.
# Note that we also know what fields they contain ('node projections' differing from the rest).
my @metrics = ('aligned token sets', 'node projections', 'triples in mapped nodes', 'juːmæʧ');
my %score; # indexed by document (file) name
my %lscore; # total score for "language" (all documents)
my $label0; # e.g., 'GOLD'
my $label1; # e.g., 'SYSTEM'
foreach my $file (@ARGV)
{
    open(EVAL, $file) or die("Cannot read '$file': $!");
    while(<EVAL>)
    {
        s/\r?\n$//;
        my @f = split(/\t/);
        my $metric = $f[0];
        if(!defined($label0))
        {
            $label0 = $f[1];
        }
        elsif($f[1] ne $label0)
        {
            print STDERR ("WARNING: Labels of the left source differ! Expected '$label0', found '$f[1]'.\n");
        }
        if(!defined($label1))
        {
            $label1 = $f[2];
        }
        elsif($f[2] ne $label1)
        {
            print STDERR ("WARNING: Labels of the right source differ! Expected '$label1', found '$f[2]'.\n");
        }
        if($metric eq 'node projections')
        {
            $score{document}{$file}{$metric} =
            {
                'mapped0' => $f[3],
                'mapped1' => $f[4],
                'total0'  => $f[5],
                'total1'  => $f[6],
                'p'       => $f[7],
                'r'       => $f[8],
                'f'       => $f[9]
            };
            $lscore{$metric}{mapped0} += $f[3];
            $lscore{$metric}{mapped1} += $f[4];
            $lscore{$metric}{total0} += $f[5];
            $lscore{$metric}{total1} += $f[6];
        }
        # Avoid unknown metrics. They may have unexpected number or order of fields.
        elsif(grep {$metric eq $_} (@metrics))
        {
            $score{document}{$file}{$metric} =
            {
                'correct' => $f[3],
                'total0'  => $f[4],
                'total1'  => $f[5],
                'p'       => $f[6],
                'r'       => $f[7],
                'f'       => $f[8]
            };
            $lscore{$metric}{correct} += $f[3];
            $lscore{$metric}{total0} += $f[4];
            $lscore{$metric}{total1} += $f[5];
        }
    }
    close(EVAL);
}

# Compute micro-average score over all documents.
foreach my $metric (@metrics)
{
    if($metric eq 'node projections')
    {
        my $lr = $lscore{$metric}{total0} > 0 ? $lscore{$metric}{mapped0}/$lscore{$metric}{total0} : 0;
        my $lp = $lscore{$metric}{total1} > 0 ? $lscore{$metric}{mapped1}/$lscore{$metric}{total1} : 0;
        my $lf = $lp+$lr > 0 ? 2*$lp*$lr/($lp+$lr) : 0;
        $lscore{$metric}{p} = $lp;
        $lscore{$metric}{r} = $lr;
        $lscore{$metric}{f} = $lf;
    }
    else
    {
        my $lr = $lscore{$metric}{total0} > 0 ? $lscore{$metric}{correct}/$lscore{$metric}{total0} : 0;
        my $lp = $lscore{$metric}{total1} > 0 ? $lscore{$metric}{correct}/$lscore{$metric}{total1} : 0;
        my $lf = $lp+$lr > 0 ? 2*$lp*$lr/($lp+$lr) : 0;
        $lscore{$metric}{p} = $lp;
        $lscore{$metric}{r} = $lr;
        $lscore{$metric}{f} = $lf;
    }
}

print_tsv($label0, $label1, \%score, @metrics);



#------------------------------------------------------------------------------
# Prints collected metrics as TSV (tab separated values).
#------------------------------------------------------------------------------
sub print_tsv
{
    my $label0 = shift; # label of the left data source
    my $label1 = shift; # label of the right data source
    my $score = shift; # hash ref
    my @metrics = @_; # names of metrics to be printed = keys to %{$score}
    foreach my $metric (@metrics)
    {
        if($metric eq 'node projections')
        {
            print("$metric\t$label0\t$label1\t$score->{$metric}{mapped0}\t$score->{$metric}{mapped1}\t$score->{$metric}{total0}\t$score->{$metric}{total1}\t$score->{$metric}{p}\t$score->{$metric}{r}\t$score->{$metric}{f}\tmapped0 mapped1 total0 total1 p r f\n");
        }
        else
        {
            print("$metric\t$label0\t$label1\t$score->{$metric}{correct}\t$score->{$metric}{total0}\t$score->{$metric}{total1}\t$score->{$metric}{p}\t$score->{$metric}{r}\t$score->{$metric}{f}\tcorrect total0 total1 p r f\n");
        }
    }
}



#------------------------------------------------------------------------------
# Prints collected metrics as a HTML table.
#------------------------------------------------------------------------------
sub print_html
{
    my $label0 = shift; # label of the left data source
    my $label1 = shift; # label of the right data source
    my $score = shift; # hash ref
    my @metrics = @_; # names of metrics to be printed = keys to %{$score}
    my $html = "<html>\n";
    $html .= "<head>\n";
    $html .= "  <title>UMR Comparison of $label0 to $label1</title>\n";
    $html .= "</head>\n";
    $html .= "<body>\n";
    $html .= "  <h1>UMR Comparison of $label0 to <span style='color:blue'>$label1</span></h1>\n";
    $html .= "  <h2>F<sub>1</sub> Scores</h2>\n";
    $html .= "  <p>Each score pertains to the combined test set of the language, without distinguishing individual documents.</p>\n";
    $html .= "  <table>\n";
    $html .= "    <tr><td><b>Language</b></td>";
    foreach my $metric (@metrics)
    {
        $html .= "<td><b>$metric</b></td>";
    }
    $html .= "</tr>\n";
    $html .= "    <tr><td>x</td>";
    foreach my $metric (@metrics)
    {
        $html .= "<td>$score->{$metric}{f}</td>";
    }
    $html .= "</tr>\n";
    $html .= "  </table>\n";
    $html .= "</body>\n";
    $html .= "</html>\n";
    print($html);
}
