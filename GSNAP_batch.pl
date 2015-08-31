#!/usr/bin/perl -w
use Parallel::ForkManager;
use Data::Dumper;

#parameter file name as commandline argument
my $paramfile = $ARGV[0]; 

#read in param file, PARAM is the file handle, and create a hash of all the parameters.
#split by => and make the first column, the key and the second column, the value. 
open PARAM, $paramfile or die print $!;
my %param;
while(<PARAM>)
{
	chomp;
	@r = split('=>');
	#print "@r";
	$param{$r[0]}=$r[1];
}

$param{'ALNDIR'} = $param{'PROJECTNAME'}.'/gsnap';
$param{'CUFFDIR'} = $param{'PROJECTNAME'}.'/cufflinks';
$param{'COUNTDIR'} = $param{'PROJECTNAME'}.'/htseq_count';

#make directory with projectname and subdirectories gsnap, cufflinks and genecounts
system("mkdir $param{'PROJECTNAME'}") unless (-d $param{'PROJECTNAME'});
system("mkdir $param{'ALNDIR'}") unless (-d $param{'ALNDIR'});
system("mkdir $param{'CUFFDIR'}") unless (-d $param{'CUFFDIR'});
system("mkdir $param{'COUNTDIR'}") unless (-d $param{'COUNTDIR'});

#open file with filename which is value of the key FASTALIST
open FILE, $param{'FASTALIST'} or die 

#create an array samples
my @samples;

#splitting each line based on ',' and storing in an array @r
#pushing the reference of this array in another array @samples
while(<FILE>){
	chomp;
	my @r = split(',');
	push(@samples,\@r);
}

# start time
my $start_run = time();

# run parallel jobs
my $pm=new Parallel::ForkManager($param{'JOBS'});

foreach (@samples)
{	
	$pm->start and next;		
		
		# Align with gsnap
		# --batch=5 expands genomic indexes, expansion gives faster alignments	
		# --distant-splice-penalty when intron-length>local-splice-distance
		# --clip-overlap for paired end reads, clip overlapping alignments
		# -s known splice-sites in .iit file
		# -N look for novel splice-sites
		# -v use db containing known snps
		# convert sam output to bam
		my $gsnapcmd = "gsnap -d $param{'GENOME'} --gunzip --batch=5 --nthreads=$param{'THREADS'} --distant-splice-penalty=10000 --clip-overlap -s $param{'SPLICEFILE'} -N 1 --npaths=100 -Q -v $param{'SNPFILE'} --read-group-id=$_->[2] --read-group-name=$_->[2] --read-group-library=$_->[2] --read-group-platform='Illumina' --format=sam $param{'FASTQDIR'}/$_->[0] $param{'FASTQDIR'}/$_->[1]  2> $param{'ALNDIR'}/$_->[2].out | samtools view -bS - > $param{'ALNDIR'}/$_->[2].bam";
		print $gsnapcmd,"\n";		
		system($gsnapcmd);
		
		# get unmapped reads and convert to fastq
                # my $cmd= "samtools view -f 0x0004 -h $param{'ALNDIR'}/".$_->[2].".bam | java -jar /opt/picard/SamToFastq.jar INPUT=/dev/stdin FASTQ=$param{'UMFASTQDIR'}/".$_->[2]."_unmapped_R1.fastq SECOND_END_FASTQ=$param{'UMFASTQDIR'}/".$_->[2]."_unmapped_R2.fastq";
                # print $cmd,"\n";
                # system($cmd);

		# Fix the bam file
		# remove unmapped reads and secondary alignments
		my $samfixmatecmd="samtools fixmate $param{'ALNDIR'}/".$_->[2].".bam $param{'ALNDIR'}/".$_->[2]."_unsortfix.bam";
		print $samfixmatecmd,"\n";
		system($samfixmatecmd);

		# filter bam file based on some condition
		my $filtercmd = "bamtools filter -script $param{'BAMFILTER'} -in $param{'ALNDIR'}/".$_->[2]."_unsortfix.bam -out ".$param{'ALNDIR'}.'/'.$_->[2]."_filter.bam";
		print $filtercmd,"\n";
		system($filtercmd);

		# sort the fixed+filtered bam file
		my $samsortcmd="samtools sort  $param{'ALNDIR'}/".$_->[2]."_filter.bam $param{'ALNDIR'}/".$_->[2]."_filter_sort";
		print $samsortcmd,"\n";
		system($samsortcmd);

		# Index the sorted bam file
		my $samindexcmd="samtools index $param{'ALNDIR'}/".$_->[2]."_filter_sort.bam";
		print $samindexcmd,"\n";
		system($samindexcmd);
		
		# Convert bam file to sam
		# Make counts (how many reads map to each feature) using htseq-count.
		my $htseqcountcmd = "samtools view -f 0x0002 $param{'ALNDIR'}/$_->[2]_unsortfix.bam | awk '!/\\t\\*\\t/' - | htseq-count -s reverse - $param{'GTF'} > $param{'COUNTDIR'}/$_->[2].counts";
		print $htseqcountcmd,"\n";
		system($htseqcountcmd);

		# run cufflinks
		my $cuffcmd = "cufflinks --library-type fr-firststrand -p 2 -o $param{'CUFFDIR'}/$_->[2] $param{'ALNDIR'}/".$_->[2]."_filter_sort.bam 2> $param{'CUFFDIR'}/$_->[2].out";
		print $cuffcmd,"\n";			
		system($cuffcmd);
        
        	# run cuffquant
        	my $cuffquant = "cuffquant -o ./cuffquant/$_->[2] -p 10 --frag-bias-correct /NGSshare/hg19_data/hg19.fa --multi-read-correct --library-type fr-firststrand $param{'GTF'} ../gsnap/".$_->[2]."_filter_sort.bam";
		print $cuffquant,"\n";
		system($cuffquant);

		print "$_->[2] completed\n"; 
	
	$pm->finish;
}

$pm->wait_all_children;

#run cuffmerge
my $cuffmrg = "cuffmerge -g $param{'GTF'} -s $param{'GENOME'} -p 25 assembly_list.txt";
print $cuffmrg,"\n";
system($cuffmrg);

# end time
my $end_run = time();
my $run_time = $end_run - $start_run;
print "Job took $run_time seconds\n";

# from here on, either follow cufflinks_batch.pl or lincRNA discovery pipeline
