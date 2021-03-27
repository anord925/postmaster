#!/usr/bin/env perl
use warnings;
use strict;
use POSIX;

#  FUNCTIONAL SUBROUTINES
#
sub WriteCatalog;
sub ExtractDateFromFname;


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


my $location = $0;
$location =~ s/UpdateCatalogs\.pl//;

my $site_dirname = ConfirmDirectory($location.'../../Site');

# Kick things off by reading in all of our posts
my $pbd = OpenInputFile($site_dirname.'posts-by-date.txt');
my @Posts;
while (my $line = <$pbd>) {
    $line =~ s/\n|\r//g;
    if ($line) {
	push(@Posts,$line);
    }
}
close($pbd);

# And now we can write our catalogs!
WriteCatalog('');
WriteCatalog('Research');
WriteCatalog('Play');


1;  ##   END OF SCRIPT   ##





############################
#                          #
#  FUNCTIONAL SUBROUTINES  #
#                          #
############################





#################################################################
#
#  FUNCTION:  WriteCatalog
#
sub WriteCatalog
{
    my $topic = shift;

    my $headerfname = $location.'../component-html/';
    if ($topic) { $headerfname = $headerfname.'subdir-catalog-header.html'; }
    else        { $headerfname = $headerfname.'home-catalog-header.html';   }
    
    my $tmpfname = 'tmp-catalog.html';    
    open(my $outf,'>',$tmpfname) || die "\n  ERROR:  Failed to open '$tmpfname'\n\n";

    # Copy our header file into our temporary file
    my $inf = OpenInputFile($headerfname);
    while (my $line = <$inf>) { print $outf "$line"; }
    close($inf);
    print $outf "\n";

    # If we're in a subdirectory, add the catalog title. Otherwise, let
    # 'em know we're laying all our cards on the table!
    print $outf '<div class="catalogTitle">'."\n";
    print $outf '<a href="catalog.html"><h2>';
    if ($topic) { print $outf "$topic";  }
    else        { print $outf 'Library'; }
    print $outf '</h2></a>'."\n";
    print $outf '</div>'."\n\n";

    # Movin' into the body!
    print $outf '<div class="catalogBody">'."\n";

    # We'll be printing out a brief (pre-written) description from a file
    # either named after our topic or 'home'
    my $descfname = $location.'../component-html/';
    if ($topic) {
	$topic = lc($topic);
	$descfname = $descfname.$topic.'-catalog-description.html';
    } else {
	$descfname = $descfname.'home-catalog-description.html';
    }

    $inf = OpenInputFile($descfname);
    while (my $line = <$inf>) { print $outf "$line"; }
    close($inf);
    print $outf "\n";

    # Wow, I really thought this would be harder!  Next stop, filling in
    # the actual catalog -- hopefully not too gnarly?
    for (my $i=0; $i<scalar(@Posts); $i++) {

	my $post = $Posts[$i];

	# Our post consists of three parts: the filename, the title,
	# and the first picture in the file (if there is one), like:
	$post =~ /^(\S+)\s+\<([^\>]+)\>\s+(\S+)/;
	my $post_fname = $1;
	my $post_title = $2;
	my $post_pic   = $3;

	$post_fname =~ /^([^\/]+)\//;
	my $post_cat = $1;

	if ($topic) {
	    next if ($post_cat ne $topic);
	    $post_fname =~ s/^$post_cat\///;
	}

	# Extract the date from the post and convert it to a string
	my $date = ExtractDateFromFname($post_fname);

	print $outf '<div class="catalogEntry">'."\n";
	print $outf '<a href="'.$post_fname.'"><img class="catalogEntryImg"';
	if ($topic) { print $outf ' src="../'; }
	else        { print $outf ' src="';    }
	print $outf 'images/'.$post_pic.'"></a>'."\n";
	print $outf '<div class="catalogEntryTitle">'."\n";
	print $outf '<a href="'.$post_fname.'">'.$post_title.'</a>'."\n";
	print $outf '</div>'."\n";
	print $outf '<p class="catalogEntryDate">'.$date.'</p>'."\n";
	print $outf '</div>'."\n\n";
	
    }

    # Closing out 'div class catalogBody'
    print $outf '</div>'."\n\n";

    # If we toss this in here, we can totally prank 'UpdateNavBar.pl'!
    print $outf '<div class="rightNav">'."\n";
    print $outf '</div>'."\n\n";

    # Badda-bing badda-boom!
    my $cr_inf = OpenInputFile($location.'../component-html/copyright.html');
    while (my $line = <$cr_inf>) { print $outf "$line"; }
    close($cr_inf);

    close($outf);

    # JEEPERS!  Now all we need to do is copy our temporary file's contents
    # over into the site!
    my $target_fname = $site_dirname;
    if ($topic) {
	$target_fname = ConfirmDirectory($target_fname.$topic.'/');
    }
    $target_fname = $target_fname.'catalog.html';

    RunSystemCommand("mv $tmpfname $target_fname");
    
}








#################################################################
#
#  FUNCTION:  ExtractDateFromFname
#
sub ExtractDateFromFname
{
    my $fname = shift;

    $fname =~ /(\d+)\-(\d+)\-(\d+)/;
    my $year  = $1;
    my $month = $2;
    my $day   = $3;
    
    my @Months = qw( January February March April May June July August September October November December );

    if ($day == 1 || $day == 21 || $day == 31) {
        $day = $day.'st';
    } elsif ($day == 2 || $day == 22) {
        $day = $day.'nd';
    } elsif ($day == 3 || $day == 23) {
        $day = $day.'rd';
    } else {
        $day = $day.'th';
    }

    return $year.', '.$Months[$month-1].' '.$day;

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













