#!/usr/bin/env perl
# Author: Zhao
# Date: 2012-05-03
# Purpose: 把导出的all entity数据简化为combat数据，简化命名

use Data::Table;
use 5.010;

$file = 'all.txt';
$all = fromTSV($file);
@header = $all->header;
@names = grep {/normalized/} @header;
$sub = $all->subTable(undef,[$header[0],@names]);

$name_file = 'name.txt';
$name = fromTSV($name_file);
@sample = map {s/\.txt.*/\.txt/;$t = $name->match_string($_);$t->elm(0,1)} @names;
$sub->header([$header[0],@sample]);
outputTSV($sub,'data.txt');

open(BA,'>batch.txt');
say BA join("\t",'Array name','Sample name','Batch','Covariate 1');
map {say BA join("\t",$_,$_,1,1)} @sample;
close(BA);

@flags = grep {/Flag/} @header;
$flag_tbl = $all->subTable(undef,\@flags);
@flag_names = map {s/\.txt.*/\.txt/;$t = $name->match_string($_);join('_',$t->elm(0,1),'Flag')} @names;
$flag_tbl->header(\@flag_names);
outputTSV($flag_tbl,'flag.txt');

@anns = grep {!/\.txt/} @header;
$ann_tbl = $all->subTable(undef,\@anns);
outputTSV($ann_tbl,'anns.txt');

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
