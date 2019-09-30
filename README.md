# parselog
A Perl Script that reads compressed (or uncompressed) log files and prints the result in a CSV file
Give it a configuration  file containing three lines:
  1) The file(s) you want to uncompress
  2) The regex you want to use to parse it
  3) The regex groups (starting from 0) you want to output in the CSV  
You can also give it more than one configuration file.
See examples in the source code comments
