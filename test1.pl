#!/usr/bin/env perl
# Author: Zhao
# Date: 2011.11.11
# Purpose: format txt file outputed from Genespring
# Update: 2011.11.18
use Data::Table;
use Smart::Comments;
use Excel::Writer::XLSX;
use threads;
use Thread::Semaphore;
use warnings;
$semaphore = new Thread::Semaphore(2);
$s_prefix = "sample";
$g_prefix = "group";

open(SE,$s_prefix."Expression.txt") || die $!;
while (<SE>){
  last unless(/^#/);
  $valid = $1 if (/(\d+) out of \d+/);
  $lc = $1 if (/Lower cut-off: (\d+).0/);
  $plat = 1 if (/Technology.*NimbleGen/i);
  $plat = 2 if (/Technology.*Agilent/i);
}
close(SE);
$name = fromTSV("name.txt");
$sn = $name->nofRow;
$sExp = fromTSV($s_prefix."Expression.txt");
@sDiff = glob "$s_prefix*-*.txt";
open(SD,$sDiff[0]) || die $!;
while (<SD>){
  last unless(/^#/);
  $fc = $1 if (/Fold.Change cut-off.*?([\d\.]+)/i);
  $pc = $1 if (/p-value cut-off.*?([\d\.]+)/i);
}
close(SD);
mkdir "go";
mkdir "path";
$gn = -e $g_prefix."Expression.txt" ? 1 : 0;
# 汇总处理
$gExp = fromTSV($g_prefix."Expression.txt") if $gn;
@gDiff = glob "$g_prefix*-*.txt" if $gn;
@group = keys %{{$name->col('Group'),reverse $name->col('Group')}} if $gn;
$gn = scalar @group if $gn;
die "Only one group!" if ($gn == 1);
&set_note1;
$semaphore->down();
$thread = async{
  $book = Excel::Writer::XLSX->new('gene.xlsx');
  &set_format;
  &ag_filter;
  if ($gn != 0){
    $exp = subTables([$gExp,[0,2..($gn * $plat +1)],
                      $sExp,[2..($sExp->nofCol - $plat )]]);
  }else{
    $exp = subTables([$sExp,[0,2..($sExp->nofCol - $plat )]]);
  }
  $sheet = $book->add_worksheet("All Targets Value");
  $sheet->merge_range( "A1:M1", $noteATV, $note );
  $sheet->set_row(0,120);
  @title = $exp->header;
  @title = map {$_ =~ s/raw/normalized/;$_} $exp->header if $plat == 1;
  $sheet->merge_range(2,1,2,$gn,"Group-Raw Intensity",$GRI) if ($plat == 2 && $gn > 1);
  $sheet->merge_range(2,($plat-1)*$gn+1,2,$plat*$gn,"Group-Normalized Intensity",$GNI) if $gn;
  $sheet->merge_range(2,$plat*$gn+1,2,$plat*$gn+$sn,"Raw Intensity",$RI) if ($plat == 2 && $sn > 1);
  $sheet->merge_range(2,$plat*$gn+$sn*($plat-1)+1,2,$plat*$gn+$sn*$plat,"Normalized Intensity",$NI);
  $sheet->merge_range(2,$plat*$gn+$sn*$plat+1,2,$plat*$gn+($sn-4)*$plat+18,"Annotations",$ANN);
  $sheet->write_row('A4',\@title,$bold);
  $sheet->write_col('A5',$$exp{'data'},$format);
  $sheet->set_column(0,$exp->nofCol - 1,10);
  $sheet = $book->add_worksheet("Box Plot");
  $sheet->merge_range( "A1:M1", $noteBP, $note );
  $sheet->set_row(0,120);
  $sheet = $book->add_worksheet("Scatter Plot");
  $sheet->merge_range( "A1:M1", $noteSP, $note );
  $sheet->set_row(0,80);
  $sheet = $book->add_worksheet("Hierarchical Clustering Map");
  $sheet->merge_range( "A1:M1", $noteHC, $note );
  $sheet->set_row(0,140);
  $book->close();
  ### gene.xlsx saved
  $semaphore->up();
};
$thread->detach();
$semaphore->down();
$thread = async{
  $book = Excel::Writer::XLSX->new('diff.xlsx');
  &set_format;
  for ($i=0;$i<@sDiff;$i++){
    $sDiff[$i] =~ /$s_prefix(\S+-\S+)\.txt/;
    $sc = $1;
    if ($gn != 0) {
      $gDiff[$i] =~ /$g_prefix(\S+-\S+)\.txt/;
      $gc = $1;
      unless ($sc eq $gc){
        print "File missed for $gc $sc.\n";
      }
    }
    $sc =~ s/-/ vs /;
    $sExp = fromTSV($sDiff[$i]);
    $gExp = fromTSV($gDiff[$i]) if $gn;
    &ag_filter;
    if ($gn != 0){
      $exp = subTables([$gExp,[0..(2 * $plat + 3)],
                        $sExp,[4..($sExp->nofCol - $plat )]]);
      $up = $exp->match_pattern('$_->[3] eq "up"');
      $down = $exp->match_pattern('$_->[3] eq "down"');
    }else{
      $exp = subTables([$sExp,[0,3..($sExp->nofCol - $plat )]]);
      $up = $exp->match_pattern('$_->[2] eq "up"');
      $down = $exp->match_pattern('$_->[2] eq "down"');
    }
    $snp = $sExp->nofCol - 4 - ( 18 - 4*$plat ) - ($plat - 1);
    $snp = $plat == 1 ? $snp : $snp / 2;
    &set_note2;
    # up
    $sheet = $book->add_worksheet($sc.'_up');
    $sheet->set_tab_color(45);
    $sheet->merge_range( "A1:M1", $noteUD, $note );
    $sheet->set_row(0,$gn == 0 ? 135 : 130+$plat*30);
    @title = $up->header;
    @title = map {$_ =~ s/raw/normalized/;$_} $up->header if $plat == 1;
    $sheet->merge_range( 2,0,2,$up->nofCol - 1,
                        "$sc $fc fold up regulated genes", $UP );
    &title_format;
    $sheet->write_row('A5',\@title,$bold);
    $sheet->write_col('A6',$$up{'data'},$format);
    open(GO,">go/$sc-up.txt") || die $!;
    open(PA,">path/$sc-up.txt") || die $!;
    foreach $gene (grep {!/^$/}
            $up->col($plat == 1 ? 'GENE_NAME' : 'GeneSymbol')) {
      print GO $gene,"\n";
      print PA "$gene\torange\n";
    }
    # down
    $sheet = $book->add_worksheet($sc.'_down');
    $sheet->set_tab_color(42);
    $sheet->merge_range( "A1:M1", $noteUD, $note );
    $sheet->set_row(0,$gn == 0 ? 135 : 130+$plat*30);
    @title = $down->header;
    @title = map {$_ =~ s/raw/normalized/;$_} $down->header if $plat == 1;
    $sheet->merge_range( 2,0,2,$down->nofCol - 1,
                        "$sc $fc fold down regulated genes", $DOWN );
    &title_format;
    $sheet->write_row('A5',\@title,$bold);
    $sheet->write_col('A6',$$down{'data'},$format);
    open(GO,">go/$sc-down.txt") || die $!;
    open(PA,">path/$sc-down.txt") || die $!;
    foreach $gene (grep {!/^$/}
            $down->col($plat == 1 ? 'GENE_NAME' : 'GeneSymbol')) {
      print GO $gene,"\n";
      print PA "$gene\tyellow\n";
    }
  }
  close GO;
  close PA;
  if ($gn != 0){
    $sheet = $book->add_worksheet("Volcano Plots");
    $sheet->merge_range( "A1:M1", $noteVP, $note );
    $sheet->set_row(0,160);
  }
  $book->close();
  ### diff.xlsx saved
  $semaphore->up();
};
$thread->detach();

&waitquit;

sub title_format{
  if ($gn == 0){
    $sheet->merge_range( 3,1,3,2,'Fold change and Regulation' ,$ANN);
    $sheet->merge_range( 3,3,3,4,'Raw Intensity' ,$GRI) if $plat == 2;
    $sheet->merge_range( 3,$plat*2+1,3,$plat*2+2,'Normalized Intensity' ,$RI);
    $sheet->merge_range( 3,$plat*2+3,3,20-$plat*2,'Annotation' ,$ANN);
  }else{
    $sheet->merge_range( 3,1,3,3,'P-value Fold change and Regulation' ,$ANN);
    $sheet->merge_range( 3,4,3,5,'Group-Raw Intensity' ,$GRI) if $plat == 2;
    $sheet->merge_range( 3,$plat*2+2,3,$plat*2+3,'Group-Normalized Intensity' ,$RI);
    $sheet->merge_range( 3,$plat*2+4,3,$plat*2+$snp+3,'Raw Intensity' ,$GRI) if $plat == 2;
    $sheet->merge_range( 3,$plat*2+$snp*($plat-1)+4,3,$plat*2+$snp*$plat+3,'Normalized Intensity' ,$GNI);
    $sheet->merge_range( 3,$plat*2+$snp*$plat+4,3,21-$plat*2+$snp*$plat,'Annotation' ,$ANN);
  }
  $sheet->set_column(0,$up->nofCol - 1,10);
}
sub ag_filter{
  if($plat == 2){
    $sExp = $sExp->match_pattern('$_->['.($sExp->nofCol-1).'] eq "false"');
    $gExp = $gExp->match_pattern('$_->['.($gExp->nofCol-1).'] eq "false"') if defined $gExp;
  }
}

sub set_format{
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

  $DOWN = $book->add_format();
  $DOWN->set_font('Arial');
  $DOWN->set_bold();
  $DOWN->set_align('center');
  $DOWN->set_size(10);
  $DOWN->set_bg_color(17);

  $UP = $book->add_format();
  $UP->set_font('Arial');
  $UP->set_bold();
  $UP->set_align('center');
  $UP->set_size(10);
  $UP->set_bg_color(10);
}

sub fromTSV{
  my $file = $_[0] || die "File not declared!";
  print "read $file\n";
  my $t = Data::Table::fromTSV($file,1,undef,
      {OS=>1,skip_pattern=>'^\s*#'});
  $t->rotate if ($t->type == 1);
  return $t;
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

sub headerCol{
  my ($table,$idx) = @_;
  return ($table->header)[@{$idx}];
}

sub subTables{
  my $para = $_[0];
  my ($table,$i);
  for($i=0;$i<$#$para;$i+=2){
    unless(defined $table){
      $table = $$para[$i]->subTable(undef,[headerCol($$para[$i],$$para[$i+1])]);
    }else{
      $table->colMerge(
        $$para[$i]->subTable(undef,[headerCol($$para[$i],$$para[$i+1])]));
    }
  }
  $table->rotate if ($table->type == 1);
  return $table;
}

sub char{
  my $no = $_[0];
  $ch = chr(($no - 1) % 26 + 65);
  if($no / 26 > 1){
    $ch = chr(int(($no - 1) / 26) + 64) . $ch;
  }
  return $ch;
}

sub waitquit{
  my $num=0;
  while($num<2){
    $semaphore->down();
    $num++;
  }
  $semaphore->up(2);
}

sub set_note1{
  if($plat == 1){
    $noteATV =
"All Targets Value (Entities where at least $valid out of $sn samples have values greater than or equal to Lower cut-off: $lc.0)\n
# Column A: SEQ_ID, the sequence identifier.
".($gn == 0 ? "" :
"# Column B~".char(1+$gn).": Normalized intensity of each  group
")."# Column ".char($gn+2)."~".char(1+$gn+$sn).": Normalized intensity of each sample, the gene expression summary value for the gene.
# Column ".char(2+$gn+$sn)."~".char($gn+$sn+15).": Annotations to each probe, including ACCESSION, GENE_NAME, SYNONYM, DESCRIPTION, NCBI_GENE_ID, CHROMOSOME, START, STOP,  GO biological process, GO cellular component, GO molecular function, UniGene, TIGRID, EnsemblID.";
  }else{
    $noteATV =
"All Targets Value (Entities where at least $valid out of $sn samples have flags in Detected )\n
# Column A: ProbeName, it represents the probe name.
".($gn == 0 ? "" :
"# Column B~".char(1+$gn).": Raw Intensity of each group (averaged intensity of replicate samples).
# Column ".char(2 + $gn)."~".char(2*$gn + 1).": log2 value of normalized intensity of each group (averaged intensity of replicate samples).
")."# Column ".char(2*$gn + 2)."~".char(2*$gn + $sn + 1).": Raw Intensity of each sample.
# Column ".char(2*$gn + $sn + 2)."~".char(2*$gn + 2*$sn + 1).": log2 value of normalized intensity of each sample.
# Column ".char(2*$gn + 2*$sn + 2)."~".char(2*$gn + 2*$sn + 11).": Annotations to each probe, including GenbankAccession, GenomicCoordinates, GeneSymbol, Description, Go, RefSeqAccession, UniGeneID, EntrezGeneID, EnsemblID, TIGRID.";
  }
  $noteBP =
"Box Plot\n
     The boxplot is a traditional method for visualizing the distribution of a dataset. They are most useful for comparing the distributions of several datasets.
      Here, a boxplot view is used to look at,  and compare, the distributions of expression values for the samples or conditions in an experiment after normalization.\n
     Press Ctrl and rolling button of your mouse to zoom in.";
  $noteSP =
"Scatter Plot\n
      The scatterplot is a visualization that is useful for assessing the variation (or reproducibility) between chips.\n
      Press Ctrl and rolling button of your mouse to zoom in.";

  print "\tQ1. clustering was performed based on:\n\t1. \"All Targets Value\"\n\t2. differentially expressed genes\t[]:";
  $hc = <STDIN>;
  chomp($hc);
  $hc = $hc == 1 ? '"All Targets Value"' : "differentially expressed genes";  $noteHC =
"Heat Map and Unsupervised Hierarchical Clustering\n
     Hierarchical clustering is one of the simplest and widely used clustering techniques for analysis of gene expression data. Cluster analysis arranges samples into groups based on their expression levels, which allows us to hypothesize about the relationships among samples. The dendrogram shows the relationships among the expression levels of samples.\n
      Here, hierarchical clustering was performed based on $hc. Your experiment consists of $sn different conditions. The result of hierarchical clustering on conditions shows distinguishable gene expression profiling among samples.\n
       Press Ctrl and rolling button of your mouse to zoom in.";
}

sub set_note2{
  # note in diff table in grouped condition
  if ($gn == 0){
  $noteUD = $plat == 1 ?
"# Condition pairs: $sc
# Fold Change cut-off: $fc\n
# Column A: ProbeName, it represents probe name.
# Column B: Absolute Fold change, the absolute ratio (no log scale) of normalized intensities between two groups.
# Column C: Regulation, it depicts which one of the groups has greater or lower intensity values wrt other group.
# Column D,E: Raw Intensity of each sample.
# Column F,G: log2 value of normalized intensity of each sample.
# Column H~Q: Annotations to each probe, including GenbankAccession, GenomicCoordinates, GeneSymbol, Description, Go, RefSeqAccession, UniGeneID, EntrezGeneID, EnsemblID, TIGRID.
" :
"# Condition pairs: $sc
# Fold Change cut-off: $fc\n
# Column A: SEQ_ID, the sequence identifier.
# Column B: FCAbsolute, the absolute ratio (no log scale) of normalized intensities between two samples.
# Column C: Regulation, it depicts which sample has greater or lower intensity values wrt other sample.
# Column D~E: Normalized Intensity of each sample, the gene expression summary value for the gene.
# Column F~S: Annotations for each gene, including ACCESSION, GENE_NAME, SYNONYM, DESCRIPTION, NCBI_GENE_ID, CHROMOSOME, START, STOP, GO biological process, GO cellular component, GO molecular function, UniGene, TIGRID, EnsemblID.";
  }else{
  $noteUD =
"# Condition pairs: $sc
# Fold Change cut-off: $fc
# P-value cut-off: $pc\n
".($plat == 1 ? "# Column A: SEQ_ID, the sequence identifier.
":"# Column A: ProbeName, it represents probe name.
")."# Column B: p-value, p-value calculated from T-Test.
# Column C: FCAbsolute, the absolute ratio (no log scale) of normalized intensities between two groups.
# Column D: Regulation, it depicts which one of the groups has greater or lower intensity values wrt other group.
".($plat == 1 ? "" :
"# Column E,F: Raw Intensity of each group (averaged intensity of replicate samples).
")."# Column ".char(3+$plat*2).",".char(4+$plat*2).": log2 value of normalized intensity of each group (averaged intensity of replicate samples).
".($plat == 1 ? "" :
"# Column ".char(5+$plat*2)."~".char(4+$plat*2+$snp).": Raw Intensity of each sample.
")."# Column ".char(5+$plat*2+$snp*($plat-1))."~".char(4+$plat*(2+$snp)).": log2 value of normalized intensity of each sample.
# Column ".char(5+$plat*(2+$snp))."~".char(22+$plat*($snp-2)).": Annotations to each probe, including GenbankAccession, GenomicCoordinates, GeneSymbol, Description, Go, RefSeqAccession, UniGeneID, EntrezGeneID, EnsemblID, TIGRID.";
  }

  $noteVP =
"Volcano plots\n
      Volcano plots are a useful tool for visualizing differential expression between two different conditions. They are constructed using fold-change values and p-values, and thus allow you to visualize the relationship between fold-change and statistical significance (which takes both magnitude of change and variability into consideration).\n
      The vertical lines correspond to $fc-fold up and down, respectively, and the horizontal line represents a p-value of $pc. So the red point in the plot represents the differentially expressed genes with statistical significance.\n
     Press Ctrl and rolling button of your mouse to zoom in." if $gn;
}
