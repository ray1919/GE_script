#!/usr/bin/perl -w
# script name: get_gff_refGene.pl
# script version: perl5.8.8.822
# Date: 2009.5.24
# Author: Swimbaby
# Description:
# Revision History:
# 1.0/<date>: original version
use File::Copy;

my $dir = 'Negative';
mkdir($dir);
#use Cwd;
#$mydir = getcwd();

##################################################
#输入名称
my $chrom = 'Negative';
# $filename = "";
##################################################
#主函数

while(my $filename = <*.txt>)
{
 chop $filename; chop $filename;  chop $filename;    chop $filename;
&get_sub_list($filename,$chrom);
 }
 print "complete!\n";


sub get_sub_list
{

open (TOTAL, "$_[0].txt") or die "error(input2):$!";
# 打开文件，准备从文件中读取DNA序列。
open(CONTAIN, ">$dir/$_[0]\_$_[1]") or die "error (output1):$!";
my  $line;
while ( $line= <TOTAL> )
{
   if($line =~ /^FEATURES/)
   {
     print CONTAIN "$line";
     last;
   }
}

while ( $line= <TOTAL> )
{
      my @terms = split(/\t/,$line);
      if($terms[6])
      {
        my $name = substr($terms[6],0,8);
           if($name eq $_[1])
             {
               print CONTAIN "$line";
             }
   }
}

close TOTAL;
close CONTAIN;
print "successful!\n";
}



$tag="Negative";
$column = 10;


##################################################
my $kkk = "A";

@files=glob "*_$tag";
$count = @files;


print $count,"\n";

open OUTPUT,">$dir/$tag" or die "error(input):$!";

$i = 0;
foreach $file(@files)
{
open INPUT,"$file" or die "error(input):$!";
$line = <INPUT>;
$j=1;
while(<INPUT>)
{
@terms = split(/\t/,$_);
$data[$i][$j] = $terms[10];
$j++;
}
$i++;
close INPUT;
print "successful read a file!\n";
}

open INPUT,"$dir/$files[0]" or die "error(input):$!";
        print "open the $files[0]\n";
        $line = <INPUT>;
        @terms=split(/\t/,$line);
       for($i=0;$i<($column - 1) ;$i++)
            {
              print OUTPUT "$terms[$i]\t";
              print "$terms[$i]\n";
             }
       for($i=0;$i<$count;$i++)
            {
              print OUTPUT "$files[$i]\t";
            }
              print OUTPUT "\n";
print "the first line has been output!\n";

$j=1;
while(<INPUT>)
{
        @terms=split(/\t/,$_);
        for($i=0; $i < ($column - 1) ;$i++)
            {
              print OUTPUT "$terms[$i]\t";
             }

for($i=0;$i<$count;$i++)
{
print OUTPUT "$data[$i][$j]\t";
}
print OUTPUT "\n";
$j++;
}


close OUTPUT;
print "successful get the sublist!\n";
