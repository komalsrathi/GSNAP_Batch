#!/usr/bin/perl -w
use Parallel::ForkManager;
use Data::Dumper;

# parameter file name as commandline argument
my $paramfile = $ARGV[0]; 

# read in param file, PARAM is the file handle, and create a hash of all the parameters.
# split by => and make the first column, the key and the second column, the value. 
open PARAM, $paramfile or die print $!;
my %param;

while(<PARAM>)
{
        chomp;
        @r = split('=>');
        #print "@r";
        $param{$r[0]}=$r[1];
}

# directories
$param{'ALNDIR'} = $param{'PROJECTNAME'}.'/gsnap';
$param{'CUFFLINKS'} = $param{'PROJECTNAME'}.'/cufflinks';
$param{'CUFFQUANT'} = $param{'PROJECTNAME'}.'/cuffquant';
$param{'CUFFNORM'} = $param{'PROJECTNAME'}.'/cuffnorm';
$param{'CUFFDIFF'} = $param{'PROJECTNAME'}.'/cuffdiff';
$param{'CUFFMERGE'} = $param{'PROJECTNAME'}.'/cuffmerge';


# make directory with projectname and subdirectories gsnap, cufflinks, cuffquant, cuffnorm and cuffdiff
system("mkdir $param{'PROJECTNAME'}") unless (-d $param{'PROJECTNAME'});
system("mkdir $param{'CUFFLINKS'}") unless (-d $param{'CUFFLINKS'});
system("mkdir $param{'CUFFMERGE'}") unless (-d $param{'CUFFMERGE'});
system("mkdir $param{'CUFFQUANT'}") unless (-d $param{'CUFFQUANT'});
system("mkdir $param{'CUFFNORM'}") unless (-d $param{'CUFFNORM'});
system("mkdir $param{'CUFFDIFF'}") unless (-d $param{'CUFFDIFF'});

# run cufflinks
foreach (@samples)
{
    $pm->start and next;
    
    # run cufflinks
    my $cuffcmd = "cufflinks --library-type $param{'LIBTYPE'} -p $param{'PROCESSORS'} -o $param{'CUFFLINKS'}/$_->[2] $param{'ALNDIR'}/".$_->[2]."_filter_sort.bam 2> $param{'CUFFDIR'}/$_->[2].out";
    print $cuffcmd,"\n";
    system($cuffcmd);
    
    print "$_->[2] completed\n";
    
    $pm->finish;
}

# run cuffmerge
my $cuffmrg = "cuffmerge -o $param{'CUFFMERGE'} -g $param{'GTF'} -s $param{'FASTA'} -p $param{'PROCESSORS'} $param{'ASSEMBLY'}";
print $cuffmrg,"\n";
system($cuffmrg);

# run cuffquant
foreach (@samples)
{
    $pm->start and next;
    
    # library type can be determined by using infer_experiment.py @http://rseqc.sourceforge.net/#infer-experiment-py
    my $cuffquant = "cuffquant -o $param{'CUFFQUANT'}/$_->[2] -p $param{'PROCESSORS'} --frag-bias-correct $param{'FASTA'} --multi-read-correct --library-type $param{'LIBTYPE'} $param{'GTF'} $param{'ALNDIR'}/".$_->[2]."_filter_sort.bam";
    print $cuffquant,"\n";
    system($cuffquant);
    
    print "$_->[2] completed\n";
    
    $pm->finish;
}

# wait for cuffquant to finish and then start cuffnorm
$pm->wait_all_children;
print "\nCuffquant Finished.....\n";
print "\nStarting Cuffnorm......\n";

# run cuffnorm
# for cuffnorm, unfortunately you have to explicitly provide the names of samples
my $cuffnorm = "cuffnorm -o $param{'CUFFNORM'} --library-type $param{'LIBTYPE'} -L Control,Case -p $param{'PROCESSORS'} $param{'GTF'} $param{'CUFFQUANT'}/Control_sample1/abundances.cxb,$param{'CUFFQUANT'}/Control_sample2/abundances.cxb,$param{'CUFFQUANT'}/Control_sampleN/abundances.cxb $param{'CUFFQUANT'}/Case_sample1/abundances.cxb,$param{'CUFFQUANT'}/Case_sample2/abundances.cxb,$param{'CUFFQUANT'}/Case_sampleN/abundances.cxb";
print $cuffnorm,"\n";
system($cuffnorm);

# run cuffdiff
# for cuffdiff, you have to explicitly provide the names of samples
my $cuffdiff = "cuffdiff -o $param{'CUFFDIFF'} --library-type $param{'LIBTYPE'} -L Control,Case --multi-read-correct -b $param{'FASTA'} -p $param{'PROCESSORS'} $param{'GTF'} $param{'CUFFQUANT'}/Control_sample1/abundances.cxb,$param{'CUFFQUANT'}/Control_sample2/abundances.cxb,$param{'CUFFQUANT'}/Control_sampleN/abundances.cxb $param{'CUFFQUANT'}/Case_sample1/abundances.cxb,$param{'CUFFQUANT'}/Case_sample2/abundances.cxb,$param{'CUFFQUANT'}/Case_sampleN/abundances.cxb";
print $cuffdiff,"\n";
system($cuffdiff);
