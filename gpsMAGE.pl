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
#              gpsMAGE.pl examples\tfl_directions.txt
#              gpsMAGE.pl examples\tfl_webinject.txt


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
my ($d1, $d2, $d3, $d4, $d5, $d6);


get_options();

my $sourcefile_content = read_file($sourcefile_full);

my $chosen_format;

detect_and_process_gps_format();

if (not defined $chosen_format) {
    die "\nFormat of input not detected\n";
}

#------------------------------------------------------------------
sub output_gpx_route {
    my ($_chosen_format) = @_;


    my $_regex = $gps_formats{$_chosen_format}->{pattern};
    my $_start_lat_ref = $gps_formats{$_chosen_format}->{start_lat_ref};
    my $_start_lon_ref = $gps_formats{$_chosen_format}->{start_lon_ref};
    my $_wpt_name_ref = $gps_formats{$_chosen_format}->{wpt_name_ref};
    my $_wpt_supp_ref = $gps_formats{$_chosen_format}->{wpt_supp_ref};
    my $_end_lat_ref = $gps_formats{$_chosen_format}->{end_lat_ref};
    my $_end_lon_ref = $gps_formats{$_chosen_format}->{end_lon_ref};

    my $_position_number = 1;

    my ($_saveLat, $_saveLon, $_save_end_Lat, $_save_end_Lon);
    my $_file_number = 1;
    while ( $sourcefile_content =~ m{$_regex}isg ) {
        ($d1, $d2, $d3, $d4, $d5, $d6) = ($1, $2, $3, $4, $5, $6);
        #print "d1:d2|$d1:$d2\n";
        if (defined $_saveLat) {
            if ( ($_saveLat == _value($_start_lat_ref) ) && ($_saveLon == _value($_start_lon_ref) ) ) {
                # alternative route found, output current route and process the next
                if (defined $_save_end_Lat) {
                    $route .= _output_position($_save_end_Lat, $_save_end_Lon, "Final Pos $_position_number");
                }
                _write_gpx_file($_file_number, $_chosen_format);
                $_file_number++;
                undef $route;
                undef $_saveLat;
                undef $_saveLon;
                undef $_save_end_Lat;
                undef $_save_end_Lon;
                $_position_number = 1;
            }
        }
        if (not defined $_saveLat) {
            $_saveLat = _value($_start_lat_ref);
            $_saveLon = _value($_start_lon_ref);
        }
        $_save_end_Lat = _value($_end_lat_ref);
        $_save_end_Lon = _value($_end_lon_ref);
        $route .= _output_position(_value($_start_lat_ref), _value($_start_lon_ref), _name($_position_number, _value($_wpt_name_ref), _value($_wpt_supp_ref)) );
        $_position_number++;
    }

    # deal with the final file
    if (defined $_end_lat_ref) {
        $route .= _output_position(_value($_end_lat_ref), _value($_end_lon_ref), "Final Pos $_position_number");
    }
    _write_gpx_file($_file_number, $_chosen_format);

    return;
}

#------------------------------------------------------------------
sub _value {
    my ($_loc) = @_;

    if (not defined $_loc) {
        return;
    }

    my $_result;
    my $_assign = '$_result = $'."$_loc".';';
    #print "_assign:$_assign\n";
    eval { eval  "$_assign";  };
    #print "_result:$_result\n";
    return $_result;
}

#------------------------------------------------------------------
sub _name {
    my ($_position_number, $_wpt_name, $_wpt_supp) = @_;
    my $_name;
    my $_cmt;

    my $_wpt_desc = '';
    if (defined $_wpt_name) {
        $_wpt_desc .= $_wpt_name;
    }

    if (defined $_wpt_supp) {
        $_wpt_desc .= ':'.$_wpt_supp;
    }

    # GPSMAP 60CSx only allows 14 characters in the name
    # GPSMAP 60CSx only allows 250 waypoints per route
    # GPSMAP 60CSx only allows 50 routes in the device
    # http://advrider.com/index.php?threads/how-do-you-follow-the-tracks-you-load-to-garmin-gps.459508/

    $_name = $_position_number.':';

    if ( $_wpt_desc =~ m/left|right/i ) {
        if ( $_wpt_desc =~ m/(left)/i ) {
            $_name .= 'L';
            $_cmt .= 'Left';
        }
    
        if ( $_wpt_desc =~ m/(right)/i ) {
            $_name .= 'R';
            $_cmt .= 'Right';
        }
    } elsif ( $_wpt_desc =~ m/(continue)/i ) {
        $_name .= 'C';
        $_cmt .= 'Cont';
    }

    if ( $_wpt_desc =~ m/([\w]+) (road|walk|street|grove|mall|avenue|terrace|roundabout|crescent|yard|lane|vale|gardens|bridge|village)/i ) {
        $_name .= ' '.$1;
        $_cmt .= ' '.$1.' '.$2;
    } elsif ( $_wpt_desc =~ m/on to ([\w]+ [\w]*)/i) {
        $_name .= ' '.$1;
        $_cmt .= ' '.$1;
    }
    
    if ( $_wpt_desc =~ m/\b([\d]+)m\b/ ) {
        my $_distance = ' '.$1.'m';
        if (length $_name.$_distance < 15) {
            $_name = $_name.$_distance;
        }
        $_cmt = $_cmt.$_distance;
    }        

    return $_name, $_cmt;
}

#------------------------------------------------------------------
sub _write_gpx_file {
    my ($_file_number, $_chosen_format) = @_;

    if (not defined $route) {
        print {*STDOUT} "\nNothing to write\n\n";
        return;
    }

    my $_output_file = "$sourcefile_name"."_$_file_number"."_$_chosen_format.gpx";

    print {*STDOUT} "Writing file $_file_number : $_output_file\n";

    open my $_GPX_ROUTE, '>' ,"$_output_file" or die "\nERROR: Failed to open $_output_file for writing\n\n";
    print {$_GPX_ROUTE} _output_header($_file_number, $_chosen_format);
    print {$_GPX_ROUTE} $route;
    print {$_GPX_ROUTE} _output_footer();
    close $_GPX_ROUTE or die "\nERROR: Failed to close $_output_file\n\n";

    return;
}

#------------------------------------------------------------------
sub _output_position {
    my ($_lat, $_lon, $_position_name, $_cmt) = @_;

    if (not $_cmt) {
        $_cmt = $_position_name;
    }

    my $_position_xml;

    $_position_xml .= qq|        <rtept lat="$_lat" lon="$_lon">\n|;
    $_position_xml .= qq|            <ele>0.0</ele>\n|;
    $_position_xml .= qq|            <name>$_position_name</name>\n|;
    $_position_xml .= qq|            <cmt>$_cmt</cmt>\n|;
    $_position_xml .= qq|        </rtept>\n|;

    #print "                                                                       _name:$_position_name\n";
    #print "                                                        _cmt:$_cmt\n";

    return $_position_xml;
}

#------------------------------------------------------------------
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

#------------------------------------------------------------------
sub _output_footer {

    my $_footer_xml;

    $_footer_xml .= '    </rte>'."\n";
    $_footer_xml .= '</gpx>'."\n";

    return $_footer_xml;
}


#------------------------------------------------------------------
sub detect_and_process_gps_format {

    # https://api-prod6.tfl.gov.uk//Journey/JourneyResults/SW8%201EH/to/1003196?AccessibilityPreference=norequirements&CyclePreference=AllTheWay&Date=20160402&JourneyPreference=leasttime&MaxWalkingMinutes=40&numberOfTrips=3&Mode=cycle&NationalSearch=False&Time=1415&TimeIs=Departing&WalkingOnly=False&IsExternalWidget=False&WalkingSpeed=average&bikeProficiency=easy,moderate,fast&alternativewalking=true&WalkingOptimization=False&app_id=8268063a&app_key=14f7f5ff5d64df2e88701cef2049c804
    $gps_formats{ TFLMap } = {
                                 description => 'Transport for London Map Data',
                                 pattern => '"startLat":(-?\d+\.\d+),"startLon":(-?\d+\.\d+),"endLat":(-?\d+\.\d+),"endLon":(-?\d+\.\d+)',
                                 start_lat_ref => 'd1',
                                 start_lon_ref => 'd2',
                                 end_lat_ref => 'd3',
                                 end_lon_ref => 'd4',
                             };

    # 
    # https://tfl.gov.uk/plan-a-journey/results?IsAsync=true&JpType=cycling&InputFrom=SW9+9SL&DataSetsJson=null&Modes=tube%2Cdlr%2Coverground%2Ctflrail%2Cbus%2Criver-bus%2Ctram%2Ccable-car%2Cnational-rail%2Criver-tour&From=SW9+9SL&FromId=&PreviousFrom=SW9+9SL&InputTo=Alexandra+Palace%2C+Alexandra+Palace+Park&DataSetsJson=null&Modes=tube%2Cdlr%2Coverground%2Ctflrail%2Cbus%2Criver-bus%2Ctram%2Ccable-car%2Cnational-rail%2Criver-tour&To=Alexandra+Palace%2C+Alexandra+Palace+Park&ToId=1003196&PreviousTo=Alexandra+Palace%2C+Alexandra+Palace+Park&Date=20160402&Time=2015&Mode=bus&Mode=tube&Mode=national-rail&Mode=dlr&Mode=overground&Mode=tflrail&Mode=river-bus&Mode=tram&Mode=cable-car&Mode=coach&CyclePreference=AllTheWay&WalkingSpeedWalking=average&JourneyPreference=leasttime&AccessibilityPreference=norequirements&MaxWalkingMinutes=40&WalkingSpeedTransport=average&InputVia=&DataSetsJson=null&Modes=tube%2Cdlr%2Coverground%2Ctflrail%2Cbus%2Criver-bus%2Ctram%2Ccable-car%2Cnational-rail&Via=&ViaId=&PreviousVia=&NationalSearch=false&WalkingOptimization=false&SavePreferences=false&IsMultipleJourneySelection=True&JourneyType=&IsPastWarning=False&ispostback=true&app_id=8268063a&app_key=14f7f5ff5d64df2e88701cef2049c804
    $gps_formats{ TFLDirections } = {
                                        description => 'Transport for London Streetview Directions',
                                        pattern => 'instruction-heading[^\>]*\>([\w ]+).{5,80}"instruction-description"\>([\w, ]+).{5,1400}location=(-?\d+\.\d+),(-?\d+\.\d+)&heading=\d+',
                                        wpt_name_ref => 'd1',
                                        wpt_supp_ref => 'd2',
                                        start_lat_ref => 'd3',
                                        start_lon_ref => 'd4',
                                };

    foreach my $_gps_format_name ( sort keys %gps_formats ) {
        my $test = $gps_formats{$_gps_format_name}->{pattern};
        if ( $sourcefile_content =~ m{$test}is ) {
            $chosen_format = $_gps_format_name;
            print "\n";
            output_gpx_route($_gps_format_name);
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
