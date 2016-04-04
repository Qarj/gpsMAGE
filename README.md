# gpsMAGE 0.01

## Project Goal

Convert various types of input to GPX Route files.

## Current Status

Transport for London, at https://tfl.gov.uk/ allows you to generate turn by turn journey
plans for cycling through London.

Unfortunately the turn by turn plans are not that helpful since you have to stop constantly
to refer to them.

This project can convert those journy plans into GPX compatible route files that you can load
into your GPS.

Tested with a Garmin GPSMAP 60CSx.

The project is still at a very early stage, but is already working.

To use it, you will need to use a tool that captures HTTP traffic. For example, if you use
HTTPFox for Firefox, turn this on and generate a cycle plan and watch the traffic.

In the result, look for a URL starting with
```
https://tfl.gov.uk/plan-a-journey/results?IsAsync=true&JpType=cycling
```
approx one third of the way down. The HTML source for this will contain the turn by turn
directions.

Copy and paste this into a text file called directions.txt.

You can then run gpsMAGE as follows on this file:
```
gpsMAGE.pl directions.txt
```

The output will hopefully look like this:
```
C:\git\gpsMAGE>gpsMAGE.pl directions.txt

Writing file 1 : directions_1_TFLDirections.gpx
Writing file 2 : directions_2_TFLDirections.gpx
Writing file 3 : directions_3_TFLDirections.gpx

C:\git\gpsMAGE>
```

The three files correspond to the Easy, Moderate and Fast options.

About two thirds of the way down in your traffic capture, you will see another URL starting with the following:
```
https://api-prod6.tfl.gov.uk//Journey/JourneyResults/
```

This one contains the 3 journeys also. It does not have turn by turn directions, but it does have a lot more
waypoints so it could be worth a look.

If you cannot see the http source for the URL, copy the URL into Chrome and you should see all the JSON
display.

## Examples

There are two inbuilt examples so you can see it in action for a demo journey.


The first example is for the turn by turn directions.
```
gpsMAGE.pl examples\tfl_directions.txt
```

The second is for the more detailed journey with more waypoints. TFL presumably use this for the Google Map
overlay.
```
gpsMAGE.pl examples\tfl_map.txt
```

## Roadmap

The next goal is to have GPS Mage produce the files straight from the command prompt without having to
worry about capturing the HTTP traffic.

