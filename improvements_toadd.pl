#create txt files for cuffmerge & cuffdiff
open (MYFILE, '>>assembly_list.txt');
open (OUTFILE, '>>inputfilelist.txt');

# labels for cuffnorm/cuffquant/cuffdiff
my @labels;

# run cufflinks
 if($param{'RUNCUFFLINKS'})
 {
    # run cufflinks
    my $cufflinkscmd = "cufflinks -p $param{'THREADS'} -o $param{'CUFFDIR'}/$_->[2] $param{'ALNDIR'}/".$_->[2]."_fixmate.bam 2> $param{'CUFFDIR'}/$_->[2].out";
    print $cufflinkscmd,"\n";                       
    system($cufflinkscmd);
                        
    # add output file name to assembly_list.txt for cuffmerge
    print MYFILE "$param{'CUFFDIR'}/$_->[2]/transcripts.gtf\n";
                        
    # add *_fixmate.BAM file names to inputfilelist.txt
    print OUTFILE "$param{'ALNDIR'}/".$_->[2]."_fixmate.bam\n";
                        
    # create an array of labels for cuffdiff/cuffnorm/cuffquant
    push(@labels,"$_->[2]");
  }
  
# run cuffmerge 
# this command will create a merged.gtf in CUFFDIR
my $cuffmergecmd = "cuffmerge -g $param{'GTF'} -s $param{'GENOME'} -p $param{'THREADS'} assembly_list.txt -o $param{'CUFFDIR'}";
print $cuffmergecmd,"\n";
system($cuffmergecmd);

my $label = join(',', @labels);

#run cuffdiff
my $cuffdiffcmd = "cuffdiff -o $param{'CUFFDIR'}/$_->[2]/diff_out -L $label -b $param{'GENOMEFA'} -p $param{'THREADS'} -u $param{'CUFFDIR'}/merged.gtf inputfilelist.txt";
print $cuffdiffcmd,"\n";
system($cuffdiffcmd);
