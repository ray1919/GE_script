#!/usr/bin/env perl

use File::Copy;
use 5.010;
#输入名称
my $mRNAdir = 'mRNA';
my $lncRNAdir = 'LncRNA';
my $tmpdir = 'temp';
my $samplePrefix = 'sample';
my $groupPrefix = 'group';
mkdir($tmpdir);
print "Organism: 1.hs 2.mm 3.rn [1]:";
my $orgn = <STDIN>;
given($orgn) {
  when(/1/) {$orgn = 'hs'}
  when(/2/) {$orgn = 'mm'}
  when(/3/) {$orgn = 'rn'}
  default   {$orgn = 'hs'}
}
given($orgn) {
  when('hs') {
    $assoFile = '/public/WinXPShare/panzhong/10Arraystar_microarray_annotation_files_042011/human_lncRNA_microarray_v2_DesignID033010/add_NMrelationship_human_v2.0/microarray_033010_lncRNA_NM_association_110518_baken.txt';
    $scdir = '/public/WinXPShare/panzhong/10Arraystar_microarray_annotation_files_042011/human_lncRNA_microarray_v2_DesignID033010/subgroup_Analysis_huamn_v2.0/';
    $lincRNA = $scdir.
    'microarray_033010_human_lncRNA_V2_annotation_20110517_lincRNA.txt';
    $enhancer_lncRNA = $scdir.
    'microarray_033010_human_lncRNA_V2_annotation_20110517_enhancer_lncRNA.txt';
    $hox_cluster = $scdir.
    'microarray_033010_human_lncRNA_V2_annotation_20110517_Hox_cluster.txt';
    $lincRNA_nearby_NM = $scdir.
    'microarray_033010_human_lncRNA_V2_annotation_20110517_lincRNA_extend_overlap_NM_baken.txt';
    $enhancer_nearby_NM = $scdir.
    'microarray_033010_human_lncRNA_V2_annotation_20110517_enhancer_lncRNA_extend_overlap_NM_baken.txt';
  }
  when('mm') {
    $assoFile = '/public/WinXPShare/panzhong/10Arraystar_microarray_annotation_files_042011/mouse_lncRNA_microarary_v2_DesignID034068/add_NMrelationship/MM9_lncRNA_microarray_v2_transcripts_poss_inf_110610_NMrelationship_baken';
    $scdir = '/public/WinXPShare/panzhong/10Arraystar_microarray_annotation_files_042011/mouse_lncRNA_microarary_v2_DesignID034068/subgroup/';
    $lincRNA = $scdir.'MM9_lncRNA_microarray_V2_annotation_110613_lincRNA';
    $lincRNA_nearby_NM = $scdir.'MM9_lncRNA_microarray_V2_annotation_110613_lincRNA_extend_overlap_NM_baken';
  }
  when('rn') {
    $assoFile = '/public/WinXPShare/panzhong/10Arraystar_microarray_annotation_files_042011/rat_lncRNA_microarray_DesignID026403/add_NMrelationship/array_026403_rat_lncRNA_NM_association_120503_baken.txt';
  }
}
#主函数 relation
my %relation = ();
&read_total($assoFile);    #read in the annotation file
my @files = glob "$lncRNAdir/*.txt";
foreach $filename (@files) {
    $outputFile = $filename;
    $outputFile =~ s/$lncRNAdir/$tmpdir/;
    $outputFile =~ s/\.txt$/_NMrelationship.txt/;
    &add_NMrelationship($filename,$outputFile);
}
say 'successful add NMrelationship to all data files!';
say '<press ENTER to continue>';
<STDIN>;

#主函数 subgroup
my $lncRNA_all = $lncRNAdir.'/'.$samplePrefix.'all.txt';
my $NM_all     = $mRNAdir.'/'.$samplePrefix.'all.txt';
my $rlpFile    = $tmpdir.'/Rinn_lincRNA_profiling.txt';
my $elpFile    = $tmpdir.'/Enhancer_LncRNA_profiling.txt';
my $hcpFile    = $tmpdir.'/HOX_cluster_profiling.txt';
&get_sub_list( $lincRNA, $lncRNA_all, $rlpFile ) if (defined $lincRNA);
&get_sub_list( $enhancer_lncRNA, $lncRNA_all, $elpFile ) if (defined $enhancer_lncRNA);
&get_hox_cluster_list( $hox_cluster, $NM_all, $lncRNA_all, $hcpFile ) if (defined $hox_cluster);
@files = glob $tmpdir.'/'.$samplePrefix.'*#*_NMrelationship.txt';
my ($lncRNA_de, $elnFile, $lncFile, $NM_de);
foreach $filename (@files) {
    $lncRNA_de = $filename;
    $elnFile    = $filename;
    $elnFile    =~ s#$tmpdir/#$tmpdir/elncncgdt_#;
    $lncFile    = $filename;
    $lncFile    =~ s#$tmpdir/#$tmpdir/lncgdt_#;
    # my $NM_de = substr( $filename, 0, length($filename) - 19 ) . '.txt';
    $NM_de      = $filename;
    $NM_de      =~ s/_NMrelationship//;
    $NM_de      =~ s/$tmpdir/$mRNAdir/;
    &get_lncRNA_NM_datapair( $lncRNA_de, $NM_de, $lincRNA_nearby_NM,
        $lncFile ) if (defined $lincRNA_nearby_NM);
    &get_lncRNA_NM_datapair( $lncRNA_de, $NM_de, $enhancer_nearby_NM,
        $elnFile ) if (defined $enhancer_nearby_NM);
    print "successful add NMrelationship to all data files!\n";
}
#unlink('elncncgdt_all_NMrelationship.txt')
#  or die "Could not delete the file!\n";
#unlink('lncgdt_all_NMrelationship.txt') or die "Could not delete the file!\n";
say '<press ENTER to continue>';
<STDIN>;
exit;

# read in all the annotation file
sub read_total {
    open( LIST, $_[0] ) or die "error(input2):$!";
    my $tag = 0;
    my $sg  = 0;
    while ( $line = <LIST> ) {
        chomp $line;
        $line =~ s/\r$//;
        my @name = split( /\t/, $line );
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
    say "there are $tag unique record in the list file!";
}

sub add_NMrelationship {
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
                if ( $terms[$i] eq 'seqname' || $terms[$i] eq 'SeqID' ) {
                    $seqname = $i;
                }
                if ( $terms[$i] eq 'chrom' || $terms[$i] eq 'chromosome' ) {
                    $chrom_i = $i;
                }
                if ( $terms[$i] eq 'txStart' ) {
                    $txStart_i = $i;
                }
            }
            last;
        }
    }
    ########################################
    while ( $line = <TOTAL> ) {
        if ( $line !~ /^\#/ ) {
            chomp $line;
            my @terms = split( /\t/, $line );
            $name = $terms[$seqname];
            my $chrom   = $terms[$chrom_i];
            my $txStart = $terms[$txStart_i];
            if ( $relation{ ${name} . ${chrom} . ${txStart} }[0] ne "" ) {
                my $i = 0;
                while ( $relation{ ${name} . ${chrom} . ${txStart} }[$i] ne "" ) {
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
    say "successful add NMrelationship for $_[0].";
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
        elsif ( $terms[$i] eq 'NearbyProteinName' ) {
            $protein = $i;
        }
        elsif ( $terms[$i] eq 'NearbyGeneChrom' ) {
            $genechrom = $i;
        }
        elsif ( $terms[$i] eq 'NearbyGenetxStart' ) {
            $genetxStart = $i;
        }
    }
    if ( $type eq "sample" ) {
        print OUTPUT
"seqname\tGeneSymbol\tFold change - LncRNAs\tLog Fold change - lncRNAs\tAbsolute Fold change - LncRNAs\tRegulation - LncRNAs\tsource\tRNAlength\tChrom\tStrand\ttxStart\ttxEnd\tGenomeRelationship\tNearbyGene\tNearbyGeneSymbol\tNearbyProteinName\tFold change - mRNAs\tLog Fold change - mRNAs\tAbsolute Fold change - mRNAs\tRegulation - mRNAs\tNearbyGeneChrom\tNearbyGeneStrand\tNearbyGenetxStart\tNearbyGenetxEnd\n";
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
    print "successful add NMrelationship for $_[1].txt!\n";
}
