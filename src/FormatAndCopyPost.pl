#!/usr/bin/env perl
use warnings;
use strict;
use POSIX;
use File::Spec;

#  FUNCTIONAL SUBROUTINES
#
sub GetDate;


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

my $max_img_width = 600.0;

if (@ARGV != 1) { die "\n  USAGE: ./FormatAndCopyPost.pl [rippable-file]\n\n"; }

my $location = $0;
$location =~ s/FormatAndCopyPost\.pl//;

# Make sure that we're in a position where we can safely navigate to our
# files 'n' stuff.
my $site_dirname = ConfirmDirectory($location.'../../Site/');

# In case we encounter any images, we'll want to know the precise location of
# our rippable file.
my $rip_loc = File::Spec->rel2abs($ARGV[0]);
$rip_loc =~ s/\/[^\/]+$/\//;

# Open up the file and do our initial reading!
my $RipFile = OpenInputFile($ARGV[0]);

my $title = <$RipFile>;
$title =~ s/^\s+//;
$title =~ s/\s+$//;

# Handle any asterisks in the title stupidly
while ($title =~ /\*[^\*]+\*/) {
    $title =~ s/\*/\<em\>/;
    $title =~ s/\*/\<\/em\>/;
}

my $category = lc(<$RipFile>);
$category =~ s/\s//g;
if ($category ne 'research' && $category ne 'play') {
    die "\n  ERROR:  Category must be either 'research' or 'play'\n\n";
}

my @Paragraphs;
my $current_paragraph = '';
while (my $line = <$RipFile>) {
    $line =~ s/\n|\r//g;
    if (!$line) {
	if ($current_paragraph) {

	    # Clear out any unnecessary whitespace
	    $current_paragraph =~ s/^\s+//;
	    $current_paragraph =~ s/\s+$//;
	    while ($current_paragraph =~ /  /) {
		$current_paragraph =~ s/  / /g;
	    }
	    
	    push(@Paragraphs,$current_paragraph);
	    $current_paragraph = '';

	}
	next;
    }
    $current_paragraph = $current_paragraph.$line.' ';
}
push(@Paragraphs,$current_paragraph) if ($current_paragraph);
close($RipFile);

my $num_paragraphs = scalar(@Paragraphs);

# Sanity check
if ($num_paragraphs == 0) {
    die "\n  ERROR:  File '$ARGV[0]' appears empty...\n\n";
}


# Now we'll go paragraph-by-paragraph splitting 'em into sentences
# and checking those sentences for paired asterisks, indicating
# text that needs to be italicized (obv.s, skipping any GD images).
my $first_img = 0;
for (my $paragraph_id=0; $paragraph_id<$num_paragraphs; $paragraph_id++) {

    my $paragraph = $Paragraphs[$paragraph_id];

    if ($paragraph !~ /^\</ || $paragraph =~ /^\<a/) {

	# Break it into sentences and look for paired asterisks.
	# We have to do this in an obnoxiously careful way.
	my @Sentences;
	my $in_link = 0;
	my $next_sentence = '';
	my @ParagraphChars = split(//,$paragraph);
	for (my $char_id=0; $char_id<scalar(@ParagraphChars); $char_id++) {

	    my $char = $ParagraphChars[$char_id];

	    my $end_of_sentence = 0;
	    if (!$in_link) {
		if ($char eq '!' || $char eq '?' || $char eq '.') {
		    $end_of_sentence = 1;
		}
		if ($char eq '.' && $char_id>0 && $char_id+1<scalar(@ParagraphChars)
		    && $ParagraphChars[$char_id-1] =~ /\d/
		    && $ParagraphChars[$char_id+1] =~ /\d/) {
		    $end_of_sentence = 0;
		}
	    }

	    if ($char eq '<') {
		$in_link = 1;
	    } elsif ($char eq '>') {
		$in_link = 0;
	    }


	    $next_sentence = $next_sentence.$char;
	    if ($end_of_sentence) {
		push(@Sentences,$next_sentence);
		$next_sentence = '';
	    }

	}

	$paragraph = '';
	my $num_sentences = scalar(@Sentences);
	for (my $sentence_id=0; $sentence_id<$num_sentences; $sentence_id++) {

	    my $sentence = $Sentences[$sentence_id];
	    $sentence =~ s/^\s+//;
	    $sentence =~ s/\s+$//;

	    # To avoid throwing off regexes, we need to literal-ify parens
	    $sentence =~ s/\(/\\\(/g;
	    $sentence =~ s/\)/\\\)/g;

	    if ($sentence =~ /\*/) {

		# Identify and remove terminal punctuation
		my $end_punctuation = '';
		if ($sentence =~ /([^\*A-Za-z\(\)\\]+)$/) {
		    $end_punctuation = $1;
		    $sentence =~ s/$end_punctuation$//;
		}
		
		# ASTERISK ALERT! ASTERISK ALERT!
		my @Fragments = split(/\*/,$sentence);
		my $num_fragments = scalar(@Fragments);


		# If there's only one asterisk, this was a false-flag operation!
		if ($sentence =~ /^\*/ && $sentence =~ /\*$/) {
		    
		    $sentence =~ s/\*//g;
		    $sentence = '<em>'.$sentence.'</em>';
		    
		} else {

		    my $emp_sentence = '';
		    my $is_emp = 0;
		    if ($sentence =~ /^\*/) {
			$emp_sentence = '<em>';
			$is_emp = 1;
		    }

		    my $fragment_id = 0;
		    while ($fragment_id < $num_fragments) {
			if ($is_emp) {
			    $emp_sentence = $emp_sentence.$Fragments[$fragment_id].'</em>';
			    $is_emp = 0;
			} elsif ($sentence =~ /\*$/ && $fragment_id == $num_fragments-1) {
			    # Special case of a terminal emphasis
			    $emp_sentence = $emp_sentence.'<em>'.$Fragments[$fragment_id].'</em>';
			} elsif ($fragment_id < $num_fragments-1)  {
			    $emp_sentence = $emp_sentence.$Fragments[$fragment_id].'<em>';
			    $is_emp = 1;
			} else {
			    $emp_sentence = $emp_sentence.$Fragments[$fragment_id].'*';
			}
			$fragment_id++;
		    }

		    $sentence = $emp_sentence;
		    
		}

		# Don't forget your punctuation!
		$sentence = $sentence.$end_punctuation;

	    }
	    
	    unless ($sentence_id+1 == $num_sentences && !$sentence) {
		$paragraph = $paragraph.$sentence;
		$paragraph = $paragraph.' ' if ($sentence_id+1 < $num_sentences);
	    }
	    
	}

    } elsif ($paragraph =~ /\<img/) {

	$paragraph =~ /\s([^\>]+)\>/;
	my $local_img_location = $1;

	# We'll want to convert the local image location to an absolute location
	my $abs_img_location = $local_img_location;
	if ($local_img_location =~ /^\~/) {
	    $abs_img_location =~ s/^\~\///;
	    $abs_img_location = '/Users/alexandernord/'.$abs_img_location;
	} elsif ($local_img_location !~ /^\//) {
	    $abs_img_location = $rip_loc.$local_img_location;
	}

	# Does this file actually exist?
	if (!(-e $abs_img_location)) {
	    die "\n  ERROR:  Failed to location image '$abs_img_location' ('$local_img_location' in file)\n\n";
	}
	
	$abs_img_location =~ /\/([^\/]+)$/;
	my $raw_img_name = $1;

	# Refer to heirarchy
	my $target_img_location = $location.'../../Site/images/'.$raw_img_name;
	if (!(-e $target_img_location)) {
	    RunSystemCommand("cp $abs_img_location $target_img_location");
	} else {
	    print "\n  WARNING: Image '$target_img_location' already exists.  File not copied.\n\n";
	}

	# Before we go any further, be sure to note the image's name
	# if this is the first image in the file
	$first_img = $raw_img_name if (!$first_img);
	
	# Get the pixel size to determine whether we need to resize
	# (based on width)
	my $SipsIn = OpenSystemCommand('sips -g pixelHeight -g pixelWidth '.$abs_img_location);
	my $conf_line   = <$SipsIn>;
	my $height_line = <$SipsIn>;
	my $width_line  = <$SipsIn>;
	close($SipsIn);

	# If we don't have good height, then something fucked up
	if ($width_line !~ /pixelWidth/) {
	    die "\n  ERROR:  sips failed to process image file $abs_img_location\n\n";
	}

	$height_line =~ /pixelHeight\: (\d+)/;
	my $img_height = $1;
	$width_line  =~ /pixelWidth\: (\d+)/;
	my $img_width = $1;

	# We don't like images wider than 500px
	my $style_str = 'class="articlePic"';
	if ($img_width > $max_img_width) {
	    
	    my $resize_scale = $max_img_width/($img_width+0.0);
	    my $resize_height = int((0.0+$img_height)*$resize_scale);
	    $style_str = $style_str.' style="width:'.$max_img_width.'px;height:'.$resize_height.'px;"';

	}

	# And now you're html!
	$raw_img_name = '../images/'.$raw_img_name;
	$paragraph = '<a href="'.$raw_img_name.'"><img '.$style_str.' src="'.$raw_img_name.'"></a>';

    } else {

	print "\n  WARNING: Unrecognized html-like line '$paragraph' ignored\n\n";
	
    }

    # Now that we're past the regex-ing for this paragraph, we'll need to
    # go from \( back to (
    $paragraph =~ s/\\\(/\(/g;
    $paragraph =~ s/\\\)/\)/g;
    $Paragraphs[$paragraph_id] = $paragraph;

}

# We DEMAND titles 'n' categories 'round these parts
die "\n  ERROR: Category required!\n\n" if (!$category);
die "\n  ERROR: Title required!\n\n" if (!$title);

# If there aren't any images in this article, use the category default
$first_img = $category.'-default.jpg' if (!$first_img);

# Get a hold of the directory we'll be writing to
my $target_dirname = ConfirmDirectory($site_dirname.$category);


# Alrighty, seems like we're formatted 'n' whatver, but if we're going to
# publish this bad boy, then we're going to have to update our list of
# most recent posts.


# ... but first, random question, what's the date today?
my ($year,$month,$day,$date_str) = GetDate();
$month = '0'.$month if ($month<10);
$day = '0'.$day if ($day<10);

# Haha! It wasn't a random question!  Now I'm going to name the html file
# according to this date!  Fooled ya!
my $outfname = NameOutputFile($target_dirname.$year.'-'.$month.'-'.$day.'.html');

# Time to write our post out to a file!
my $outf = OpenOutputFile($outfname);


# First off, we'll need to copy over the content to announce the
# style and fonts (and draw my sweet logo!).
my $head_inf = OpenInputFile($location.'../component-html/article-header.html');
while (my $line = <$head_inf>) { print $outf "$line"; }
close($head_inf);

# Write in the catalog category (with just the first character
# capitalized, for prettiness).
$category =~ /^(\S)/;
my $cat_first_char = uc($1);
my $formatted_cat = $category;
$formatted_cat =~ s/^\S/$cat_first_char/;

print $outf '<div class="catalogTitle">'."\n";
print $outf '<a href="index.html"><h2>'.$formatted_cat.'</h2></a>'."\n";
print $outf '</div>'."\n";

# Write in the title for this article
print $outf '<div class="articleTitle">'."\n";
print $outf '<h2>'.$title.'</h2>'."\n";
print $outf '<p class="articleDate">'.$date_str.'</p>'."\n";
print $outf '</div>'."\n\n";


# Now for the article itself!  The only real trick here is keeping an eye out
# for embedded images.
print $outf '<div class="articleContent"><br>'."\n";
for (my $paragraph_id=0; $paragraph_id<$num_paragraphs; $paragraph_id++) {
    if ($Paragraphs[$paragraph_id] =~ /^\<img/) {
	print $outf "$Paragraphs[$paragraph_id]\n";
    } else {
	print $outf '<p>'."$Paragraphs[$paragraph_id]".'</p>'."\n";
    }
}
print $outf '</div>'."\n\n";

# Awesome!  The biggest thing missing is the nav-bar, but we have *special*
# means of accomplishing that goal (i.e., UpdateNavBars.pl), so for now we'll
# just write in the necessary code for UpdateNavBars to know where to do its
# dark deeds.
print $outf '<div class="rightNav">'."\n";
print $outf '</div>'."\n\n";

# SWAG! Now to add the copyright and close up our html file
my $cr_inf = OpenInputFile($location.'../component-html/copyright.html');
while (my $line = <$cr_inf>) { print $outf "$line"; }
close($cr_inf);

# That's all the html!
close($outf);

# In case we posted multiple times today, the file name could be a bit
# different from what we requested, so now let's grab it to be sure
$outfname =~ /\/([^\/]+)$/;
my $local_outfname = $1;

# Update the 'posts-by-date.txt' file, assuming we have one
my $tmp_outfname = NameOutputFile($target_dirname.'tmp.txt');

my $tmp_outf = OpenOutputFile($tmp_outfname);
print $tmp_outf "$category\/$local_outfname \<$title\> $first_img\n";

my $pbd_fname  = $site_dirname.'posts-by-date.txt';
if (-e ($pbd_fname)) {
    my $pbd_inf = OpenInputFile($pbd_fname);
    while (my $line = <$pbd_inf>) {
	$line =~ s/\n|\r//g;
	next if (!$line);
	print $tmp_outf "$line\n";
    }
    close($pbd_inf);
}

close($tmp_outf);

RunSystemCommand("mv $tmp_outfname $pbd_fname");


1;  ##   END OF SCRIPT   ##





############################
#                          #
#  FUNCTIONAL SUBROUTINES  #
#                          #
############################





#################################################################
#
#  FUNCTION:  GetDate
#
sub GetDate
{
    # https://www.tutorialspoint.com/perl/perl_date_time.htm
    my @Months = qw( January February March April May June July August September October November December );
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

    $year += 1900; # WTF, perl?!

    my $month_str = $Months[$mon];
    my $month_num = $mon+1;

    my $day_num = $mday;
    my $day_str;
    if ($day_num == 1 || $day_num == 21 || $day_num == 31) {
	$day_str = $day_num.'st';
    } elsif ($day_num == 2 || $day_num == 22) {
	$day_str = $day_num.'nd';
    } elsif ($day_num == 3 || $day_num == 23) {
	$day_str = $day_num.'rd';
    } else {
	$day_str = $day_num.'th';
    }

    my $date_str = $year.', '.$month_str.' '.$day_str;
    return($year,$month_num,$day_num,$date_str);
    
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













