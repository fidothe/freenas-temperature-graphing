#!/usr/local/bin/bash
#####
# Given an rrd file of the system's cpu and drive temperatures
# as input, this script uses rrdtool to graph the data.
# The input files must named as such: temps-Xmin.rdd
# where X is the minute interval between readings.
# ex: "temps-10min.rrd" would contain readings every 10 minutes
# Author: Seren Thompson
# Date: 2016-04-02
#####

if [ -z $1 ]; then
  echo "Error: you need to give an input filename as an argument. Ex:"
  echo " $0 temps-Xmin.rrd"
  echo
  echo "Exiting..."
  exit 1
fi


######################################
# Script variables
######################################
# These are arbitrary
MAXGRAPHTEMP=50
MINGRAPHTEMP=20
SAFETEMPLINE=40

# # Different strokes for different folks
# LINECOLORS=( 0000FF 4573A7 AA4644 89A54E 71588F 006060 0f4880 )
# LINECOLORS=( 0000FF FF4A46 008941 006FA6 A30059 FFDBE5 7A4900 0000A6 63FFAC B79762 004D43 8FB0FF 997D87 )
# LINECOLORS=( 1CE6FF FF34FF FF4A46 008941 A30059 7A4900 63FFAC B79762 004D43 8FB0FF 997D87 000000 )
# From http://stackoverflow.com/questions/309149/generate-distinctly-different-rgb-colors-in-graphs
# LINECOLORS=( 777A7E E0FEFD E16DC5 01344B F8F8FC 9F9FB5 182617 FE3D21 7D0017 822F21 EFD9DC 6E68C4 35473E 007523 767667 A6825D 83DC5F 227285 A95E34 526172 979730 756F6D 716259 E8B2B5 B6C9BB 9078DA 4F326E B2387B 888C6F 314B5F E5B678 38A3C6 586148 5C515B CDCCE1 C8977F )
# From http://stackoverflow.com/questions/309149/generate-distinctly-different-rgb-colors-in-graphs
LINECOLORS=( 000000 00FF00 0000FF FF0000 01FFFE FFA6FE FFDB66 006401 010067 95003A 007DB5 FF00F6 FFEEE8 774D00 90FB92 0076FF D5FF00 FF937E 6A826C FF029D FE8900 7A4782 7E2DD2 85A900 FF0056 A42400 00AE7E 683D3B BDC6FF 263400 BDD393 00B917 9E008E 001544 C28C9F FF74A3 01D0FF 004754 E56FFE 788231 0E4CA1 91D0CB BE9970 968AE8 BB8800 43002C DEFF74 00FFC6 FFE502 620E00 008F9C 98FF52 7544B1 B500FF 00FF78 FF6E41 005F39 6B6882 5FAD4E A75740 A5FFD2 FFB167 009BFF E85EBE )

NUMCOLORS=${#LINECOLORS[@]}
colorindex=0

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# rrdtool database file
datafile=$1
outputprefix=${datafile%.*}  # strip extension
outputprefix=${outputprefix##*/}   # extract filename
interval=`echo $datafile | sed 's/.*temps-\(.*\)min.rrd/\1/'`  # extract minute number

# Get CPU numbers
numcpus=$(/sbin/sysctl -n hw.ncpu)
# Get drive device names
drivedevs=
for i in $(/sbin/sysctl -n kern.disks | awk '{for (i=NF; i!=0 ; i--) if(match($i, '/da/')) print $i }' ); do
  # Sanity check that the drive will return a temperature (we don't want to include non-SMART usb devices)
  DevTemp=`/usr/local/sbin/smartctl -a /dev/$i | awk '/194 Temperature_Celsius/{print $0}' | awk '{print $10}'`;
  if ! [[ "$DevTemp" == "" ]]; then
    drivedevs="${drivedevs} ${i}"
  fi
done

title="Temps"


######################################
# Script functions
######################################
write_graph_to_disk ()
{
  /usr/local/bin/rrdtool graph ${BASEDIR}/${outputprefix}-${outputfilename}.png \
  -w 785 -h 151 -a PNG \
  --slope-mode \
  --start end-${timespan} --end now \
  --font DEFAULT:7: \
  --title "${title}" \
  --watermark "`date`" \
  --vertical-label "Celcius" \
  --right-axis-label "Celcius" \
  ${guidrule} \
  ${defsandlines} \
  --right-axis 1:0 \
  --alt-autoscale \
  --lower-limit ${MINGRAPHTEMP} \
  --upper-limit ${MAXGRAPHTEMP} \
  --rigid > /dev/null
  # "HRULE:${SAFETEMPLINE}#FF0000:Max safe temp - ${SAFETEMPLINE}"
  # "HRULE:${SAFETEMPLINE}#FF0000:Max-${SAFETEMPLINE}"
}



######################################
# Main
######################################
# seconds in:
# a day:   86400
# 2 days:  172800
# a week:  604800
# 30 days: 2592000

interval=`echo ${datafile} | sed 's/.*temps-\(.*\)min.rrd/\1/'`
if [[ "$interval" == "" ]]; then
  interval=1
fi
timespan=$((interval * 86400))

# # Graph all cpus and drives together
# outputfilename=everything
# title="Temperature: All CPUs and Drives, ${interval} minute interval"
# guidrule=
# defsandlines=
# for (( i=0; i < ${numcpus}; i++ )); do
#   (( colorindex = i % NUMCOLORS )) # If we run out of colors, start over
#   defsandlines="${defsandlines} DEF:cpu${i}=${datafile}:cpu${i}:MAX LINE1:cpu${i}${LINECOLORS[$colorindex]}:\"cpu${i}\""
# done
# i=0
# for drdev in ${drivedevs}; do
#   (( colorindex = ( i + numcpus ) % NUMCOLORS )) # Don't reuse the cpu colors unless we have to
#   defsandlines="${defsandlines} DEF:${drdev}=${datafile}:${drdev}:MAX LINE1:${drdev}${LINECOLORS[$colorindex]}:\"${drdev}\""
#   (( i = i + 1 ))
# done
# write_graph_to_disk

# Output a combined graph of all cpus
outputfilename=cpus
defsandlines=
title="Temperature: All CPUs, ${interval} minute interval"
guidrule=
for (( i=0; i < ${numcpus}; i++ )); do
  (( colorindex = i % NUMCOLORS )) # If we run out of colors, start over
  defsandlines="${defsandlines} DEF:cpu${i}=${datafile}:cpu${i}:MAX LINE1:cpu${i}#${LINECOLORS[$colorindex]}:cpu${i}"
done
write_graph_to_disk

# Output a combined graph of all drives
outputfilename=drives
defsandlines=
title="Temperature: All Drives, ${interval} minute interval"
guidrule=HRULE:${SAFETEMPLINE}#FF0000:Max-safe-temp:dashes
i=0
for drdev in ${drivedevs}; do
  (( colorindex = i % NUMCOLORS )) # If we run out of colors, start over
  defsandlines="${defsandlines} DEF:${drdev}=${datafile}:${drdev}:MAX LINE1:${drdev}#${LINECOLORS[$colorindex]}:${drdev}"
  (( i = i + 1 ))
done
write_graph_to_disk

# # Output graphs of each cpu
# for (( i=0; i < ${numcpus}; i++ )); do
#   defsandlines="DEF:cpu${i}=${datafile}:cpu${i}:MAX LINE1:cpu${i}#000000:\"cpu${i}\""
#   outputfilename=cpu${i}
#   title="Temperature: CPU ${i}, ${interval} minute interval"
#   guidrule=
#   write_graph_to_disk
# done

# # Output graphs of each drive
# for i in ${drivedevs}; do
#   drivenum=${i#ada*}
#   defsandlines="DEF:${i}=${datafile}:${i}:MAX LINE1:${i}#000000:\"${i}\""
#   outputfilename=drive-${i}
#   guidrule="HRULE:${SAFETEMPLINE}#FF0000"
#   title="Temperature: Drive ${i}, ${interval} minute interval"
#   write_graph_to_disk
# done


