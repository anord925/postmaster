#!/usr/bin/env perl
use warnings;
use strict;
use POSIX;
use Cwd;


#  FUNCTIONAL SUBROUTINES
#
sub AddPost;
sub RemovePost;
sub RemoveMostRecentPost;
sub PublishSite;
sub FullDirFileExtraction;


#  BEUREAUCRATIC SUBROUTINES
#
sub MIN;
sub MAX;
sub RunSystemCommand;
sub OpenSystemCommand;
sub OpenInputFile;
sub NameOutputFile;
sub OpenOutputFile;
sub OpenFileToAppendTo;
sub DeleteFile;
sub ConfirmDirectory;
sub OpenDirectory;
sub NameDirectory;
sub CreateDirectory;



############
#          #
#  SCRIPT  #
#          #
############


# Where the names of any files to be removed will live
my $nixxed_fname = 'src/nixxed.txt';


if (@ARGV < 1) {
    print "\n";
    print "  USAGES:\n";
    print "  -------\n";
    print "   %  ./ManageSite.pl add [post]\n";
    print "   %  ./ManageSite.pl remove [optional:fname (default:most-recent)]\n";
    print "   %  ./ManageSite.pl publish\n";
    die "\n";
}


my $opt = lc($ARGV[0]);
if ($opt eq 'add') {
    
    AddPost();

} elsif ($opt eq 'remove') {

    if (scalar(@ARGV)==2) {
	RemovePost($ARGV[1]);
    } else {
	RemoveMostRecentPost();
    }

} elsif ($opt eq 'publish') {

    PublishSite();

} else {
    die "\n  ERROR: Unrecognized option '$opt'\n\n";
}


1;  ##   END OF SCRIPT   ##





############################
#                          #
#  FUNCTIONAL SUBROUTINES  #
#                          #
############################





#################################################################
#
#  FUNCTION:  AddPost
#
sub AddPost
{
    my $fname = $ARGV[1];
    if (!(-e $fname)) {
	die "\n  ERROR:  Failed to locate post file '$fname'\n\n";
    }

    RunSystemCommand('./src/FormatAndCopyPost.pl '.$fname);
    RunSystemCommand('./src/UpdateInternalLinks.pl');

}





#################################################################
#
#  FUNCTION: RemovePost
#
sub RemovePost
{
    my $fname = shift;

    # Sanity check
    $fname =~ /^([^\/]+)\//;
    my $category = $1;
    if ($category ne 'research' && $category ne 'play') {
	die "\n  ERROR:  Failed to recognize category of '$fname' (should be 'research' or 'play')\n\n";
    }

    # Remove the file from our posts-by-date file
    my $pbd_name = '../Site/posts-by-date.txt';
    my $tmpfname = 'src/tmp-pbd.txt';
    open(my $tmpf,'>',$tmpfname) || die "\n  ERROR: Failed to open output file '$tmpfname'\n\n";

    my $pbd = OpenInputFile($pbd_name);
    my $found_file = 0;
    while (my $line = <$pbd>) {
	$line =~ s/\n|\r//g;
	if (!$line || $line =~ /^$fname/) {
	    $found_file = 1;
	    next;
	}
	print $tmpf "$line\n";
    }
    close($pbd);
    close($tmpf);

    # Doesn't hurt, even if we didn't find the file we were looking for
    RunSystemCommand("mv $tmpfname $pbd_name");

    # Warn the user that we didn't see this file, if that is in fact the case
    if (!$found_file) {
	print "\n  Warning:  Didn't find file '$fname' in '$pbd_name'\n\n";
    }
    
    # Update our catalogs and nav bars
    RunSystemCommand('./src/UpdateInternalLinks.pl');
    
    # Add this to our list of removed posts
    my $outf;
    if (-e $nixxed_fname) {
	open($outf,'>>',$nixxed_fname) || die "\n  ERROR:  Failed to open 'src/nixxed.txt'\n\n";
    } else {
	$outf = OpenOutputFile($nixxed_fname);
    }
    print $outf "$fname\n";
    close($outf);

}






#################################################################
#
#  FUNCTION: RemoveMostRecentPost
#
sub RemoveMostRecentPost
{

    # Open up the catalog and identify the most recent post
    my $inf = OpenInputFile('../Site/posts-by-date.txt');
    my $most_recent = 0;
    while (my $line = <$inf>) {
	$line =~ s/\n|\r//g;
	if ($line =~ /^(\S+)/) {
	    $most_recent = $1;
	    last;
	}
    }
    close($inf);

    if (!$most_recent) {
	die "\n  ERROR:  Failed to identify any posts in '../Site/posts-by-date.txt'\n\n";
    }

    RemovePost($most_recent);
    
}





#################################################################
#
#  FUNCTION: PublishSite
#
sub PublishSite
{

    # So you think it's time to publish, do ya?

    # Kick things off by identifying any files that we're just SICK OF
    my @FilesToRemove;
    if (-e $nixxed_fname) {
	my $inf = OpenInputFile($nixxed_fname);
	while (my $line = <$inf>) {
	    $line =~ s/\n|\r//g;
	    next if (!$line);
	    push(@FilesToRemove,$line);
	}
	close($inf);
    }

    # We'll want to guarantee that our catalogs and nav bars are up to snuff
    RunSystemCommand('./src/UpdateInternalLinks.pl');

    # Let's navigate our way over to the site directory
    chdir '../Site/';

    # If there's anything to remove, make sure that gets 'git rm'-ed
    foreach my $file_to_remove (@FilesToRemove) {
	RunSystemCommand("git rm $file_to_remove");
	RunSystemCommand("rm $file_to_remove") if (-e $file_to_remove);
    }

    # Get a list of every file, and ADD THEM ALL
    my $filelist_ref = FullDirFileExtraction('.');
    my @FileList = @{$filelist_ref};
    foreach my $fname (@FileList) {
	RunSystemCommand("git add $fname");
    }

    # We're ready to push off!
    system("git commit");
    system("git push origin main");

    # The very last thing we'll do is delete the file recording nixxed posts,
    # since they're no longer relevant!
    # (take note that we've moved into 'Site')
    if (scalar(@FilesToRemove)) {
	RunSystemCommand("rm ../postmaster/src/$nixxed_fname");
    }
    
}



#################################################################
#
#  FUNCTION: FullDirFileExtraction
#
sub FullDirFileExtraction
{
    my $dirname = shift;
    $dirname = ConfirmDirectory($dirname);

    my @FileList;

    my $dir = OpenDirectory($dirname);
    while (my $fname = readdir($dir)) {

	$fname =~ s/\/$//;
	next if ($fname =~ /^\./);
	$fname = $dirname.$fname;

	if (-d $fname) {

	    my $subdir_list_ref = FullDirFileExtraction($fname);
	    my @SubdirList = @{$subdir_list_ref};
	    foreach my $subfile (@SubdirList) {
		push(@FileList,$subfile);
	    }
	    
	} else {

	    push(@FileList,$fname);
	    
	}
	
    }
    closedir($dir);

    return \@FileList;
    
}







###############################
#                             #
#  BEUREAUCRATIC SUBROUTINES  #
#                             #
###############################



#################################################################
#
#  FUNCTION:  MIN
#
sub MIN
{
    my $a = shift;
    my $b = shift;
    return $a if ($a < $b);
    return $b;
}



#################################################################
#
#  FUNCTION:  MAX
#
sub MAX
{
    my $a = shift;
    my $b = shift;
    return $a if ($a > $b);
    return $b;
}



#################################################################
#
#  FUNCTION:  RunSystemCommand
#
sub RunSystemCommand
{
    my $command = shift;
    if (system($command)) { die "\n  ERROR:  System command '$command' failed during execution\n\n"; }
}



#################################################################
#
#  FUNCTION:  OpenSystemCommand
#
sub OpenSystemCommand
{
    my $command = shift;
    if ($command !~ /\s+\|\s*$/) { $command = $command.' |'; }
    open(my $command_output,$command) || die "\n  ERROR:  Failed to open output from system command '$command'\n\n";
    return $command_output;
}



#################################################################
#
#  FUNCTION:  OpenInputFile
#
sub OpenInputFile
{
    my $filename = shift;
    if (!(-e $filename)) { die "\n  ERROR:  Failed to locate input file '$filename'\n\n"; }
    open(my $filehandle,'<',$filename) || die "\n  ERROR:  Failed to open input file '$filename'\n\n";
    return $filehandle;
}



#################################################################
#
#  FUNCTION:  NameOutputFile
#
sub NameOutputFile
{
    my $intended_name = shift;
    my $basename;
    my $extension;
    if ($intended_name =~ /(\S+)(\.[^\.]+)$/) {
	$basename = $1;
	$extension = $2;
    } else {
	$basename = $intended_name;
	$extension = '';
    }
    my $filename = $basename.$extension;
    my $attempt = 1;
    while (-e $filename) {
	$attempt++;
	$filename = $basename.'_'.$attempt.$extension;
    }
    return $filename;
}



#################################################################
#
#  FUNCTION:  OpenOutputFile
#
sub OpenOutputFile
{
    my $filename = shift;
    $filename = NameOutputFile($filename);
    open(my $filehandle,'>',$filename) || die "\n  ERROR:  Failed to open output file '$filename'\n\n";
    return $filehandle;
}



#################################################################
#
#  FUNCTION:  OpenFileToAppendTo
#
sub OpenFileToAppendTo
{
    my $filename = shift;
    open(my $filehandle,'>>',$filename) || die "\n  ERROR:  Failed to open output file '$filename' (for appending)\n\n";
    return $filehandle;
}



#################################################################
#
#  FUNCTION:  ConfirmDirectory
#
sub ConfirmDirectory
{
    my $dirname = shift;
    if (!(-d $dirname)) { die "\n  ERROR:  Failed to locate directory '$dirname'\n\n"; }
    if ($dirname !~ /\/$/) { $dirname = $dirname.'/'; }
    return $dirname;
}



#################################################################
#
#  FUNCTION:  DeleteFile
#
sub DeleteFile
{
    my $filename;
    if (-e $filename) {
	my $rm_command = 'rm '.$filename;
	RunSystemCommand($rm_command);
    }
}



#################################################################
#
#  FUNCTION:  OpenDirectory
#
sub OpenDirectory
{
    my $dirname = shift;
    $dirname = ConfirmDirectory($dirname);
    opendir(my $dirhandle,$dirname) || die "\n  ERROR:  Failed to open directory '$dirname'\n\n";
    return $dirhandle;
}



#################################################################
#
#  FUNCTION:  NameDirectory
#
sub NameDirectory
{
    my $intended_name = shift;
    $intended_name =~ s/\/$//;
    my $dirname = $intended_name;
    my $attempt = 1;
    while (-d $dirname) {
	$attempt++;
	$dirname = $intended_name.'_'.$attempt;
    }
    $dirname = $dirname.'/';
    return $dirname;
}



#################################################################
#
#  FUNCTION:  CreateDirectory
#
sub CreateDirectory
{
    my $dirname = shift;
    $dirname = NameDirectory($dirname);
    RunSystemCommand("mkdir $dirname");
    if (!(-d $dirname)) { die "\n  ERROR:  Creation of directory '$dirname' failed\n\n"; }
    return $dirname;
}


##   END OF FILE   ##













