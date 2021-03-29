# Create EXIF renamed image files
Copy image and video files from the source directory to the destination directory using the EXIF Date/Time to rename the files. If the destination directory is not given, the files will be created in the source directory conserving the original files.

Usage:

    perl create-exif-renamed-files.pl [OPTION] --input SOURCE_DIRECTORY [--ouput DESTINATION_DIRECTORY]
    
where option include:

    -v, --verbose	explain what is being done
    -h, --help		display this help and exit

