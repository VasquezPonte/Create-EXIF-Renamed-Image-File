#!/usr/bin/perl -w
#============================================================================== #
# Program:      Create EXIF renamed files                                       #
# Description:  Create renamed copy of image files given the EXIF Date/Time     #
# Version:      1.0                                                             #
# File:         create-exif-renamed-files.pl                                    #
# Author:       Vásquez Ponte, 2019 (https://vasquezponte.com)                  #
#============================================================================== #

use strict;
use warnings;
use Getopt::Long qw(GetOptions);

#
# Constants
#
use constant SCRIPT_NAME        => 'create-exif-renamed-files.pl';
use constant EXIFTOOL           => '/usr/bin/exiftool';

#
# Variables
#
my $help = '';
my $verbose = '';
my $source_path = '';
my $destination_path = '';


# ============================================================================= #
# ===============================   MAIN   ==================================== #
# ============================================================================= #

GetOptions(
    'input|i=s' => \$source_path,
    'output|o=s' => \$destination_path,
    'verbose|v' => \$verbose,
    'help|h' => \$help
) or die "Usage: $0 [OPTION] --input SOURCE_DIRECTORY [--ouput DESTINATION_DIRECTORY]\n";

if ($source_path eq '' || $help) {
    print 'Copy image files from the SOURCE_DIRECTORY to the DESTINATION_DIRECTORY using the EXIF Date/Time to rename the files. '.
        'If the DESTINATION_DIRECTORY is not given, the files will be created in the SOURCE_DIRECTORY conserving the original files.' . "\n\n".
        'Usage: '. SCRIPT_NAME .' [OPTION] --input SOURCE_DIRECTORY' . "\n".
	    '  or   '. SCRIPT_NAME .' [OPTION] --input SOURCE_DIRECTORY [--ouput DESTINATION_DIRECTORY]'. "\n\n".
        'Options:'. "\n".
        ' -v, --verbose'. "\t\t". 'explain what is being done'. "\n".
        ' -h, --help'. "\t\t". 'display this help and exit'. "\n\n".
        'Examples:'. "\n".
        ' Create renamed image files in the same source folder.' . "\n" . 
        "\t" . SCRIPT_NAME . ' -i /path/to/source/folder' . "\n\n".
        ' Create renamed image files in the destination folder.' . "\n" . 
        "\t" . SCRIPT_NAME . ' -i /path/to/source/folder -o /path/to/destination/folder' .   "\n";
    print "\n";
        exit 0;
}

print "\n===\n= Start: ". (localtime) ."\n===\n\n" if $verbose;

print 'Checking source folder "'. $source_path .'"' ."\n" if $verbose;
check_folder(\$source_path);

if ($destination_path ne '') {
    print 'Checking destination folder "'. $destination_path .'"' ."\n" if $verbose;
    check_folder(\$destination_path);
}

# Recursively process all image files in the directory
print 'Processing files in source folder "'. $source_path .'"' ."\n\n" if $verbose;
process_files($source_path);

print "===\n= End: ". (localtime) ."\n===\n\n" if $verbose;


# ============================================================================= #
# ===========================  Subroutines  =================================== #
# ============================================================================= #

#
# sub process_files ( string )
#
# Accepts one argument: the full path to a directory.
# https://www.perlmonks.org/?node_id=136482
#
sub process_files {
    my $path = shift;

    opendir (DIR, $path)
        or die "Unable to open $path: $!";
    my @files = grep { !/^\.{1,2}$/ } readdir (DIR);
    closedir (DIR);

    @files = map { $path . '/' . $_ } @files;
    for (@files) {
        if (-d $_) {
            process_files ($_);
        } else {
            if ( (! -l $_) && (grep /\.(?:png|gif|jpg|jpeg)$/i, $_) ) {
                create_renamed_copy($_);
            }
        }
    }
}

#
# sub create_renamed_copy ( string )
#
# Create a renamed copy of the image file using the EXIF data
#
sub create_renamed_copy {
    use Image::ExifTool qw(ImageInfo);

    my $file = shift;
    my $exif_date_time = '';

    my $info = ImageInfo($file, 'CreateDate', 'DateTimeOriginal', 'FileModifyDate');
    if (keys %{ $info}) {
        print 'Reading EXIF information from image file "'. $_ .'"' . "\n" if $verbose;
        if (exists $info->{CreateDate}) {
            print 'CreateDate: ' . $info->{CreateDate} ."\n" if $verbose;
            $exif_date_time = $info->{CreateDate};
        } elsif (exists $info->{DateTimeOriginal}) {
            print 'DateTimeOriginal: ' . $info->{DateTimeOriginal} ."\n" if $verbose;
            $exif_date_time = $info->{DateTimeOriginal};
        } else {
            print 'No Date/Time information in EXIF data in file "'. $_ .'"' . "\n";
        }
    } else {
        print 'No EXIF data in file "'. $_ .'"' . "\n";
    }

    # Create file
    if ($exif_date_time ne '') {
        create_file($_, $exif_date_time);
    }
    print "\n" if $verbose;
}

#
# sub create_file ( string, string )
#
# Accepts two arguments:
#   - The full path of the original file
#   - Date/Time information from EXIF data
#   
sub create_file {
	use File::Copy qw(copy);
	
	my ($file, $datetime) = @_;	
	my ($newfile);
	
	$newfile = generate_full_path($file, $datetime);
	print 'Generated full path: "'. $newfile .'"' ."\n" if $verbose;

    if (! -e $newfile) {
        print "Creating file: '$newfile'\n" if $verbose;
        copy($file, $newfile) or die "Copy failed: $!\n";
    }
}

#
# sub generate_full_path ( string, string )
#
# Accepts two arguments:
#   - The full path of the original file
#   - Date/Time information from EXIF data
# Returns a full path for copying the original file 
#
sub generate_full_path {
    use File::Basename;
    use Digest::MD5 qw(md5_hex);
    use File::Path qw(make_path);
    
    my ($file, $datetime) = @_;    
    my ($name, $path, $suffix);
    my ($date, $time);
    my ($newpath, $newname, $newfile);
    my ($subpath, $digest);
    my ($err);
        
    ($date, $time) = split(' ', $datetime);
    $date =~ tr/:/-/;
    $time =~ tr/://d;
    # ISO 8601
    $newname = $date . 'T' . $time;

    # fileparse("/foo/bar/baz.jpg", ".jpg") returns  ("baz", "/foo/bar/", ".jpg")
    ($name, $path, $suffix) = fileparse($file, qr/\.[^.]*/);    
    if ($destination_path ne '') {
    	$subpath = substr($path, length($source_path));
        $newpath = $destination_path . $subpath;
        unless(-e $newpath) {
        	make_path($newpath, {error => \$err});
            die 'Unable to create "' . $newpath .'"' ."\n\n" if ($err && @$err);
        }
    } else {
        $newpath = $path;
    }
    
    $newfile = $newpath . $newname . lc $suffix;
    if (-e $newfile) {
        $digest = md5_hex($name . $suffix);
        $newfile = $newpath . $newname .'_'. $digest . lc $suffix;
    }

    return $newfile;
}

#
# sub check_folder ( string )
#
# Accepts one argument: the full path to a directory.
#
sub check_folder {
    use File::Temp qw/ tempfile tempdir /;
    use Try::Tiny;
	
    my $path_ref = shift;
    
    if ((! -e $$path_ref) || (! -d $$path_ref)) {
        die 'Error: "'. $$path_ref .'" does not exist or is not a directory.'. "\n\n";
    }

    # Remove trailing slash, except for the root directory
    $$path_ref =~ s{(.+)/\z}{$1};
    
    try {
        my ($fh, $filename) = tempfile(DIR => $$path_ref, SUFFIX => '.tmp', UNLINK => 1);
        print "\n" if $verbose;
    } catch {
        die 'Error: Directory "'. $$path_ref .'" is not writable.'. "\n\n";
    }
}
