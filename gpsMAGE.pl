#!/usr/bin/perl

# $Id$
# $Revision$
# $Date$

use strict;
use warnings;
use vars qw/ $VERSION /;

$VERSION = '0.01';

#    gpsMAGE converts various types of input into GPX Route files
#

#    Example: 
#              gpsMAGE.pl examples\tfl_map.txt

use Getopt::Long;
use File::Basename;
use File::Spec;
use Cwd;
use Time::HiRes 'time','sleep';
use File::Slurp;

local $| = 1; # don't buffer output to STDOUT

my $har_file_content;
my ( $opt_version, $opt_help );
my ( $sourcefile_full, $sourcefile_name, $sourcefile_path );
my $route;
my %gps_formats = ( name => {
                               description => 'description of gps format',
                               pattern => 'regex to match the gps format',
                              }
                  );

get_options();

my $sourcefile_content = read_file($sourcefile_full);

my $chosen_format = detect_gps_format();
print "\nSource GPS Format : $chosen_format\n\n";

output_gpx_route($chosen_format);

#------------------------------------------------------------------
sub output_gpx_route {
    my ($_chosen_format) = @_;


    my $_regex = $gps_formats{$_chosen_format}->{pattern};

    my $_position_number = 1;
    my ($_startLat, $_startLon, $_endLat, $_endLon);

    my ($_saveLat, $_saveLon, $_save_end_Lat, $_save_end_Lon);
    my $_file_number = 1;
    while ( $sourcefile_content =~ m{$_regex}ig ) {
        ($_startLat, $_startLon, $_endLat, $_endLon) = ($1, $2, $3, $4);
        if (defined $_saveLat) {
            if ( ($_saveLat == $_startLat) && ($_saveLon == $_startLon) ) {
                # alternative route found, output current route and process the next
                if (defined $_save_end_Lat) {
                    $route .= _output_position($_save_end_Lat, $_save_end_Lon, "Final Position $_position_number");
                }
                _write_gpx_file($_file_number, $_chosen_format);
                $_file_number++;
                $route = '';
                undef $_saveLat;
                undef $_saveLon;
                undef $_save_end_Lat;
                undef $_save_end_Lon;
                $_position_number = 1;
            }
        }
        if (not defined $_saveLat) {
            $_saveLat = $_startLat;
            $_saveLon = $_startLon;
        }
        $_save_end_Lat = $_endLat;
        $_save_end_Lon = $_endLon;
        $route .= _output_position($_startLat, $_startLon, "Position $_position_number");
        $_position_number++;
    }

    # deal with the final file
    if (defined $_endLat) {
        $route .= _output_position($_endLat, $_endLon, "Final Position $_position_number");
    }
    _write_gpx_file($_file_number, $_chosen_format);

    return;
}

sub _write_gpx_file {
    my ($_file_number, $_chosen_format) = @_;

    my $_output_file = "$sourcefile_name"."_$_file_number".'_mage.gpx';

    print {*STDOUT} "Writing file $_file_number : $_output_file\n";

    open my $_GPX_ROUTE, '>' ,"$_output_file" or die "\nERROR: Failed to open $_output_file for writing\n\n";
    print {$_GPX_ROUTE} _output_header($_file_number, $_chosen_format);
    print {$_GPX_ROUTE} $route;
    print {$_GPX_ROUTE} _output_footer();
    close $_GPX_ROUTE or die "\nERROR: Failed to close $_output_file\n\n";

    return;
}

sub _output_position {
    my ($_lat, $_lon, $_position_name) = @_;

    my $_position_xml;

    $_position_xml .= qq|        <rtept lat="$_lat" lon="$_lon">\n|;
    $_position_xml .= qq|            <ele>0.0</ele>\n|;
    $_position_xml .= qq|            <name>$_position_name</name>\n|;
    $_position_xml .= qq|        </rtept>\n|;

    return $_position_xml;
}

sub _output_header {
    my ($_file_number, $_chosen_format) = @_;

    my $_header_xml;

    $_header_xml .= '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'."\n";
    $_header_xml .= '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="gpsMAGE">'."\n";
    $_header_xml .= '    <metadata>'."\n";
    $_header_xml .= '        <name>Created using '.$_chosen_format." template with gpsMAGE </name>\n";
    $_header_xml .= '    </metadata>'."\n";
    $_header_xml .= '    <rte>'."\n";
    $_header_xml .= '        <name>'.$sourcefile_name." Route $_file_number</name>\n";

    return $_header_xml;
}

sub _output_footer {

    my $_footer_xml;

    $_footer_xml .= '    </rte>'."\n";
    $_footer_xml .= '</gpx>'."\n";

    return $_footer_xml;
}


#------------------------------------------------------------------
sub detect_gps_format {

    $gps_formats{ TFLMap } = {
                                 description => 'Transport for London Map Data',
                                 pattern => '"startLat":(-?\d+\.\d+),"startLon":(-?\d+\.\d+),"endLat":(-?\d+\.\d+),"endLon":(-?\d+\.\d+)',
                             };

    foreach my $_gps_format_name ( sort keys %gps_formats ) {
        my $test = $gps_formats{$_gps_format_name}->{pattern};
        if ( $sourcefile_content =~ m{$test}i ) {
            return $_gps_format_name;
        }
    }

    return;
}


#------------------------------------------------------------------
sub get_options {

    Getopt::Long::Configure('bundling');
    GetOptions(
        'v|V|version'               => \$opt_version,
        'h|help'                    => \$opt_help,
        )
        or do {
            print_usage();
            exit;
        };
    if ($opt_version) {
        print_version();
        exit;
    }

    if ($opt_help) {
        print_version();
        print_usage();
        exit;
    }

    # read the testfile name, and ensure it exists
    if (($#ARGV + 1) < 1) {
        print "\nERROR: No source file name specified at command line\n";
        print_usage();
        exit;
    } else {
        $sourcefile_full = $ARGV[0];
    }
    ($sourcefile_name, $sourcefile_path) = fileparse($sourcefile_full, ('.xml', '.txt'));

    if (not -e $sourcefile_full) {
        die "\n\nERROR: no such test file found $sourcefile_full\n";
    }

    return;
}

sub print_version {
    print "\ngpsMAGE version $VERSION\nFor more info: https://github.com/Qarj/gpsMAGE\n\n";
    return;
}

sub print_usage {
    print <<'EOB'

Usage: gpsMAGE.pl sourcefile.txt <<options>>

wif.pl -v|--version
wif.pl -h|--help
EOB
;
return;
}
#------------------------------------------------------------------
