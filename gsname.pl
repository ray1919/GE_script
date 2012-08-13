#!/usr/bin/env perl
use Data::Table;

$tn = fromTSV('name.txt');
$tn->addCol([$tn->col('Samples')],'Sample');
$tn->colMap('Sample',sub{s/_532_RMA.calls//;$_});
$tn->addCol([$tn->col('Sample')],'Group');
$tn->colMap('Group',sub{s/\d+$//;$_});
outputTSV($tn);
outputTSV($tn,'name.txt');


sub fromTSV{
  my $file = $_[0] || die "File not declared!";
  my %fileGuessOS = ( 0 => "UNIX", 1 => "DOS", 2 => "MAC" );
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

