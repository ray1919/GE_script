#!/usr/bin/env perl
# Author: Zhao Rui
# Date: 2012-03-16
# Purpose: format txt file outputed from Genespring
# Revised: 2012-03-22 13:13
use Data::Table;
use Smart::Comments;
use Excel::Writer::XLSX;
use threads;
use Thread::Semaphore;
use 5.010;
use warnings;

#输入名称
my $cpus      = 3;
my $semaphore = new Thread::Semaphore($cpus);
my $s_prefix  = "sample";
my $g_prefix  = "group";
my $lncRNAdir = 'LncRNA';
my $mRNAdir   = 'mRNA';
my $stime = time;
my $tmpdir = 'temp';

mkdir($tmpdir);
my $assoFile = '/public/WinXPShare/panzhong/10Arraystar_microarray_annotation_files_042011/human_lncRNA_microarray_v2_DesignID033010/add_NMrelationship_human_v2.0/microarray_033010_lncRNA_NM_association_110518_baken.txt';
$scdir = '/public/WinXPShare/panzhong/10Arraystar_microarray_annotation_files_042011/human_lncRNA_microarray_v2_DesignID033010/subgroup_Analysis_huamn_v2.0/';
my $lincRNA = $scdir.
'microarray_033010_human_lncRNA_V2_annotation_20110517_lincRNA.txt';
my $enhancer_lncRNA = $scdir.
'microarray_033010_human_lncRNA_V2_annotation_20110517_enhancer_lncRNA.txt';
my $hox_cluster = $scdir.
'microarray_033010_human_lncRNA_V2_annotation_20110517_Hox_cluster.txt';
my $lincRNA_nearby_NM = $scdir.
'microarray_033010_human_lncRNA_V2_annotation_20110517_lincRNA_extend_overlap_NM_baken.txt';
my $enhancer_nearby_NM = $scdir.
'microarray_033010_human_lncRNA_V2_annotation_20110517_enhancer_lncRNA_extend_overlap_NM_baken.txt';

#主函数 relation
my %relation = ();
### read the annotation file
&read_total($assoFile);
my @files = glob "$lncRNAdir/*.txt";
foreach $filename (@files) {
    $outputFile = $filename;
    $outputFile =~ s/$lncRNAdir/$tmpdir/;
    $outputFile =~ s/\.txt$/_NMrelationship.txt/;
    &add_NMrelationship($filename,$outputFile);
}
### add NMrelationship done
say '<press ENTER to continue>';
<STDIN>;

#主函数 subgroup
my $lncRNA_all = $lncRNAdir.'/'.$s_prefix.'all.txt';
my $NM_all     = $mRNAdir.'/'.$s_prefix.'all.txt';
my $rlpFile    = $tmpdir.'/Rinn_lincRNA_profiling.txt';
my $elpFile    = $tmpdir.'/Enhancer_LncRNA_profiling.txt';
my $hcpFile    = $tmpdir.'/HOX_cluster_profiling.txt';
&get_sub_list( $lincRNA,         $lncRNA_all, $rlpFile );
&get_sub_list( $enhancer_lncRNA, $lncRNA_all, $elpFile );
&get_hox_cluster_list( $hox_cluster, $NM_all, $lncRNA_all, $hcpFile );
@files = glob $tmpdir.'/'.$s_prefix.'*#*_NMrelationship.txt';
my ($lncRNA_de, $elnFile, $lncFile, $NM_de);
foreach $filename (@files) {
    $lncRNA_de = $filename;
    $elnFile    = $filename;
    $elnFile    =~ s#$tmpdir/#$tmpdir/elncncgdt_#;
    $lncFile    = $filename;
    $lncFile    =~ s#$tmpdir/#$tmpdir/lncgdt_#;
    $NM_de      = $filename;
    $NM_de      =~ s/_NMrelationship//;
    $NM_de      =~ s/$tmpdir/$mRNAdir/;
    &get_lncRNA_NM_datapair( $lncRNA_de, $NM_de, $lincRNA_nearby_NM,
        $lncFile );
    &get_lncRNA_NM_datapair( $lncRNA_de, $NM_de, $enhancer_nearby_NM,
        $elnFile );
}
### NMrelationship added to all data files
say '<press ENTER to continue>';
<STDIN>;

&detect_info;

for $wd ($mRNAdir,$lncRNAdir) {
    # 汇总处理
    $semaphore->down();
    $thread = threads->new(\&do_profile,$wd);
    $thread->detach();
    # 差异列表
    $semaphore->down();
    $thread = threads->new(\&do_diff,$wd);
    $thread->detach();
}


if ( -f '../' . $name->elm( 0, 'Samples' ) ) {
    for ( $i = 0 ; $i < $sn ; $i++ ) {
        $sample_name{ '../' . $name->elm( $i, 'Samples' ) } =
                  'prefix_'.$name->elm( $i, 'Sample' );
        $image_name{$i}[0] = '../' . $name->elm( $i, 'Samples' );
        $image_name{$i}[1] = $name->elm( $i, 'Sample' );
    }
    $semaphore->down();
    $thread = threads->new(\&do_raw);
    $thread->detach();

    $semaphore->down();
    $thread = threads->new(\&do_images);
    $thread->detach();
}

$semaphore->down();
$thread = threads->new(\&do_subgroup);
$thread->detach();

&waitquit;
### Job done. <press ENTER to quit> : time - $stime
<STDIN>;
exit;

# read in all the annotation file
sub read_total {
    open( LIST, $_[0] ) or die "error(input2):$!";
    my $tag = 0;
    my $sg  = 0;
    my @name;
    while ( <LIST> ) {
        @name = split("\t", $_ );
        chomp($name[9]);
        $name[9] =~ s/\r$//;
        if ( !$relation{ $name[0] . $name[1] . $name[2] } ) {
            $relation{ $name[0] . $name[1] . $name[2] }[0] =
"$name[3]\t$name[4]\t$name[5]\t$name[6]\t$name[7]\t$name[8]\t$name[9]";
        }
        else {
            $relation{ $name[0] . $name[1] . $name[2] }
              [ @{ $relation{ $name[0] . $name[1] . $name[2] } } ] =
"$name[3]\t$name[4]\t$name[5]\t$name[6]\t$name[7]\t$name[8]\t$name[9]";
        }
        $tag++;
    }
    # say "there are $tag unique record in the list file!";
}

sub add_NMrelationship {
    ### add NMrelationship to :$_[0]
    open( TOTAL, $_[0] ) or die "error(input2):$!";

    # 打开文件，准备从文件中读取DNA序列。
    open( CONTAIN, ">$_[1]" ) or die "error (output1):$!";
    my $line;
    my $gotlist    = 0;
    my $annotation = 0;
    # anchor the column number of type
    while ( $line = <TOTAL> ) {
        if ( $line =~ /^#/ ) {
            print CONTAIN $line;
        }
        else {
            chomp $line;
            print CONTAIN "$line\t$relation{'seqnamechromtxStart'}[0]\n";
            my @terms = split( /\t/, $line );
            for ( my $i = 0 ; $i <= $#terms ; $i++ ) {
                if ( $terms[$i] eq 'seqname' ) {
                    $seqname = $i;
                }
                if ( $terms[$i] eq 'chrom' ) {
                    $chrom_i = $i;
                }
                if ( $terms[$i] eq 'txStart' ) {
                    $txStart_i = $i;
                }
            }
            last;
        }
    }
    while ( $line = <TOTAL> ) {
        if ( $line !~ /^\#/ ) {
            chomp $line;
            my @terms = split( /\t/, $line );
            $name = $terms[$seqname];
            my $chrom   = $terms[$chrom_i];
            my $txStart = $terms[$txStart_i];
            # if ($relation{ $name.$chrom.$txStart }[0] ne "" ){
            if (defined $relation{ $name.$chrom.$txStart }[0]){
                my $i = 0;
                # while ( $relation{ $name.$chrom.$txStart }[$i] ne "" ) {
                while (defined $relation{ $name.$chrom.$txStart }[$i]) {
                    $gotlist++;
                    $line = join( "\t",
                        @terms,
                        $relation{ ${name} . ${chrom} . ${txStart} }[$i] );
                    say CONTAIN $line;
                    $i++;
                }
            }
            else {
                print CONTAIN $line, " \t" x 7, "\n";
            }
        }
    }
    say "$gotlist records have annotation!";
    close TOTAL;
    close CONTAIN;
    # say "successful add NMrelationship for $_[0].";
}

sub get_sub_list {
    open( LIST,   $_[0] )      or die "error(input2):$!";
    open( TOTAL,  $_[1] )      or die "error(input2):$!";
    open( OUTPUT, ">$_[2]" ) or die "error (output1):$!";

    my %sublist = ();
    my $line;
    my @name;
    my @terms;
    my $name;

    $line = <LIST>;
    while ( $line = <LIST> ) {
        chomp $line;
        @name = split( /\t/, $line );
        $sublist{ $name[0] } = 1;
    }

    my $count = keys(%sublist);

    my %gotlist = ();
    while ( $line = <TOTAL> ) {
        if ( not $line =~ /^\#/ ) {
            print OUTPUT "$line";
            last;
        }
    }

    while ( $line = <TOTAL> ) {
        if ( $line =~ /^\#/ ) {

            # print "$line";
        }
        else {
            $name  = "KKKKKKK";
            @terms = split( /\t/, $line );
            $name  = $terms[0];
            chomp $name;
            if ( exists( $sublist{$name} ) ) {
                $gotlist{$name} = 1;
                print OUTPUT "$line";
            }
            else {

                # $j++;
                # print  UNIQ "$line";
                # print "find $j unique line!\n";
            }
        }
    }

    my $count1 = keys %gotlist;

    close TOTAL;
    close LIST;
    close OUTPUT;
    print "there are $count unique record in the list file!\n";
    print "there are $count1 unique record in the gotlist file!\n";
    print "successful get the sublist!\n";
}

sub get_hox_cluster_list {
    open( LIST,   $_[0] )      or die "error(input2):$!";
    open( TOTAL1, $_[1] )      or die "error(input2):$!";
    open( TOTAL2, $_[2] )      or die "error(input2):$!";
    open( OUTPUT, ">$_[3]" ) or die "error (output1):$!";

    my %sublist = ();
    my $line;
    my @name;
    my @terms;
    my $name;

    $line = <LIST>;
    while ( $line = <LIST> ) {
        chomp $line;
        @name = split( /\t/, $line );
        $sublist{ $name[0] } = 1;
    }

    my $count = keys(%sublist);

    my %gotlist = ();
    while ( $line = <TOTAL1> ) {
        if ( not $line =~ /^\#/ ) {
            print OUTPUT "$line";
            last;
        }
    }

    while ( $line = <TOTAL1> ) {
        if ( $line =~ /^\#/ ) {

            # print "$line";
        }
        else {
            $name  = "KKKKKKK";
            @terms = split( /\t/, $line );
            $name  = $terms[0];
            chomp $name;
            if ( exists( $sublist{$name} ) ) {
                $gotlist{$name} = 1;
                print OUTPUT "$line";
            }
            else {

                # $j++;
                # print  UNIQ "$line";
                # print "find $j unique line!\n";
            }
        }
    }

    while ( $line = <TOTAL2> ) {
        if ( $line =~ /^\#/ ) {

            # print "$line";
        }
        else {
            $name  = "KKKKKKK";
            @terms = split( /\t/, $line );
            $name  = $terms[0];
            chomp $name;
            if ( exists( $sublist{$name} ) ) {
                $gotlist{$name} = 1;
                $line =~ s/\n$/\t\t\t\t\t\n/;
                print OUTPUT $line;
            }
            else {

                # $j++;
                # print  UNIQ "$line";
                # print "find $j unique line!\n";
            }
        }
    }

    my $count1 = keys %gotlist;

    close LIST;
    close TOTAL1;
    close TOTAL2;
    close OUTPUT;
    print "there are $count unique record in the list file!\n";
    print "there are $count1 unique record in the gotlist file!\n";
    print "successful get the sublist!\n";
}

sub get_lncRNA_NM_datapair {
    open( LNC,    $_[0] )  or die "error(input2):$!";
    open( NM,     $_[1] )  or die "error($_[1]):$!";
    open( NEARBY, $_[2] )  or die "error(input2):$!";
    open( OUTPUT, ">$_[3]" ) or die "error (output1):$!";
    my %data    = ();
    my %chrom   = ();
    my %txStart = ();

    my $line;
    my $tag = 0;

    my $p;
    my $foldchange;
    my $regulation;
    my $seqname;
    my $chrom;
    my $txStart;

    my @terms;
    my @name;
    my $name;
    my $i;

    while ( $line = <LNC> ) {
        if ( not $line =~ /^\#/ ) {
            chomp $line;
            if ( $line =~ /p-value/ ) {
                $type = "group";
                @terms = split( /\t/, $line );
                for ( $i = 0 ; $i <= $#terms ; $i++ ) {
                    if ( $terms[$i] eq 'p-value' ) {
                        $p = $i;
                    }
                    elsif ( $terms[$i] eq 'FCAbsolute' ) {
                        $foldchange = $i;
                    }
                    elsif ( $terms[$i] eq 'regulation' ) {
                        $regulation = $i;
                    }
                    elsif ( $terms[$i] eq 'seqname' ) {
                        $seqname = $i;
                    }
                    elsif ( $terms[$i] eq 'chrom' ) {
                        $chrom = $i;
                    }
                    elsif ( $terms[$i] eq 'txStart' ) {
                        $txStart = $i;
                    }
                }
                last;
            }
            else {
                $type = "sample";
                @terms = split( /\t/, $line );
                for ( $i = 0 ; $i <= $#terms ; $i++ ) {
                    $AbsoluteFoldchange = 3;
                    $logfoldchange      = 2;
                    $foldchange         = 1;
                    if ( $terms[$i] =~ /^Regulation/ ) {
                        $regulation = $i;
                    }
                    elsif ( $terms[$i] eq 'seqname' ) {
                        $seqname = $i;
                    }
                    elsif ( $terms[$i] eq 'chrom' ) {
                        $chrom = $i;
                    }
                    elsif ( $terms[$i] eq 'txStart' ) {
                        $txStart = $i;
                    }
                }
                last;
            }
        }
    }

    while ( $line = <LNC> ) {

        if ( not $line =~ /^\#/ and $type eq "group" ) {
            chomp $line;
            @name         = split( /\t/, $line );
            $name         = $name[$seqname];
            $data{$name}  = "$name[$p]\t$name[$foldchange]\t$name[$regulation]";
            $chrom{$name} = $name[$chrom];
            $txStart{$name} = $name[$txStart];
        }
        if ( not $line =~ /^\#/ and $type eq "sample" ) {
            chomp $line;
            @name = split( /\t/, $line );
            $name = $name[$seqname];
            $data{$name} =
"$name[$foldchange]\t$name[$logfoldchange]\t$name[$AbsoluteFoldchange]\t$name[$regulation]";
            $chrom{$name}   = $name[$chrom];
            $txStart{$name} = $name[$txStart];
        }
    }

    while ( $line = <NM> ) {
        if ( not $line =~ /^\#/ ) {
            chomp $line;
            if ( $line =~ /p-value/ ) {
                $type = "group";
                @terms = split( /\t/, $line );
                for ( $i = 0 ; $i <= $#terms ; $i++ ) {
                    if ( $terms[$i] eq 'p-value' ) {
                        $p = $i;
                    }
                    elsif ( $terms[$i] eq 'FCAbsolute' ) {
                        $foldchange = $i;
                    }
                    elsif ( $terms[$i] eq 'regulation' ) {
                        $regulation = $i;
                    }
                    elsif ( $terms[$i] eq 'seqname' ) {
                        $seqname = $i;
                    }
                    elsif ( $terms[$i] eq 'chrom' ) {
                        $chrom = $i;
                    }
                    elsif ( $terms[$i] eq 'txStart' ) {
                        $txStart = $i;
                    }
                }
                last;
            }
            else {
                $type = "sample";
                @terms = split( /\t/, $line );
                for ( $i = 0 ; $i <= $#terms ; $i++ ) {
                    $AbsoluteFoldchange = 3;
                    $logfoldchange      = 2;
                    $foldchange         = 1;
                    if ( $terms[$i] =~ /^Regulation/ ) {
                        $regulation = $i;
                    }
                    elsif ( $terms[$i] eq 'seqname' ) {
                        $seqname = $i;
                    }
                    elsif ( $terms[$i] eq 'chrom' ) {
                        $chrom = $i;
                    }
                    elsif ( $terms[$i] eq 'txStart' ) {
                        $txStart = $i;
                    }
                }
                last;
            }
        }
    }
    while ( $line = <NM> ) {

        if ( not $line =~ /^\#/ and $type eq "group" ) {
            chomp $line;
            @name         = split( /\t/, $line );
            $name         = $name[$seqname];
            $data{$name}  = "$name[$p]\t$name[$foldchange]\t$name[$regulation]";
            $chrom{$name} = $name[$chrom];
            $txStart{$name} = $name[$txStart];
        }
        if ( not $line =~ /^\#/ and $type eq "sample" ) {
            chomp $line;
            @name = split( /\t/, $line );
            $name = $name[$seqname];
            $data{$name} =
"$name[$foldchange]\t$name[$logfoldchange]\t$name[$AbsoluteFoldchange]\t$name[$regulation]";
            $chrom{$name}   = $name[$chrom];
            $txStart{$name} = $name[$txStart];
        }
    }

    my %gotlist = ();

    my $gene;
    my $genechrom;
    my $genetxStart;

    #标题
    $line = <NEARBY>;
    chomp $line;
    @terms = split( /\t/, $line );
    for ( $i = 0 ; $i <= $#terms ; $i++ ) {
        if ( $terms[$i] eq 'seqname' ) {
            $seqname = $i;
        }
        elsif ( $terms[$i] eq 'chrom' ) {
            $chrom = $i;
        }
        elsif ( $terms[$i] eq 'txStart' ) {
            $txStart = $i;
        }
        elsif ( $terms[$i] eq 'NearbyGene' ) {
            $gene = $i;
        }
        #elsif ( $terms[$i] eq 'NearbyProteinName' ) {
        #    $protein = $i;
        #}
        elsif ( $terms[$i] eq 'NearbyGeneChrom' ) {
            $genechrom = $i;
        }
        elsif ( $terms[$i] eq 'NearbyGenetxStart' ) {
            $genetxStart = $i;
        }
    }
    if ( $type eq "sample" ) {
        print OUTPUT
"seqname\tGeneSymbol\tFold change - LncRNAs\tLog Fold change - lncRNAs\tAbsolute Fold change - lncRNAs\tRegulation\tsource\tRNAlength\tChrom\tStrand\ttxStart\ttxEnd\tGenomeRelationship\tNearbyGene\tNearbyGeneSymbol\tNearbyProteinName\tFold change - mRNAs\tLog Fold change - mRNAs\tAbsolute Fold change - mRNAs\tRegulation - mRNAs\tNearbyGeneChrom\tNearbyGeneStrand\tNearbyGenetxStart\tNearbyGenetxEnd\n";
    }
    else {
        print OUTPUT
"seqname\tGeneSymbol\tp-value - LncRNAs\tFold change - LncRNAs\tRegulation - LncRNAs\tsource\tRNAlength\tChrom\tStrand\ttxStart\ttxEnd\tGenomeRelationship\tNearbyGene\tNearbyGeneSymbol\tNearbyProteinName\tp-value - mRNAs\tFold change - mRNAs\tRegulation - mRNAs\tNearbyGeneChrom\tNearbyGeneStrand\tNearbyGenetxStart\tNearbyGenetxEnd\n";
    }
    while ( $line = <NEARBY> ) {
        chomp $line;
        $line =~ s/\r//g;
        @terms = split( /\t/, $line );
        my $lnc            = $terms[$seqname];
        my $lnc_chrom      = $terms[$chrom];
        my $lnc_txStart    = $terms[$txStart];
        my $coding         = $terms[$gene];
        my $coding_chrom   = $terms[$genechrom];
        my $coding_txStart = $terms[$genetxStart];

        if ( exists( $data{$lnc} ) and ( exists( $data{$coding} ) ) ) {
            if (    ( $lnc_chrom eq $chrom{$lnc} )
                and ( $lnc_txStart == $txStart{$lnc} )
                and ( $coding_chrom eq $chrom{$coding} )
                and ( $coding_txStart == $txStart{$coding} ) )
            {
                $gotlist{"$lnc\_$coding"} = 1;
                my @term = (
                    @terms[ 0, 1 ],
                    $data{$lnc},
                    @terms[ 2 .. 11 ],
                    $data{$coding},
                    @terms[ 12 .. 15 ]
                );
                $line = join( "\t", @term );
                print OUTPUT "$line\n";
            }
        }
    }
    my $count1 = keys %data;
    print
"there are $count1 unique record differentially expressed in our experiment!\n";
    my $count2 = keys %gotlist;
    print "there are $count2 unique record nearby relationship!\n";
    close NEARBY;
    close NM;
    close LNC;
    close OUTPUT;
    say "NMrelationship added to $_[1].txt";
}

sub detect_info {
  $name  = fromTSV("name.txt");
  $sn    = $name->nofRow;
  $first_ann_id = 'type';
  $gn = -f $mRNAdir.'/'.$g_prefix . "all.txt" ? 1 : 0;
  $gn = &count_uniq($name->col('Group')) if $gn;
  die "Only one group!" if ( $gn == 1 );
  # choose clustering methed
  $hc = $gn == 0 ? 1 : 2;
  # fc & pc detection
  @sDiff = glob "$mRNAdir/$s_prefix*#*.txt";
  open( SD, $sDiff[0] ) || die $!;
  while (<SD>) {
      last unless (/^#/);
      $fc = $1 if (/Fold.Change cut-off.*?([\d\.]+)/i);
      $pc = $1 if (/p-value cut-off.*?([\d\.]+)/i);
  }
  close(SD);
  # check number passed cut-off
  open( SE, $mRNAdir.'/'.$s_prefix . "all.txt" ) || die $!;
  while (<SE>) {
      last unless (/^#/);
      $valid = $1 if (/(\d+) out of \d+/);
  }
  close(SE);
  print "\tQ1. clustering was performed based on:
          1. \"All Targets Value\"\n\t2. Differentially Expressed mRNAs/LncRNAs\t[$hc]:";
  $ci = <STDIN>;
  chomp($ci);
  $hc = $ci if ( $ci eq 1 || $ci eq 2 );
}

sub do_subgroup {
  foreach $sgFile ('elncncgdt','lncgdt') {
    ### ---------- prepare : $sgFile.' ----------------'
    $book = Excel::Writer::XLSX->new($sgFile eq 'elncncgdt'
      ? 'Enhancer LncRNA nearby coding gene data table.xlsx'
      : 'LincRNA nearby coding gene data table.xlsx');
    &set_format;
    @files = glob "$tmpdir/${sgFile}_$s_prefix*#*_NMrelationship.txt";
    foreach $file (@files) {
      $file =~ m/$s_prefix(.+#.+)_NMrelationship/;
      $sc = $1;
      $sc =~ s/#/ vs /;
      $tbl = fromTSV($file);
      if ( !defined $pc ) {
        $tbl->delCol('Fold change - LncRNAs');
        $tbl->delCol('Log Fold change - lncRNAs');
        $tbl->delCol('Fold change - mRNAs');
        $tbl->delCol('Log Fold change - mRNAs');
      }
      $sheet = $book->add_worksheet( &sheet_name($sc) );
      &set_noteSG;
      $sheet->merge_range( 0,0,0,$tbl->nofCol - 1, $noteNCG, $note );
      $sheet->set_row( 0, 295 );
      @title = $tbl->header;
      $sheet->write_row( 'A3', \@title, $bold );
      $tbl->rotate if ( $tbl->type == 0 );
      $sheet->write_row( 'A4', $$tbl{'data'}, $format );
    }
    $book->close();
  }
  foreach $sgFile ('Enhancer_LncRNA_profiling','HOX_cluster_profiling','Rinn_lincRNA_profiling') {
    ### ---------- prepare : $sgFile.' ----------------'
    $tbl = fromTSV("$tmpdir/$sgFile.txt");
    $tbl->delCol('Number Passed');
    $xls = $sgFile.'.xlsx';
    $xls =~ s/_/ /g;
    $book = Excel::Writer::XLSX->new($xls);
    &set_format;
    $sheet = $book->add_worksheet($sgFile);
    $sheet->set_column(0,0,18);
    &set_noteSG;
    given ($sgFile) {
      when ('Enhancer_LncRNA_profiling') {
        $sheet->merge_range( 0,0,0,$tbl->nofCol - 1, $noteELP, $note );
      }
      when ('HOX_cluster_profiling') {
        $sheet->merge_range( 0,0,0,$tbl->nofCol - 1, $noteHOX, $note );
      }
      when ('Rinn_lincRNA_profiling') {
        $sheet->merge_range( 0,0,0,$tbl->nofCol - 1, $noteRLP, $note );
      }
    }
    $sheet->set_row( 0, 135 );
    @title = $tbl->header;
    $sheet->write_row( 'A4', \@title, $bold );
    $sheet->merge_range(2,1,2,$sn,'Raw Intensity',$RI);
    $sheet->merge_range(2,$sn+1,2,2*$sn,'Normalized Intensity',$NI);
    $sheet->merge_range(2,2*$sn+1,2,$tbl->nofCol-1,'Annotations',$ANN);
    $sheet->write_row( 'A5', $$tbl{'data'}, $format );
    $book->close();
  }
  $semaphore->up();
}

sub set_noteSG{
  if (defined $pc ) {
    $noteNCG = "# Condition pairs: $sc
# Fold Change cut-off: $fc
# P-value cut-off: $pc\n
This table contains the differentially expressed ".
($sgFile eq 'elncncgdt' ? "enhancer-like LncRNAs" : "lincRNA") .
" and their nearby coding genes (distance < 300 kb).\n
# Column A: seqname, the sequence identifier.
# Column B: GeneSymbol, the symbol of the LncRNA.
# Column C: P-value  - LncRNAs,  it is calculated by t-test.
# Column D: Fold change - LncRNAs, the ratio of normalized intensities between two groups, positive value indicates up-regulation, and negative value indicates down-regulation.
# Column E: Regulation  - LncRNAs, it depicts which group has greater or lower intensity values than other group.
# Column F ~ K: Annotations for each noncoding RNA, including source, RNAlength, Chrom, Strand, txStart, txEnd.
# Column L: GenomeRelationship, it depicts the genomic position of the protein coding genes relative to corresponding LncRNAs.
# Column M: NearbyGene, the Accession number of nearby coding gene with the LncRNA.
# Column N: NearbyGeneSymbol, the symbol of the coding gene.
# Column O: NearbyProteinName, the name of nearby protien.
# Column P: P-value - mRNAs,  it is calculated by t-test.
# Column Q: Fold change - mRNAs, the ratio of normalized intensities between two groups, positive value indicates up-regulation, and negative value indicates down-regulation.
# Column R: Regulation - mRNAs, it depicts which group has greater or lower intensity values than other group.
# Column S ~ V: Annotations for each mRNA, including NearbyGeneChrom, NearbyGeneStrand, NearbyGenetxStart, NearbyGenetxEnd.\n
Note:  Only differentially expressed pairs are listed.";
  }
  else {
    $noteNCG = "# Condition pairs: $sc
# Fold Change cut-off: $fc\n
This table contains the differentially expressed ".
($sgFile eq 'elncncgdt' ? "enhancer-like LncRNAs" : "lincRNA") .
" and their nearby coding genes (distance < 300 kb).\n
# Column A: seqname, the sequence identifier.
# Column B: GeneSymbol, the symbol of the LncRNA.
# Column C: Absolute Fold change - LncRNAs, the ratio of normalized intensities between two samples, positive value indicates up-regulation, and negative value indicates down-regulation.
# Column D: Regulation  - LncRNAs, it depicts which sample has greater or lower intensity values than other sample.
# Column E ~ J: Annotations for each noncoding RNA, including source, RNAlength, Chrom, Strand, txStart, txEnd.
# Column K: GenomeRelationship, it depicts the genomic position of the protein coding genes relative to corresponding LncRNAs.
# Column L: NearbyGene, the Accession number of nearby coding gene with the LncRNA.
# Column M: NearbyGeneSymbol, the symbol of the coding gene.
# Column N: NearbyProteinName, the name of nearby protien.
# Column O: Absolute Fold change - mRNAs, the ratio of normalized intensities between two samples, positive value indicates up-regulation, and negative value indicates down-regulation.
# Column P: Regulation - mRNAs, it depicts which sample has greater or lower intensity values than other sample.
# Column Q ~ T: Annotations for each mRNA, including NearbyGeneChrom, NearbyGeneStrand, NearbyGenetxStart, NearbyGenetxEnd.\n
Note:  Only differentially expressed pairs are listed.";
  }

  $noteRLP = "Rinn lincRNAs profiling (Entities where at least $valid out of $sn samples have flags in Present or Marginal).\n
This table contains profiling data of all probes for lincRNAs based on John Rinn's papers (Guttman, M., et al. 2009, Khalil, A.M., et al. 2009).\n
# Column A: ProbeName, it represents the probe name.
# Column B ~ ".char(1+$sn).": Raw Intensity of each sample.
# Column ".char(2+$sn)." ~ ".char(1+2*$sn).": Normalized Intensity of each sample (log2 transformed).
# Column ".char(2+2*$sn)." ~ ".char($tbl->nofCol).": Annotations to each probe, including type, seqname, GeneSymbol, source, RNAlength, chrom, strand, txStart, txEnd, Xhyb, probeSeq.";

  $noteHOX = "HOX cluster profiling (Entities where at least $valid out of $sn samples have flags in Present or Marginal).\n
This table contains profiling data of all probes in the four HOX loci, targeting 407 discrete transcribed regions (Rinn, Kertesz et al. 2007), LncRNAs and coding transcripts.\n
# Column A: ProbeName, it represents the probe name.
# Column B ~ ".char(1+$sn).": Raw Intensity of each sample.
# Column ".char(2+$sn)." ~ ".char(1+2*$sn).": Normalized Intensity of each sample (log2 transformed).
# Column ".char(2+2*$sn)." ~ ".char($tbl->nofCol).": Annotations to each probe, including type, seqname, GeneSymbol, source, RNAlength, chrom, strand, txStart, txEnd, Xhyb, probeSeq, EntrezID, unigene, GO(Avadis), ProteinAccession, product.";

  $noteELP = "Enhancer LncRNAs profiling (Entities where at least $valid out of $sn samples have flags in Present or Marginal).\n
This table contains profiling data of all probes for LncRNAs with enhancer-like function (Harrow, Denoeud et al. 2006).\n
# Column A: ProbeName, it represents the probe name.
# Column B ~ ".char(1+$sn).": Raw Intensity of each sample.
# Column ".char(2+$sn)." ~ ".char(1+2*$sn).": Normalized Intensity of each sample (log2 transformed).
# Column ".char(2+2*$sn)." ~ ".char($tbl->nofCol).": Annotations to each probe, including type, seqname, GeneSymbol, source, RNAlength, chrom, strand, txStart, txEnd, Xhyb, probeSeq.";
}

sub do_diff {
    $wd = shift;
    ### ---------- preparing : $wd.' diff.xlsx ------------------'
    $book = Excel::Writer::XLSX->new(
        $gn == 0
            ? "Differentially Expressed ${wd}s.xlsx"
            : "Differentially Expressed ${wd}s (Pass Volcano Plot).xlsx"
    );

    mkdir "go";
    mkdir "path";
    if ( $wd eq 'mRNA' ) {
        @sDiff = glob "$wd/$s_prefix*#*.txt";
        @gDiff = glob "$wd/$g_prefix*#*.txt" if $gn;
    }
    else {
        @sDiff = glob "$tmpdir/$s_prefix*#*.txt";
        @gDiff = glob "$tmpdir/$g_prefix*#*.txt" if $gn;
    }
    &set_format;
    for ( $i = 0 ; $i < @sDiff ; $i++ ) {
        undef $fc;
        undef $pc;
        # fc & pc detection
        open( SD, $sDiff[$i] ) || die $!;
        while (<SD>) {
            last unless (/^#/);
            $fc = $1 if (/Fold.Change cut-off.*?([\d\.]+)/i);
            $pc = $1 if (/p-value cut-off.*?([\d\.]+)/i);
        }
        close(SD);
        $gnColID = 'GeneSymbol';

        $sDiff[$i] =~ /$s_prefix(\S+#\S+)\.txt/;
        $sc = $1;
        if ( $gn != 0 ) {
            $gDiff[$i] =~ /$g_prefix(\S+#\S+)\.txt/;
            $gc = $1;
            unless ( $sc eq $gc ) {
                say "File missed for $gc $sc.";
            }
        }
        $sc =~ s/#/ vs /;
        $sc =~ s/_NMrelationship//;
        $sExp = fromTSV( $sDiff[$i] );
        $gExp = fromTSV( $gDiff[$i] ) if $gn;
        # sample number for each pair
        $snp = 0;
        @title = $sExp->header;
        map {if(/raw/){$snp++;}} @title;

        # up & down
        foreach $reg ('up','down') {
          if ( $gn != 0 ) {
              $gExp_ann_idx = $gExp->colIndex($first_ann_id);
              $sExp_ann_idx = $sExp->colIndex($first_ann_id);
              $exp = subTables( [ $gExp, [ 0 .. ( $gExp_ann_idx - 1 ) ],
                    $sExp, [ ($sExp_ann_idx - $snp*2) .. ($sExp->nofCol - 1) ] ] );
              @exp_header = $exp->header;
              if ( $exp_header[1] =~ /^Fold change/ ) {
                $exp->delCol($exp_header[1]);
                splice(@exp_header,1,1);
              }
              $k = 0;
              map {$reg_idx = $k if (/regulation/i);$k++} @exp_header;
              $regTbl = $exp->match_pattern('$_->['.$reg_idx.'] eq "'.$reg.'"');
          }
          else {
              $exp = subTables( [$sExp, [ 0, 3 .. ($sExp->nofCol - 1) ]] );
              $regTbl = $exp->match_pattern('$_->[2] eq "'.$reg.'"');
          }
          &set_note2;
          $sheet = $book->add_worksheet( &sheet_name($sc, '_'.$reg) );
          $sheet->set_tab_color($reg eq 'up' ? 45 : 42);
          $sheet->merge_range( 0,0,0,$regTbl->nofCol - 1, $noteUD, $note );
          $sheet->set_row( 0, $wd eq 'mRNA' ? 130 : 375 );
          @title = $regTbl->header;
          $sheet->merge_range( 2, 0, 2, $regTbl->nofCol - 1,
              "$sc $fc fold $reg regulated genes", $reg eq 'up' ? $UP : $DOWN );
          &title_format;
          $sheet->write_row( 'A5', \@title, $bold );
          $sheet->write_col( 'A6', $$regTbl{'data'}, $format );
          if ( $wd eq 'mRNA' ) {
            $s_c = $sc;
            $s_c =~ s/ /_/g;
            open( GO, ">go/$s_c-$reg.txt" )   || die $!;
            open( PA, ">path/$s_c-$reg.txt" ) || die $!;

            foreach $gene (grep { !/^$|^N\/A$/ } $regTbl->col($gnColID)) {
                say GO $gene;
                say PA "$gene\t",$reg eq 'up' ? "orange" : "yellow";
            }
            close GO;
            close PA;
          }
        }
        next;
    }
    if ( $gn != 0 ) {
        $sheet = $book->add_worksheet("Volcano Plots");
        $sheet->merge_range( "A1:M1", $noteVP, $note );
        $sheet->set_row( 0, 160 );
    }
    $book->close();
    ### done : $wd . 'diff.xlsx saved'
    $semaphore->up();
}

sub do_profile {
    $wd = shift;
    ### ---------- preparing : $wd .' profiling.xlsx-----------------'
    $book = Excel::Writer::XLSX->new($wd.' Expression Profiling Data.xlsx');

    if ( $wd eq 'mRNA' ) {
        $sExp = fromTSV( $wd.'/'.$s_prefix."all.txt" );
        $gExp = fromTSV( $wd.'/'.$g_prefix."all.txt" ) if $gn;
    }
    else {
        $sExp = fromTSV($tmpdir.'/'.$s_prefix."all_NMrelationship.txt");
        $gExp = fromTSV($tmpdir.'/'.$g_prefix."all_NMrelationship.txt") if $gn;
    }

    &set_format;
    if ( $gn != 0 ) {
        $exp = subTables(
            [
                $gExp, [ 0, 2 .. ( $gn * 2 + 1 ) ],
                $sExp, [ 2 .. ( $sExp->nofCol - 1 ) ]
            ]
        );
    }
    else {
        $exp = subTables( [ $sExp, [ 0, 2 .. ( $sExp->nofCol - 1 ) ] ] );
    }
    @title = $exp->header;
    &set_note1;
    $sheet = $book->add_worksheet("All Targets Value-$wd");
    $sheet->set_column(0,0,18);
    $sheet->merge_range( "A1:M1", $noteATV, $note );
    $sheet->set_row( 0, $wd eq 'mRNA' ? 120 : 390 );
    $sheet->merge_range( 2, 1, 2, $gn, "Group-Raw Intensity", $GRI )
      if ( $gn > 1 );
    $sheet->merge_range(
        2, $gn + 1,
        2, 2 * $gn,
        "Group-Normalized Intensity", $GNI
    ) if $gn;
    $sheet->merge_range(
        2, 2 * $gn + 1,
        2, 2 * $gn + $sn,
        "Raw Intensity", $RI
    ) if ( $sn > 1 );
    $sheet->merge_range(
        2, 2 * $gn + $sn + 1,
        2, 2 * $gn + $sn * 2,
        "Normalized Intensity", $NI
    );
    $sheet->merge_range(
        2, 2 * $gn + $sn * 2 + 1,
        2, $exp->nofCol - 1,
        "Annotations", $ANN
    );
    $sheet->write_row( 'A4', \@title, $bold );
    $sheet->write_col( 'A5', $$exp{'data'}, $format );
    $sheet->set_column( 0, $exp->nofCol - 1, 10 );
    $sheet = $book->add_worksheet("Box Plot-$wd");
    $sheet->merge_range( "A1:M1", $noteBP, $note );
    $sheet->set_row( 0, 120 );
    $sheet = $book->add_worksheet("Scatter Plot-$wd");
    $sheet->merge_range( "A1:M1", $noteSP, $note );
    $sheet->set_row( 0, 80 );
    $sheet = $book->add_worksheet("Hierarchical Clustering-$wd");
    $sheet->merge_range( "A1:M1", $noteHC, $note );
    $sheet->set_row( 0, 140 );
    $book->close();
    ### got : $wd.'profiling.xlsx saved'
    $semaphore->up();
}

sub do_images {
    ### ---------- extracting images ----------------------------------
    my @file_bmp           = glob "../*.bmp";   #get the name list of files;
    my $total_image_number = 0;
    my ( $image_w, $image_h, $txt );
    foreach $bmp_name (@file_bmp) {
        foreach $i ( keys %image_name ) {
            $txt = $image_name{$i}[0];
            next if (-f "$image_name{$i}[1].jpg");
            my @content = split( /_/, $txt );
            my $txt_image =
              $content[0] . "_" . $content[1] . "_" . $content[2] . ".bmp";
            my $image_extract_name = $txt;
            if ( $txt_image eq $bmp_name ) {
                $total_image_number++;
                open( TXT, "$txt" ) || die "can't open iamge";
                my ( $image_x, $image_y );
                my @line = <TXT>;
                my @data = split( /\t/, $line[10] );
                $image_x = $data[8] / 2 - 15;
                $image_y = $data[9] / 2 - 16;
                if ( $total_image_number == 1 ) {
                    my @data2 = split( /\t/, $line[$#line] );
                    $image_w = $data2[8] / 2 + 15 - $image_x;
                    $image_h = $data2[9] / 2 + 16 - $image_y;
                }
                system(
"convert $bmp_name -crop ${image_w}x${image_h}+$image_x+$image_y -quality 100 $image_name{$i}[1].jpg"
                );
                ### image: $image_name{$i}[1].'.jpg generated'
            }
        }
    }
    ### images generated
    $semaphore->up();
}

sub do_raw {
    ### ---------- preparing 'Raw Intensity.xlsx' ---------------------
    foreach $i ( sort {$image_name{$a}[1] cmp $image_name{$b}[1]} keys %image_name ) {
        $rawfile = $image_name{$i}[0];
        $samplename = $image_name{$i}[1];
        ### loading : "$rawfile => $samplename"
        unless ( defined $raw ) {
            $raw = Data::Table::fromTSV( $rawfile, 1, undef,
                { OS => 1, skip_lines => 9 } );
            $raw = $raw->subTable( undef,['Row', 'Col', 'ProbeName', 'SystematicName', 'gProcessedSignal' ]);
            $raw->header(['Row','Col','ProbeName', 'SystematicName',$sample_name{$rawfile}]);
        }
        else {
            $tmp = Data::Table::fromTSV( $rawfile, 1, undef,
                { OS => 1, skip_lines => 9 } );
            $raw->addCol( $tmp->colRef('gProcessedSignal'),
                $sample_name{$rawfile} );
        }
    }
    $book = Excel::Writer::XLSX->new('Raw Intensity.xlsx');
    &set_format;
    $sheet = $book->add_worksheet("Raw Intensity");
    &set_note0;
    $sheet->merge_range( 0, 0, 0, $raw->nofCol - 1, $noteRI, $note );
    $sheet->set_row( 0, 100 );
    $sheet->set_column( 0, 1, 5 );
    $sheet->set_column( 2, 3, 18 );
    $sheet->set_column( 4, $raw->nofCol - 1, 10 );
    @rtitle = map { s/prefix_//;$_ } $raw->header;
    $sheet->write_row( 'A3', \@rtitle, $bold );
    $raw->rotate if ( $raw->type == 0 );
    $sheet->write_row( 'A4', $$raw{'data'}, $format );
    $book->close();
    ### Raw Intensity.xlsx saved
    $semaphore->up();
}

sub sheet_name {
  my $name = shift;
  my $suffix = shift || '';
  if (length($name) + length($suffix) > 31) {
    $name = substr($name,0,31-length($suffix));
  }
  return $name.$suffix;
}
sub title_format {
    if ( $gn == 0 ) {
        $sheet->merge_range( 3, 1, 3, 2, 'Fold change and Regulation', $ANN );
        $sheet->merge_range( 3, 3, 3, 4, 'Raw Intensity', $GRI );
        $sheet->merge_range( 3, 5, 3, 6, 'Normalized Intensity', $RI );
        $sheet->merge_range( 3, 7, 3, $regTbl->nofCol - 1, 'Annotation', $ANN );
    }
    else {
        $sheet->merge_range( 3, 1, 3, 3, 'P-value Fold change and Regulation',
            $ANN );
        $sheet->merge_range( 3, 4, 3, 5, 'Group-Raw Intensity', $GRI );
        $sheet->merge_range(3,6,3,7, 'Group-Normalized Intensity', $RI );
        $sheet->merge_range(3,8,3,$snp + 7,'Raw Intensity', $GRI);
        $sheet->merge_range(3,$snp+8,3,$snp*2 + 7,'Normalized Intensity', $GNI );
        $sheet->merge_range(3,$snp * 2 + 8,3, $regTbl->nofCol - 1,'Annotation', $ANN );
    }
    $sheet->set_column( 1, $regTbl->nofCol - 1, 10 );
    $sheet->set_column(0,0,18);
}

sub set_format {
    $format = $book->add_format();
    $format->set_font('Arial');
    $format->set_align("left");
    $format->set_size(10);

    $number = $book->add_format();
    $number->set_num_format();

    $bold = $book->add_format();
    $bold->set_font('Arial');
    $bold->set_align("left");
    $bold->set_size(10);
    $bold->set_bold();

    $note = $book->add_format();
    $note->set_font('Verdana');
    $note->set_size(10);
    $note->set_bg_color(43);
    $note->set_text_wrap();
    $note->set_align("top");

    $GRI = $book->add_format();
    $GRI->set_font('Arial');
    $GRI->set_bold();
    $GRI->set_align('center');
    $GRI->set_size(10);
    $GRI->set_bg_color(44);

    $GNI = $book->add_format();
    $GNI->set_font('Arial');
    $GNI->set_bold();
    $GNI->set_align('center');
    $GNI->set_size(10);
    $GNI->set_bg_color(45);

    $RI = $book->add_format();
    $RI->set_font('Arial');
    $RI->set_bold();
    $RI->set_align('center');
    $RI->set_size(10);
    $RI->set_bg_color(42);

    $NI = $book->add_format();
    $NI->set_font('Arial');
    $NI->set_bold();
    $NI->set_align('center');
    $NI->set_size(10);
    $NI->set_bg_color(50);

    $ANN = $book->add_format();
    $ANN->set_font('Arial');
    $ANN->set_bold();
    $ANN->set_align('center');
    $ANN->set_size(10);
    $ANN->set_bg_color(47);

    $book->set_custom_color( 57, 0, 176, 80 );
    $DOWN = $book->add_format();
    $DOWN->set_font('Arial');
    $DOWN->set_bold();
    $DOWN->set_align('center');
    $DOWN->set_size(10);
    $DOWN->set_bg_color(57);

    $UP = $book->add_format();
    $UP->set_font('Arial');
    $UP->set_bold();
    $UP->set_align('center');
    $UP->set_size(10);
    $UP->set_bg_color(10);
}

sub fromTSV {
    my $file = $_[0] || die "File not declared!";
    ### read: $file
    my $t =
      Data::Table::fromTSV( $file, 1, undef,
        { OS => 0, skip_pattern => '^\s*#' } );
    $t->rotate if ( $t->type == 1 );
    return $t;
}

sub outputTSV {
    my ( $table, $file, $header ) = @_;
    say "outputTSV() parameter ERROR!" unless defined $table;
    $header = defined $header ? $header : 1;
    if ( defined $file ) {
        $table->tsv( $header, { OS => 0, file => $file } );
    }
    else {
        print $table->tsv( $header, { OS => 0, file => undef } );
    }
    return $table->tsv( $header, { OS => 0, file => undef } );
}

sub headerCol {
    my ( $table, $idx ) = @_;
    return ( $table->header )[ @{$idx} ];
}

sub subTables {    # [$table, [@colIdxs]]
    my $para = $_[0];
    my ( $table, $i );
    for ( $i = 0 ; $i < $#$para ; $i += 2 ) {
        unless ( defined $table ) {
            $table =
              $$para[$i]->subTable( undef,
                [ headerCol( $$para[$i], $$para[ $i + 1 ] ) ] );
        }
        else {
            $table->colMerge(
                $$para[$i]->subTable(
                    undef, [ headerCol( $$para[$i], $$para[ $i + 1 ] ) ]
                )
            );
        }
    }
    $table->rotate if ( $table->type == 1 );
    return $table;
}

sub char {
    my $no = $_[0];
    $ch = chr( ( $no - 1 ) % 26 + 65 );
    if ( $no / 26 > 1 ) {
        $ch = chr( int( ( $no - 1 ) / 26 ) + 64 ) . $ch;
    }
    return $ch;
}

sub waitquit {
    my $num = 0;
    while ( $num < $cpus ) {
        $semaphore->down();
        $num++;
    }
    $semaphore->up($cpus);
}

sub set_note0 {
    $noteRI = '# Column A: Row, the row number of the feature.
# Column B: Column, the column number of the feature.
# Column C: ProbeName, the name of each probe.
# Column D: SystematicName, the Genbank accession number.
# Column E~'
      . char( 4 + $sn )
      . ': Signal, the signal left after all the Feature Extracted Software processing steps have been completed (used for GeneSpring data normalization and further analysis).';
}

sub set_note1 {
    my $ann_ids = join(', ',@title[($gn + $sn)*2 + 1 .. ($exp->nofCol - 1) ]);
    $noteATV =
"All Targets Value (Entities where at least $valid out of $sn samples have flags in Present or Marginal)\n
# Column A: ProbeName, it represents the probe name.\n" . (
    $gn == 0
    ? ""
    : "# Column B~" . char( 1 + $gn )
        . ": Raw Intensity of each group (averaged intensity of replicate samples).
# Column "
      . char( 2 + $gn ) . "~" . char( 2 * $gn + 1 )
        . ": log2 value of normalized intensity of each group (averaged intensity of replicate samples).\n"
) .
"# Column " . char( 2 * $gn + 2 ) . "~" . char( 2 * $gn + $sn + 1 )
      . ": Raw Intensity of each sample.
# Column "
      . char( 2 * $gn + $sn + 2 ) . "~"
      . char( 2 * $gn + 2 * $sn + 1 )
      . ": log2 value of normalized intensity of each sample.
# Column "
      . char( 2 * $gn + 2 * $sn + 2 ) . "~"
      . char( $exp->nofCol )
      . ": Annotations to each probe, including $ann_ids.\n";
    if ($wd eq 'LncRNA') {
      $noteATV .= '
Note:
# Column '.char( 2 * ($gn + $sn) + 5 ).': source, the source of LncRNA is collected from.
RefSeq_NR: RefSeq validated non-coding RNA;
UCSC_knowngene: UCSC known genes annotated as "non-coding", "near-coding" and "antisense" (http://genome.ucsc.edu/cgi-bin/hgTables/);
Ensembl: Ensembl (http://www.ensembl.org/index.html);
H-invDB: H-invDB (http://www.h-invitational.jp/);
RNAdb: RNAdb2.0 (http://research.imb.uq.edu.au/rnadb/);
NRED: NRED (http://jsm-research.imb.uq.edu.au/nred/cgi-bin/ncrnadb.pl);
UCR: "ultra-conserved region" among human, mouse and rat (http://users.soe.ucsc.edu/~jill/ultra.html);
lincRNA: lincRNA identified by John Rinn\'s group (Guttman et al. 2009; Khalil et al. 2009);
misc_lncRNA: other sources.

# Columns '.char( $exp->nofCol - 6 ).' ~ '.char( $exp->nofCol ).': the relationship of LncRNA and its nearby coding gene and the coordinate of the coding gene, including relationship, Associated_gene_acc, Associated_gene_name, Associated_protein_name, Associated_gene_strand, Associated_gene_start, Associated_gene_end.
"sense_overlapping": the LncRNA\'s exon is overlapping a coding transcript exon on the same genomic strand;
"intronic": the LncRNA is overlapping the intron of a coding transcript on the same genomic strand;
"natural antisense": the LncRNA is transcribed from the antisense strand and overlapping with a coding transcript; 
"non-overlapping antisense": the LncRNA is transcribed from the antisense strand without sharing overlapping exons;
"bidirectional": the LncRNA is oriented head to head to a coding transcript within 1000 bp;
"intergenic": there are no overlapping or bidirectional coding transcripts nearby the LncRNA.';
    }
    $noteBP = "Box Plot\n
     The boxplot is a traditional method for visualizing the distribution of a dataset. They are most useful for comparing the distributions of several datasets.
      Here, a boxplot view is used to look at,  and compare, the distributions of expression values for the samples or conditions in an experiment after normalization.\n
     Press Ctrl and rolling button of your mouse to zoom in.";
    $noteSP = "Scatter Plot\n
      The scatterplot is a visualization that is useful for assessing the variation (or reproducibility) between chips.\n
      Press Ctrl and rolling button of your mouse to zoom in.";

    $hc = $hc == 1 ? '"All Targets Value"' : "Differentially Expressed ${wd}s";
    $noteHC = "Heat Map and Unsupervised Hierarchical Clustering\n
     Hierarchical clustering is one of the simplest and widely used clustering techniques for analysis of gene expression data. Cluster analysis arranges samples into groups based on their expression levels, which allows us to hypothesize about the relationships among samples. The dendrogram shows the relationships among the expression levels of samples.\n
      Here, hierarchical clustering was performed based on \"$hc\". Your experiment consists of $sn different samples. The result of hierarchical clustering on conditions shows distinguishable gene expression profiling among samples.\n
       Press Ctrl and rolling button of your mouse to zoom in.";
}

sub set_note2 {
    my @title = $sExp->header;

    # note in diff table in grouped condition
    if ( !defined $pc ) {
        $ann_ids = join(', ',@title[ 9 .. ($sExp->nofCol - 1)]);
        $endcol = char( $regTbl->nofCol );
        $noteUD = "# Condition pairs: $sc
# Fold Change cut-off: $fc\n
# Column A: ProbeName, it represents probe name.
# Column B: Absolute Fold change, the absolute ratio (no log scale) of normalized intensities between two samples.
# Column C: Regulation, it depicts which one of the samples has greater or lower intensity values wrt other sample.
# Column D,E: Raw Intensity of each sample.
# Column F,G: log2 value of normalized intensity of each sample.
# Column H~$endcol: Annotations to each probe, including $ann_ids.";
    }
    else {
        $ann_ids = join(', ',@title[($snp*2 + 4 ) .. ($sExp->nofCol - 1)]);
        $noteUD = "# Condition pairs: $sc
# Fold Change cut-off: $fc
# P-value cut-off: $pc\n
# Column A: ProbeName, it represents probe name.
# Column B: p-value, p-value calculated from T-Test.
# Column C: FCAbsolute, the absolute ratio (no log scale) of normalized intensities between two groups.
# Column D: Regulation, it depicts which one of the groups has greater or lower intensity values wrt other group.
# Column E,F: Raw Intensity of each group (averaged intensity of replicate samples).
# Column G,H: log2 value of normalized intensity of each group (averaged intensity of replicate samples).
# Column I~" . char( 8 + $snp ) . ": Raw Intensity of each sample.
# Column " . char( 9 + $snp ) . "~" . char( 8 + 2*$snp )
          . ": log2 value of normalized intensity of each sample.
# Column " . char( 9 + 2 * $snp ) . "~" . char( $regTbl->nofCol )
          . ": Annotations to each probe, including $ann_ids.";

    $noteVP = "Volcano plots\n
      Volcano plots are a useful tool for visualizing differential expression between two different conditions. They are constructed using fold-change values and p-values, and thus allow you to visualize the relationship between fold-change (magnitude of change) and statistical significance (which takes both magnitude of change and variability into consideration).They also allow subsets of genes to be isolated, based on those values.\n
      The vertical lines correspond to $fc-fold up and down, respectively, and the horizontal line represents a p-value of $pc. So the red point in the plot represents the differentially expressed ${wd}s with statistical significance.\n
     Press Ctrl and rolling button of your mouse to zoom in.";
    }

    if ($wd eq 'LncRNA') {
      $noteUD .= '
Note:
# Column '.char(12+2*$snp).': source, the source of LncRNA is collected from.
RefSeq_NR: RefSeq validated non-coding RNA;
UCSC_knowngene: UCSC known genes annotated as "non-coding", "near-coding" and "antisense" (http://genome.ucsc.edu/cgi-bin/hgTables/);
Ensembl: Ensembl (http://www.ensembl.org/index.html);
H-invDB: H-invDB (http://www.h-invitational.jp/);
RNAdb: RNAdb2.0 (http://research.imb.uq.edu.au/rnadb/);
NRED: NRED (http://jsm-research.imb.uq.edu.au/nred/cgi-bin/ncrnadb.pl);
UCR: "ultra-conserved region" among human, mouse and rat (http://users.soe.ucsc.edu/~jill/ultra.html);
lincRNA: lincRNA identified by John Rinn\'s group (Guttman et al. 2009; Khalil et al. 2009);
misc_lncRNA: other sources.

# Columns '.char( $regTbl->nofCol - 6 ).' ~ '.char( $regTbl->nofCol ).': the relationship of LncRNA and its nearby coding gene and the coordinate of the coding gene, including relationship, Associated_gene_acc, Associated_gene_name, Associated_protein_name, Associated_gene_strand, Associated_gene_start, Associated_gene_end.
"sense_overlapping": the LncRNA\'s exon is overlapping a coding transcript exon on the same genomic strand;
"intronic": the LncRNA is overlapping the intron of a coding transcript on the same genomic strand;
"natural antisense": the LncRNA is transcribed from the antisense strand and overlapping with a coding transcript; 
"non-overlapping antisense": the LncRNA is transcribed from the antisense strand without sharing overlapping exons;
"bidirectional": the LncRNA is oriented head to head to a coding transcript within 1000 bp;
"intergenic": there are no overlapping or bidirectional coding transcripts nearby the LncRNA.';
    }
}

sub count_uniq {
  my (%cnt,$elm);
  while( $elm = shift ) {
    $cnt{$elm} = 1;
  }
  return scalar keys %cnt;
}
