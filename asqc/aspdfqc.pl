#!/usr/bin/env perl
# Author: Zhao
# Date: 2012-04-25 16:51
# Purpose: automate the production of pdf qc file.

use MsOffice::Word::HTML::Writer;
use CAM::PDF;
use 5.010;
use Data::Table;
use warnings;
use Smart::Comments;

$name_tbl = fromTSV('../name.txt');
### Sample number : $name_tbl->nofRow
mkdir('images');
foreach $i ( 0 .. $name_tbl->nofRow - 1) {
  $pdf = $name_tbl->elm($i,0);
  open(IN, '../../'.$pdf) || die $!;
  $txt = <IN>.<IN>.<IN>;
  $txt =~ s/\d{12}_//g;
  $txt =~ s/_\d{12}//g;
  $/ = undef;
  $txt .= <IN>;
  open(OUT, '>'.$name_tbl->elm($i,1).'.txt') || die $!;
  print OUT $txt;
  close(IN);
  close(OUT);
  $pdf =~ s/txt$/pdf/;
  ### producing : $pdf
  $pdf_file = "../../$pdf";
  unless (-e $pdf_file) {
    die "$pdf not found!";
  }
  system("pdfimages -f 1 -l 1 $pdf_file images/");
  foreach $j ( 0 .. 2 ) {
    system("mv images/-00$j.ppm images/$j.ppm");
    system("ppmtojpeg images/$j.ppm > images/$j.jpeg");
  }
  &find_info($pdf_file,$name_tbl->elm($i,1));
  system("rm -f images/*");
}
### Job done

sub fromTSV{
  my $file = $_[0] || die "File not declared!";
  my %fileGuessOS = ( 0 => "UNIX", 1 => "DOS", 2 => "MAC" );
  print "read $file in ",$fileGuessOS{Data::Table::fromFileGuessOS($file)}," format.\n";
  return Data::Table::fromTSV($file,1,undef,
      {OS=>Data::Table::fromFileGuessOS($file),
      skip_pattern=>'^\s*#'});
}

sub find_info {
  my $file = shift || '';
  my $doc_file = shift;
  my $pdf = CAM::PDF->new($file);
  my $content = $pdf->getPageText(1) . $pdf->getPageText(2);
  if ( $content =~ / Date (.*?) Grid (.*?) Image\s*(.*?) BG Method .*? Protocol (.*?) Background Detrend .*? User Name .*? Multiplicative Detrend .*? FE Version (.*?) Additive Error .*? Sample\(red\/green\).*? Saturation Value (.* \(g\))/ms )
  {
    $Date       = $1;
    $Grid       = $2;
    $Image      = $3;
    $Protocol   = $4;
    $FE         = $5;
    $Saturation = $6;
    $Image      =~ s/\n/ /g;
    $Image      =~ s/_\d+//;
    # say join( "\n", $Date, $Grid, $Image, $Protocol, $FE, $Saturation );
  }
  else {
    say 'pattern no found 1';
  }

  if ( $content =~ m#Non Uniform\n(.*?)\n(.*?)\nPopulation\n(.*?)\n(.*?)\n# ) {
    $spot1 = $1;
    $spot2 = $2;
    $spot3 = $3;
    $spot4 = $4;
    # say join("\n",$spot1,$spot2,$spot3,$spot4);
  }
  else {
    say 'pattern no found 2';
  }

# FeatureNonUnif (Green) = 4(0.01%)
# GeneNonUnif (Green) = 3 (0.008 %)
  if ( $content =~ m/# FeatureNonUnif \(Green\) = (.*?%\))\n# GeneNonUnif \(Green\) = (.*?%\))/ ) {
    $spa1 = $1;
    $spa2 = $2;
    # say join(', ',$spa1,$spa2);
  }
  else {
    say 'pattern no found 3';
  }

  if ( $content =~ /Non-Control probes:\nGreen\n# Saturated Features\n(.*?)\n99% of Sig. Distrib.\n(.*?)\n50% of Sig. Distrib.\n(.*?)\n1% of Sig. Distrib.\n(.*?)\n/ ) {
    $non1 = $1;
    $non2 = $2;
    $non3 = $3;
    $non4 = $4;
    # say join(', ',$non1,$non2,$non3,$non4);
  }
  else {
    say 'pattern no found 4';
  }

  if ( $content =~ m#Features \(NonCtrl\) with BGSubSignal < 0: (.*?) \(Green\)# ) {
    $his = $1;
    # say $his;
  }
  else {
    say 'pattern no found 5';
  }

  if ( $content =~ m#Negative Control Stats\nGreen\nAverage Net Signals\n(.*?)\nStdDev Net Signals\n(.*?)\nAverage BG Sub Signal\n(.*?)\nStdDev BG Sub Signal\n(.*?)\n# ) {
    $ncs1 = $1;
    $ncs2 = $2;
    $ncs3 = $3;
    $ncs4 = $4;
    # say join(', ',$ncs1,$ncs2,$ncs3,$ncs4);
  }
  else {
    say 'pattern no found 6';
  }

  # if ( $content =~ m#Local Bkg \(inliers\)\nGreen\nNumber\n(.*?)\nAvg\n(.*?)\nSD\n(.*?)\n# ) {
  if ( $content =~ m#Number\n(.*?)\nAvg\n(.*?)\nSD\n(.*?)\n# ) {
    $lb1 = $1;
    $lb2 = $2;
    $lb3 = $3;
    # say join(', ',$lb1,$lb2,$lb3);
  }
  else {
    say 'pattern no found 7';
  }

  if ( $content =~ m#BGSubSignal\n(.*?)\n.*?\nProcessedSignal\n(.*?)\n.*?\n# ) {
    $r1 = $1;
    $r2 = $2;
    # say join(', ',$r1,$r2);
  }
  else {
    say 'pattern no found 8';
  }

  my $doc = MsOffice::Word::HTML::Writer->new(
    title        => "My new doc",
    WordDocument => {View => 'Print'},
  );

  $doc->create_section(
    page => {size   => "21.0cm 29.7cm",
             margin => "2.18cm 2.25cm 2.00cm 2.25cm",
             header_margin => "0.8cm",
             footer_margin => "1.2cm"},
    header => '<p align="right"><img src="logos.jpg" width="96" height="37"></p>',
    footer => '<table align="center" width="100%" style="font:11px Tahoma">
      <tr>
      <td width="50%">Arraystar Inc. 9700 Great Seneca Highway.</td>
      <td>Tel: 240-314-0388</td>
      <td>Email: support@arraystar.com</td>
      </tr>
      <tr>
      <td>Rockville, MD 20850. USA</td>
      <td>Fax: 240-238-9860</td>
      <td>Website: www.arraystar.com</td>
      </tr>
      </table>',
    new_page => 0,
  );

  $doc->write('<style type="text/css">
table {font:11px Verdana;width:100%;}
#t {font:bold 11px Verdana;text-align:center;}
#nt {font:11px Verdana;text-align:center;}
</style>
<span style="font:bold 16px Calibri;">QC Report - Agilent Technologies: 1 Color</span>
<table width="100%">
<tr>
  <td>Date</td>
  <td>'.$Date.'</td>
  <td>Grid</td>
  <td>'.$Grid.'</td>
</tr>
<tr>
  <td>Image</td>
  <td>'.$Image.'</td>
  <td>FE</td>
  <td>Version '.$FE.'</td>
</tr>
<tr>
  <td>Protocol</td>
  <td>'.$Protocol.'</td>
  <td>Saturation Value</td>
  <td>'.$Saturation.'</td>
</tr>
</table>
<hr style="height:2px;border-width:2;color:black;" />
<table width="100%" cellpadding="10">
<td width="50%" valign="top">
<p id="t">Spot Finding of the Four Corners of the Array</p>
<img src="files/0.jpeg">
<br /><br />
<table>
<tr>
<td width="31%"></td>
<td id="t" width="31%">Feature</td>
<td id="t" width="38%">Local Background</td>
</tr>
</table>
<style type="text/css">
table, td, tr {background-color:#fde9d9;border: 1px solid white;border-spacing:0;border-collapse:collapse;}
</style>
<table>
<tr>
<td width="31%"></td>
<td width="31%" align="right">Green</td>
<td width="38%" align="right">Green</td>
</tr>
<tr>
<td>Non Uniform</td>
<td align="right">'.$spot1.'</td>
<td align="right">'.$spot2.'</td>
</tr>
<tr>
<td>Population</td>
<td align="right">'.$spot3.'</td>
<td align="right">'.$spot4.'</td>
</tr>
</table>
<br /><br />
<p id="t">Spatial Distribution of All Outliers on the Array</p>
<p align="center"><img src="files/1.jpeg" width="180" height="330"></p>
<p id="nt"># FeatureNonUnif (Green) = '.$spa1.'</p>
<p id="nt"># GeneNonUnif (Green) = '.$spa2.'</p>
<style type="text/css">
table, td, tr {background-color:transparent;border: 0px;}
</style>
<table style="font:10px Verdana;">
<tr>
<td><img src="files/lu.png" width=5 height=5>BG NonUniform</td>
<td><img src="files/ru.png" width=5 height=5>BG Population</td>
</tr>
<tr>
<td><img src="files/ld.png" width=5 height=5>Green FeaturePopulation</td>
<td><img src="files/rd.png" width=5 height=5>Green Feature NonUniform</td>
</tr>
</table>
</td>
<td width="50%" valign="top">
<p id="t">Non-Control probes Net Signal Statistics</p>
<table>
<tr>
<td width="65%"></td>
<td id="ut" width="35%" align="right">Green</td>
</tr>
</table>
<style type="text/css">
table, td, tr {background-color:#fde9d9;border-collapse:collapse;border: 1px solid white;}
</style>
<table style="border-collapse:collapse;">
<tr>
<td width="65%"># Saturated Features</td>
<td id="ut" width="35%" align="right">'.$non1.'</td>
</tr>
<tr>
<td width="65%">99% of Sig. Distrib.</td>
<td id="ut" width="35%" align="right">'.$non2.'</td>
</tr>
<tr>
<td width="65%">50% of Sig. Distrib.</td>
<td id="ut" width="35%" align="right">'.$non3.'</td>
</tr>
<tr>
<td width="65%">1% of Sig. Distrib.</td>
<td id="ut" width="35%" align="right">'.$non4.'</td>
</tr>
</table>

<p id="t">Histogram of Signals Plot</p>
<p align="center" id="nt"><img src="files/2.jpeg" width="230" height="230">
<br />
# Features (NonCtrl) with BGSubSignal < 0: '.$his.' (Green)</p>

<p id="t">Negative Control Stats</p>
<style type="text/css">
table, td, tr {background-color:transparent;border: 0px;}
</style>
<table>
<tr>
<td width="65%"></td>
<td id="ut" width="35%" align="right">Green</td>
</tr>
</table>
<style type="text/css">
table, td, tr {background-color:#fde9d9;border-collapse:collapse;border: 1px solid white;}
</style>
<table style="border-collapse:collapse;">
<tr>
<td width="65%">Average Net Signals</td>
<td id="ut" width="35%" align="right">'.$ncs1.'</td>
</tr>
<tr>
<td width="65%">StdDev Net Signals</td>
<td id="ut" width="35%" align="right">'.$ncs2.'</td>
</tr>
<tr>
<td width="65%">Average BG Sub Signal</td>
<td id="ut" width="35%" align="right">'.$ncs3.'</td>
</tr>
<tr>
<td width="65%">StdDev BG Sub Signal</td>
<td id="ut" width="35%" align="right">'.$ncs4.'</td>
</tr>
</table>

<p id="t">Local Bkg (inliers)</p>
<style type="text/css">
table, td, tr {background-color:transparent;border: 0px;}
</style>
<table>
<tr>
<td width="65%"></td>
<td id="ut" width="35%" align="right">Green</td>
</tr>
</table>
<style type="text/css">
table, td, tr {background-color:#fde9d9;border-collapse:collapse;border: 1px solid white;}
</style>
<table style="border-collapse:collapse;">
<tr>
<td width="65%">Number</td>
<td id="ut" width="35%" align="right">'.$lb1.'</td>
</tr>
<tr>
<td width="65%">Avg</td>
<td id="ut" width="35%" align="right">'.$lb2.'</td>
</tr>
<tr>
<td width="65%">SD</td>
<td id="ut" width="35%" align="right">'.$lb3.'</td>
</tr>
</table>
<style type="text/css">
table, td, tr {background-color:transparent;border: 0px;}
</style>
<p id="t">Reproducibility: Median %CV for Replicated Signal (inliers) Non-Control probes</p>
<style type="text/css">
table, td, tr {background-color:transparent;border: 0px;}
</style>
<table>
<tr>
<td width="65%"></td>
<td id="ut" width="35%" align="right">Green</td>
</tr>
</table>
<style type="text/css">
table, td, tr {background-color:#fde9d9;border-collapse:collapse;border: 1px solid white;}
</style>
<table style="border-collapse:collapse;">
<tr>
<td width="65%">BGSubSignal</td>
<td id="ut" width="35%" align="right">'.$r1.'</td>
</tr>
<tr>
<td width="65%">ProcessedSignal</td>
<td id="ut" width="35%" align="right">'.$r2.'</td>
</tr>
</table>
</td>
</table>
<style type="text/css">
table, td, tr {background-color:transparent;border: 0px;}
</style>
  ');
  $doc->attach("logos.jpg","logos.jpg");
  $doc->attach("0.jpeg","images/0.jpeg");
  $doc->attach("1.jpeg","images/1.jpeg");
  $doc->attach("2.jpeg","images/2.jpeg");
  $doc->attach("lu.png","lu.png");
  $doc->attach("ru.png","ru.png");
  $doc->attach("ld.png","ld.png");
  $doc->attach("rd.png","rd.png");
  $doc->save_as("Array QC Report for $doc_file.doc");
}
