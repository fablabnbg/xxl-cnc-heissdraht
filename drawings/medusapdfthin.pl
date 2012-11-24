#!/usr/bin/perl
#
# pdfs printed by medusa4 use fat stroke widths and a very slow dash pattern.
#
# This script tries to postprocess these artefacts to make prints look more
# like the original on screen.
#
#  2012-07-30, 0.01 jw -- initial draught.


my $verbose = 1;
my $infile = shift;
my $thinning = shift || 8;


my %w_stat;
sub thinning
{
  my ($width) = @_;
  # 24,17,12,9 ->
  # 6,.....,1
  my $r = $width*$width/($thinning*$thinning);
  $w_stat{$r}++;
  return $r;
}

sub run;

my $outfile = $infile;
$outfile =~ s{\.pdf}{}i;
my $tmpfile1 = $outfile . "_tmp1_$$.pdf";
my $tmpfile2 = $outfile . "_tmp2_$$.pdf";
$outfile .= "_thinned.pdf";

print "$infile -> [$thinning] -> $outfile\n";

run "pdftk '$infile' output '$tmpfile1' uncompress";

open IN,  "<", $tmpfile1 or die "cannot slurp back tmpfile $tmpfile: $!\n";
open OUT, ">", $tmpfile2 or die "cannot write output $output: $!\n";

while (defined(my $line = <IN>))
  {
    # B*
    # 0 0 0 SCN
    # 12 w 1 J 2 j [] 0 d
    # 4586 10076 m
    # 4536 9797 l
    # B*
    # 4519 9704 m
    # 4469 9425 l
    # B*
    #### the three numbers before SCN are the color. Black here.
    #### the number before the w is the line width.
    if ($line =~ m{^([\d\.]+)\s+w\s(.*)$})
      {
        my ($w, $rest) = ($1, $2);
	$line = thinning($w). " w $rest\n";
      }

    print OUT $line;
  }

close IN;
close OUT or die "could not write tmpfile $tmpfile2: $!\n";
unlink $tmpfile1;

## This is needed, not for compression but to 
## repair the struture offsets.
# run "pdftk '$tmpfile2' output '$outfile'";
run "pdftk '$tmpfile2' output '$outfile' compress";

unlink $tmpfile2;

my $max = 0;
for my $k (keys %w_stat)
  {
    $max = $w_stat{$k} if $w_stat{$k} > $max;
  }
print "\nThe values should well distributed in the range [1..9]\n";
for my $k (sort { $a <=> $b } keys %w_stat)
  {
    my $bar = int($w_stat{$k}*50./$max)+1;
    printf "%5.2f %s\n", $k, '#' x $bar;
  }

exit 0;
sub run
{
  my ($cmd) = @_;
  print "+ $cmd\n" if $verbose;
  system $cmd and die "ERROR: $cmd\n failed. $! $?\n";
}
