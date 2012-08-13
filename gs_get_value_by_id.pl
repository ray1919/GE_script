#!/usr/bin/env perl
# Author: Zhao
# Date: 2012-05-08
# Purpose: 根据ProbeName或GeneSymbol整理做做聚类的数据。

use 5.010;
use Data::Table;
use Smart::Comments;

$all = fromTSV('all.exp');
# $dif = fromTSV('dif.exp');

@files = glob '*.txt';
foreach $file (@files) {
  @content = &uniq_ary($file);
  $file =~ s/txt$/cl/;
  &get_by_probename($all,\@content,$file);
}

@files = glob '*.gs';
foreach $file (@files) {
  @content = &uniq_ary($file);
  $file =~ s/gs$/cl/;
  &get_by_genename($all,\@content,$file);
}

sub get_by_genename {
  my $tbl = $_[0];
  my $pns = $_[1];
  my $filesave = $_[2];
  ### File to be saved: $filesave
  @header = $tbl->header;
  foreach $i ( 0 .. $#header ) {
    $gn_idx = $i if ( $header[$i] eq 'GENE_NAME' );
    $sy_idx = $i if ( $header[$i] eq 'SYNONYMS' );
  }
  @data_cols = grep {/\(raw\)/} @header;
  $cl_tbl = new Data::Table( $data = [], $header = [@header], $type = 0, $enforceCheck = 1);
  foreach $gn ( @$pns ) {
    # 先匹配 GENE_NAME
    $m_tbl = $tbl->match_pattern('$_->['.$gn_idx.'] =~ /\b'.$gn.'\b/i');
    if ($m_tbl->nofRow > 0) {
      $cl_tbl->rowMerge($m_tbl);
    }
    else {
      # 再匹配 SYNONYMS
      $m_tbl = $tbl->match_pattern('$_->['.$sy_idx.'] =~ /\b'.$gn.'\b/i');
      if ($m_tbl->nofRow > 0) {
        $m_tbl->colMap('GENE_NAME', sub {"$_ ($gn)"});
        $cl_tbl->rowMerge($m_tbl);
      }
      else {
        say $gn, ' NOT FOUND!';
      }
    }
  }
  $cl_tbl->colsMap(sub {$_->[$gn_idx] .= " - $_->[0]"});
  @cl_cols = ('GENE_NAME',@data_cols);
  $cl_tbl = $cl_tbl->subTable(undef, [@cl_cols]);
  map {s/^\[//} @cl_cols;
  map {s/\].*//} @cl_cols;
  $cl_tbl->header([@cl_cols]);
  &outputTSV($cl_tbl, $filesave);
}

sub get_by_probename {
  my $tbl = $_[0];
  my $pns = $_[1];
  my $filesave = $_[2];
  @header = $tbl->header;
  foreach $i ( 0 .. $#header ) {
    $gn_idx = $i if ( $header[$i] eq 'GENE_NAME' );
    $sy_idx = $i if ( $header[$i] eq 'SYNONYMS' );
  }
  @data_cols = grep {/\(raw\)/} @header;
  @probe_names = $tbl->col('SEQ_ID');
  @data_rows = ();
  foreach $i ( 0 .. $#probe_names ) {
    if ( $probe_names[$i] ~~ @$pns ) {
      push(@data_rows, $i);
    }
  }
  $tbl->colsMap(sub {$_->[$gn_idx] .= " - $_->[0]"});
  @cl_cols = ('GENE_NAME',@data_cols);
  $cl_tbl = $tbl->subTable([@data_rows], [@cl_cols]);
  map {s/^\[//} @cl_cols;
  map {s/, .*//} @cl_cols;
  $cl_tbl->header([@cl_cols]);
  &outputTSV($cl_tbl, $filesave);
  ### File saved: $filesave
}

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

sub max {
  my @a = @_;
  my $max = $a[0];
  map {$max = $_ > $max ? $_ : $max} @a;
  return $max;
}

sub uniq_ary {
  my $file = shift;
  my %content = ();
  open(IN,$file) || die $!;
  while (<IN>) {
    chomp;
    $content{$_} = 1;
  }
  close(IN);
  return keys %content;
}
