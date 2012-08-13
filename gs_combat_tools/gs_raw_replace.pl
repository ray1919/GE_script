#!/usr/bin/env perl
# Ahthor: Zhao
# Date: 2012-05-04
# Purpose: 将gs导出文件的raw数据替换为另一个atv里面的raw数据
# Note: all_raw.txt 为原始数值对照的文件，导出时只选raw data，注释什么不要，
# 可以加快计算

use warnings;
use Data::Table;
use 5.010;
use Smart::Comments;
use Statistics::Basic qw/average/;
use threads;
use Thread::Semaphore;
$cpus      = 10;
$semaphore = new Thread::Semaphore($cpus);

$all_file  = 'all_raw.txt';
$name_file = 'name.txt';
@files     = glob 'group*.txt sample*.txt';

say 'Replace raw data in:';
say join( "\n", @files );
say "using coresponding data in $all_file";

$all_tbl  = fromTSV($all_file);
$name_tbl = fromTSV($name_file);
$is_group = $name_tbl->nofCol == 2 ? 0 : 1;
foreach $file (@files) {
  $semaphore->down();
  $thread = async {
    $tbl     = fromTSV($file);
    @header  = $tbl->header;
    $row_num = $tbl->nofRow - 1;
    foreach $r ( 0 .. $row_num ) {
      $match = $all_tbl->match_pattern(
        '$_->[0] eq "' . $tbl->elm( $r, $header[0] ) . '"' );
      unless ( $match->nofRow == 1 ) {
        say "row number not correct for ", $tbl->elm( $r, $header[0] );
      }
      %raw_val = ();
      foreach $i ( 0 .. $name_tbl->nofRow - 1 ) {
        if ( $file =~ /sample/ ) {
          if ( $is_group == 1 ) {
            $colID = join( '',
              '[', $name_tbl->elm( $i, 'Sample' ),
              ', ', $name_tbl->elm( $i, 'Group' ), '](raw)' );
          }
          else {
            $colID = join( '', '[', $name_tbl->elm( $i, 'Sample' ), '](raw)' );
          }
          next if ( $tbl->colIndex($colID) == -1 );

          $colID_all = join( '', $name_tbl->elm( $i, 'Samples' ), ':gProcessedSignal(raw)' );
          $raw_val = $match->elm( 0, $colID_all );
          $tbl->setElm( $r, $colID, $raw_val );
        }
        elsif ( $file =~ /group/ ) {
          $gn = $name_tbl->elm( $i, 'Group' );
          $colID = join( '', '[', $gn, '](raw)' );
          next if ( $tbl->colIndex($colID) == -1 );

          $colID_all = join( '', $name_tbl->elm( $i, 'Samples' ), ':gProcessedSignal(raw)' );
          push( @{ $raw_val{$gn} }, $match->elm( 0, $colID_all ) );
        }
        else {
          die 'OMG!';
        }
      }
      foreach $gn ( keys %raw_val ) {
        $colID = join( '', '[', $gn, '](raw)' );
        $tbl->setElm( $r, $colID, average( $raw_val{$gn} ) * 1 );
      }
      if ( $r % 500 == 0 ) {
        &bar( $r, $row_num );
        say $file;
      }
    }
    outputTSV( $tbl, $file . '.mo' );
    $file =~ s/\(/\\(/g;
    $file =~ s/\)/\\)/g;
    `grep ^\\# $file > $file.com`;
    `cat $file.mo >> $file.com`;
    `rm -f $file.mo`;
    say "$file done";
    $semaphore->up();
  };
  $thread->detach();
}

&waitquit;

sub waitquit {
  my $num = 0;
  while ( $num < $cpus ) {
    $semaphore->down();
    $num++;
  }
  $semaphore->up($cpus);
}

sub fromTSV {
  my $file = $_[0] || die "File not declared!";
  my %fileGuessOS = ( 0 => "UNIX", 1 => "DOS", 2 => "MAC" );
  print "read $file in ", $fileGuessOS{ Data::Table::fromFileGuessOS($file) },
    " format.\n";
  return Data::Table::fromTSV(
    $file, 1, undef,
    {
      OS           => Data::Table::fromFileGuessOS($file),
      skip_pattern => '^\s*#'
    }
  );
}

sub outputTSV {
  my ( $table, $file, $header ) = @_;
  print "outputTSV() parameter ERROR!" unless defined $table;
  $header = defined $header ? $header : 1;
  if ( defined $file ) {
    $table->tsv( $header, { OS => 0, file => $file } );
  }
  else {
    print $table->tsv( $header, { OS => 0, file => undef } );
  }
  return $table->tsv( $header, { OS => 0, file => undef } );
}

sub bar {
  local $| = 1;
  my $i = $_[0] || return 0;
  my $n = $_[1] || return 0;
  print "\r["
    . ( "#" x int( ( $i / $n ) * 50 ) )
    . ( " " x ( 50 - int( ( $i / $n ) * 50 ) ) ) . "]";
  printf( "%2.1f%%", $i / $n * 100 );
  local $| = 0;
}
