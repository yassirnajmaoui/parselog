# FONCTIONNEMENT DU SCRIPT
# Ce script permet de parser des fichiers de log compresses et en retirer l'information pertinente en format csv, qui sera imprimee dans la console
# CE SCRIPT RECOIT EN PARAMETRE UN (ou des) FICHIER DE CONFIGURATION QUI DECRIT COMMENT IL FONCTIONNERA
# PREMIERE LIGNE: LE(S) FICHIER(S) QUI SONT A DECOMPRESSER (le script accepte ausi les "glob" du style "/var/krb5/log/archives_logs/krb5kdc.*.gz")
# DEUXIEME LIGNE: UN REGEX PERMETTANT DE "PARSE" CHAQUE LIGNE
# TROISIEME LIGNE: UNE LIGNE DE NOMBRE QUI CORRESPOND AUX GROUPES REGEX QUI SONT A CONSERVER
# EXEMPLE DE FICHIER DE CONFIG:
# ./auth.log.gz
# ^([a-zA-Z]*\s[0-9]*\s[0-9]*:[0-9]*:[0-9]*)\s(\S*)\s(\S*\s\S*[\S*]):\s(Accepted|Authorized)\s(\S* for|to)\s([0-9a-zA-Z]*)(.*)$
# 1,4,5
# Dans ce cas-ci, lorsque la commande "perl parselog.pl ma_config.txt > output.txt" sera executee, le fichier "output.txt" contientra les groupes regex 1, 4 et 5 pour chaque ligne de log
# > cat output.txt
# ksdap1, keyboard-interactive/pam for, dbeauche
# ksdap1, keyboard-interactive/pam for, ctsi
# ksdap1, keyboard-interactive/pam for, vvichidv
# ksdap1, keyboard-interactive/pam for, crioux
# ksdap1, keyboard-interactive/pam for, ncouture
# ksdap1, keyboard-interactive/pam for, claplant
# ksdap1, to, ynajmaou
# ksdap1, keyboard-interactive/pam for, sbond
# ksdap1, keyboard-interactive/pam for, smarchan
# ksdap1, keyboard-interactive/pam for, dmaheu
# Ici, le fichier auth.log.gz a ete decompresse et place dans "/tmp/archives_logs/auth.log" A l'aide de Gunzip
# 
# On peut specifier plusieurs fichiers de config en meme temps:
# Exemple:
# > cat config_ssh.txt
# /var/adm/archives_logs/auth.*.gz
# ^([a-zA-Z]*\s[0-9]*\s[0-9]*:[0-9]*:[0-9]*)\s(\S*)\s(\S*\s\S*[\S*]):\s(Accepted|Authorized)\s(\S* for|to)\s([0-9a-zA-Z]*)(.*)$
# 5
# > cat config_krb.txt
# /var/krb5/log/archives_logs/krb5kdc.*.gz
# ^([a-zA-Z]*)\s([0-9]*)\s([0-9]{2}:[0-9]{2}:[0-9]{2})\s([a-zA-Z0-9]*)\s(\/\S*)*\[(\S*)\]\((\S*)\):\s(\S*)\s(\(.*\))\s([0-9.]*)\(([0-9]*)\):\s(\S*):\s(.*,\s){0,1}(\S*)@(\S*)\s(.*)$
# 13
# > cat config_ldap.txt
# /home/dsmast/idsslapd-dsmast/logs/archives_logs/audit.*.gz
# --bindDN:\s[a-zA-Z\-0-9]*=([a-zA-Z0-9\/.]*)
# 0
# > perl ./parselog.pl ./config_ldap.txt ./config_ssh.txt ./config_krb.txt > out.txt
# > cat out.txt
# ... Ici se trouve une liste de tous les ids qui ont été actifs selon les logs de ssh, kerberos et LDAP
#
# Finalement, si les fichiers que vous voulez parser ne sont pas compresses, commenter la ligne qui commmence par "gunzip $input => $output"
# PS: le dossier /tmp/archives_logs/ doit exister avant d'executer le script si de la decompression doit etre effectuee

use warnings;
use strict;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Data::Dumper;

sub process_log_file
{
	my $tmp_filename = shift();
	my $tmp_regex = shift();
	my @tmp_groups = split(/,/,shift());
	my $tmp_entries = shift();
	# print Dumper(\$tmp_entries);
	my $tmp_filehandle;
	open($tmp_filehandle, '<', $tmp_filename) or die $!;
	my $i = 0;
	while(my $tmp_line = <$tmp_filehandle>)
	{
		#chomp $line;
		my @tmp_match = ($tmp_line =~ /$tmp_regex/g);
		my $next_entry = "";
		if(@tmp_match)
		{
			$next_entry = '';
			foreach my $tmp_group (@tmp_groups)
			{
				if ($tmp_group eq $tmp_groups[$#tmp_groups])
				{
					$next_entry .= $tmp_match[int($tmp_group)];
				}else{
					$next_entry .= $tmp_match[int($tmp_group)] . ', ';
				}
			}
			$tmp_entries->{$next_entry}++;
		}
	}
	close($tmp_filehandle);
}
	
# READS CONFIG FILE
my @input_files = @ARGV;
#print(Dumper(@input_files));
my %parsed_data;

foreach my $input_file (@input_files)
{
	#print("Now working with file: " . $input_file . "\n");
	my $input_filehandle;
	open($input_filehandle, '<', $input_file) or die $!;
	my @input_file_lines;
	while(my $line = <$input_filehandle>){
			push(@input_file_lines, $line);
	}
	close($input_filehandle);

	# GETS WHAT FILES YOU WANT TO READ
	my @log_files = glob $input_file_lines[0];

	# GETS REGEX STRING AND MAKES IT AN ACTUAL REGEX
	my $re = $input_file_lines[1];
	chomp $re;
	$re = qr/$re/;

	# GETS WHAT GROUPS YOU WANT
	my $needed_groups = $input_file_lines[2];

	foreach my $input (@log_files)
	{
		my $output = $input;
		$output =~ s/([a-zA-Z0-9.\-_]*(\/|\\))*([a-zA-Z0-9.\-_]*)\.gz/\/tmp\/archives_logs\/$3/; #limitation: si un dossier termine par .gz, ca fonctionne pas...
		gunzip $input => $output or die "Error compressing '$input': $GunzipError\n"; # SI LES FICHIER N'A PAS A ETRE DECOMPRESSES, ENLEVER CETTE LIGNE
		#print "# Log file $input uncompressed and left: $output\n"; # for debugging purposes
		process_log_file($output, $re, $needed_groups, \%parsed_data);
	}

}

foreach my $key (keys %parsed_data)
{
	print "$key\n";
}
