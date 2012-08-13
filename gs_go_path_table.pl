#!/usr/bin/env perl
# Author: Zhao
# Date: 2012-05-10
# Purpose：提取GO patway报告里需要填在word中的部分

use Data::Table;
use 5.010;

@gofiles = glob 'GO\ Analysis\ Report/*-*';
@pafiles = glob 'Pathway\ Analysis\ Report/*-*';

map {s/ /\\ /g} @gofiles;
map {s/ /\\ /g} @pafiles;

$i = 1;

$file_idx = shift || 1;

@patxt = glob "$pafiles[$file_idx]/*.txt";
foreach $file (@patxt) {
  $tbl = &fromTSV($file);
  $prows = 9;
  if ( $tbl->nofRow < $prows ) {
    say "$file less than 9 lines";
    $prows = $tbl->nofRow
  }
  @cols = ('PathwayID', 'Definition', 'Fisher-Pvalue', 'Enrichment_Score', 'Genes');
  $sub = $tbl->subTable([0 .. ($prows - 1)],[@cols]);
  $sub->colMap('Genes', sub{s#^(.+?//.+?//).*#$1...#;$_});
  @dots = map {'...'} 1 .. $prows;
  $sub->addCol(\@dots,'c1',2);
  $sub->addCol(\@dots,'c2',4);
  &outputTSV($sub, $i++);
}

@gotxt = glob "$gofiles[$file_idx]/*.txt";
foreach $file (@gotxt) {
  $tbl = &fromTSV($file);
  if ( $tbl->nofRow < 4 ) {
    say "$file less than 4 lines";
    exit;
  }
  @cols = ('GO.ID', 'Term', 'Pvalue', 'FDR', 'GENES');
  $sub = $tbl->subTable([0..3],[@cols]);
  $sub->colMap('GENES', sub{s#^(.+?//.+?//).*#$1...#;$_});
  $sub->addCol([qw/... ... ... .../],'c1',2);
  $sub->addCol([qw/... ... ... .../],'c2',5);
  &outputTSV($sub, $i++);
}

`cat ? > 1.txt`;
`rm ? -f`;

sub fromTSV{
  my $file = $_[0] || die "File not declared!";
  my %fileGuessOS = ( 0 => "UNIX", 1 => "DOS", 2 => "MAC" );
  print "read $file in ",$fileGuessOS{Data::Table::fromFileGuessOS($file)}," format.\n";
  return Data::Table::fromTSV($file,1,undef,
      {OS=>Data::Table::fromFileGuessOS($file),
      skip_pattern=>'^\s*#'});
}

sub outputTSV{
  my ($table,$file,$header) = @_;
  print "outputTSV() parameter ERROR!" unless defined $table;
  $header = defined $header ? $header : 1;
  if( defined $file ){
    $table->tsv($header, {OS=>0, file=>$file});
  }else{
    print $table->tsv($header, {OS=>0, file=>undef});
  }
  return $table->tsv($header, {OS=>0, file=>undef});
}
