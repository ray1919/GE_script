#!/usr/bin/perl -w
# 应用于各种属FE导出的文件的Flag标记(piRNA,lncRNA...通用,只要第10行为每列数值的注释行即可)
#ProbeName	SystematicName	gProcessedSignal	gIsSaturated	gIsFeatNonUnifOL	gIsBGNonUnifOL	gIsFeatPopnOL	gIsBGPopnOL	gIsPosAndSignif	gIsWellAboveBG	Flag

mkdir "flag";
while ( my $filename = <*.txt> ) {
  open( INPUT,   "<$filename" )           or die "error(input):$!";
  open( OUTPUT1, ">./flag/$filename" ) or die "error (output1):$!";
  while (<INPUT>) {
    if (/ProbeName\tSystematicName/i) {
      chomp;
      @ncRNA1 = split( /\t/, $_ );
      for ( my $i = 0 ; $i < @ncRNA1 ; $i++ ) {
        if ( $ncRNA1[$i] eq "ProbeName" ) { $ProbeName      = $i; }    #6
        if ( $ncRNA1[$i] eq "SystematicName" ) { $SystematicName = $i; }    #7
        if ( $ncRNA1[$i] eq "gProcessedSignal" ) {
          $gProcessedSignal = $i;
        }                                                                   #10
        if ( $ncRNA1[$i] eq "gIsSaturated" ) { $gIsSaturated = $i; }        #15
        if ( $ncRNA1[$i] eq "gIsFeatNonUnifOL" ) {
          $gIsFeatNonUnifOL = $i;
        }                                                                   #17
        if ( $ncRNA1[$i] eq "gIsBGNonUnifOL" ) { $gIsBGNonUnifOL = $i; }    #18
        if ( $ncRNA1[$i] eq "gIsFeatPopnOL" )  { $gIsFeatPopnOL  = $i; }    #19
        if ( $ncRNA1[$i] eq "gIsBGPopnOL" )    { $gIsBGPopnOL    = $i; }    #20
        if ( $ncRNA1[$i] eq "gIsPosAndSignif" ) {
          $gIsPosAndSignif = $i;
        }                                                                   #23
        if ( $ncRNA1[$i] eq "gIsWellAboveBG" ) { $gIsWellAboveBG = $i; }    #24
      }
      print OUTPUT1 $ncRNA1[$ProbeName], "\t", $ncRNA1[$SystematicName],
        "\t", $ncRNA1[$gProcessedSignal], "\t", $ncRNA1[$gIsSaturated],
        "\t", $ncRNA1[$gIsFeatNonUnifOL], "\t", $ncRNA1[$gIsBGNonUnifOL],
        "\t", $ncRNA1[$gIsFeatPopnOL],    "\t", $ncRNA1[$gIsBGPopnOL], "\t",
        $ncRNA1[$gIsPosAndSignif], "\t", $ncRNA1[$gIsWellAboveBG], "\t",
        "Flag", "\n";
      while (<INPUT>) {
        my $flag;
        my @temp = split( "\t", $_ );
        if (  $temp[$gIsSaturated] == 0
          and $temp[$gIsFeatNonUnifOL] == 0
          and $temp[$gIsBGNonUnifOL] == 0
          and $temp[$gIsFeatPopnOL] == 0
          and $temp[$gIsBGPopnOL] == 0
          and $temp[$gIsPosAndSignif] == 1
          and $temp[$gIsWellAboveBG] == 1 )
        {
          $flag = "P";
        }
        elsif ( $temp[$gIsSaturated] == 0
          and $temp[$gIsFeatNonUnifOL] == 0
          and $temp[$gIsFeatPopnOL] == 0
          and $temp[$gIsPosAndSignif] == 1
          and $temp[$gIsWellAboveBG] == 1
          and !( $temp[$gIsBGNonUnifOL] == 0 and $temp[$gIsBGPopnOL] == 0 ) )
        {
          $flag = "M";
        }
        else { $flag = "A" }
        print OUTPUT1 $temp[$ProbeName], "\t", $temp[$SystematicName],
          "\t", $temp[$gProcessedSignal], "\t", $temp[$gIsSaturated],
          "\t", $temp[$gIsFeatNonUnifOL], "\t", $temp[$gIsBGNonUnifOL],
          "\t", $temp[$gIsFeatPopnOL],    "\t", $temp[$gIsBGPopnOL], "\t",
          $temp[$gIsPosAndSignif], "\t", $temp[$gIsWellAboveBG], "\t",
          $flag, "\n";
      }
    }
  }
  close(INPUT);
  close(OUTPUT1);
  print "successful!\n";
}
print "complete!\n";
