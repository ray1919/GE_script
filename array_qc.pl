#!/usr/bin/env perl
# Author: Zhao
# Date: 2012-03-28
use 5.010;
use File::Copy;
use Data::Table;
mkdir('Array QC');
mkdir('Raw Data Files');
$name = fromTSV('name.txt');
foreach $i ( 0 .. $name->nofRow - 1 ) {
  $file = $name->elm($i,0);
  copy("../$file",'Raw Data Files/'.$name->elm($i,1).'.txt');
  $file =~ s/txt$/pdf/;
  say $file;
  copy("../$file",'Array QC/Array QC Report for '.$name->elm($i,1).'.pdf');
}

sub fromTSV{
  my $file = $_[0] || die "File not declared!";
  my %fileGuessOS = ( 0 => "UNIX", 1 => "DOS", 2 => "MAC" );
  print "read $file in ",$fileGuessOS{Data::Table::fromFileGuessOS($file)}," format.\n";
  return Data::Table::fromTSV($file,1,undef,
      {OS=>Data::Table::fromFileGuessOS($file),
      skip_pattern=>'^\s*#'});
}
