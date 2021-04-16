#!/bin/sh

#
# path to iTMSTransporter
#
TRANSPORTER=/usr/local/itms/bin/iTMSTransporter

#
# itunes connect login data
#
APPLE_ID=TODO
ITUNES_PWD=TODO

#
# Unique App ID. iTunes Connect -> App -> App Information -> Geneeral Information -> SKU
#
SKU=TODO

#
# name of the package that will be downloaded by iTMSTranporter
#
PACKAGE=$SKU.itmsp

#
# name of metadata file inside $PACKAGE
#
METADATA="metadata.xml"

#
# path to the xml which contains the new metadata.
#
UPLOAD_METADATA="upload_metadata.xml"

#
# path to the directory that contains the screenshots
#
SCREENSHOTS_DIR=./screenshots

SCRIPT_VERSION="0.9"


function updateDescription() {
	desc_count="$(xml sel -t -v "count(/metadata/description)" $UPLOAD_METADATA)"

	echo "descr1"
	if [ $desc_count -gt 0 ] 
		then 
		echo "descr2"
			for ((i=1; i<=desc_count; i++)); do
				echo "descr3"
			  desc_data="$(xml sel -t -v "(metadata/description)[$i]" $UPLOAD_METADATA)"
			  desc_locale="$(xml sel -t -v "(metadata/description)[$i]/@locale" $UPLOAD_METADATA)"

			  cmd="xml ed -N x=\"http://apple.com/itunes/importer\" -u '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$desc_locale\""]/x:description' -v '"$desc_data"' $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
			  eval $cmd

			  rm $PACKAGE/$METADATA
			  mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"

			done
		else echo "ERROR: no description found"
	fi
}

function updateTitle() {
	title_count="$(xml sel -t -v "count(/metadata/title)" $UPLOAD_METADATA)"

	if [ $title_count -gt 0 ] 
		then 
			for ((i=1; i<=title_count; i++)); do
			  title_data="$(xml sel -t -v "(metadata/title)[$i]" $UPLOAD_METADATA)"
			  title_locale="$(xml sel -t -v "(metadata/title)[$i]/@locale" $UPLOAD_METADATA)"

			  cmd="xml ed -N x=\"http://apple.com/itunes/importer\" -u '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$title_locale\""]/x:title' -v '"$title_data"' $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
			  eval $cmd

			  rm $PACKAGE/$METADATA
			  mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"

			done
		else echo "ERROR: no title found"
	fi
}

function updateWhatsNew() {
	whatsnew_count="$(xml sel -t -v "count(/metadata/version_whats_new)" $UPLOAD_METADATA)"

	if [ $whatsnew_count -gt 0 ] 
		then 
			for ((i=1; i<=whatsnew_count; i++)); do
			  whatsnew_data="$(xml sel -t -v "(metadata/version_whats_new)[$i]" $UPLOAD_METADATA)"
			  whatsnew_locale="$(xml sel -t -v "(metadata/version_whats_new)[$i]/@locale" $UPLOAD_METADATA)"

			  cmd="xml ed -N x=\"http://apple.com/itunes/importer\" -u '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$whatsnew_locale\""]/x:version_whats_new' -v '"$whatsnew_data"' $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
			  eval $cmd

			  rm $PACKAGE/$METADATA
			  mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"

			done
		else echo "ERROR no version_whats_new found"
	fi
}

#
# downlaod metadata from itunes connect and store to $PACKAGE
#
function readMetadata() {
	$TRANSPORTER -m status -u $APPLE_ID -p $ITUNES_PWD -vendor_id $SKU &
	PID=$!
	wait $PID
	$TRANSPORTER -m lookupMetadata -u $APPLE_ID -p $ITUNES_PWD -vendor_id $SKU -destination ./ -v off &
	PID=$!
	wait $PID
	version="$(xml sel -N x="http://apple.com/itunes/importer" -t -v "/x:package/x:software/x:software_metadata/x:versions/x:version/@string" $PACKAGE/$METADATA)"
	cleard_for_sale="$(xml sel -N x="http://apple.com/itunes/importer" -t -v "/x:package/x:software/x:software_metadata/x:products/x:product/x:cleard_for_sale" $PACKAGE/$METADATA)"

	echo "Version: "$version
	echo "Cleared for sale: "$cleard_for_sale
}

#
# download metadata -> edit metadata -> verify metadata -> upload metadata
#
function updateAndUploadMetadata() {
	UPLOAD_METADATA="$1"
	$TRANSPORTER -m lookupMetadata -u $APPLE_ID -p $ITUNES_PWD -vendor_id $SKU -destination ./ &
	PID=$!
	wait $PID
	printState "finished metadata download from itunes connect"
	updateWhatsNew
	updateTitle 
	updateDescription 
	printState "finished editing"
	uploadMetadata
}

#
# verify $PACKAGE 
#
function verifyMetadata() {
	$TRANSPORTER -m verify -f $PACKAGE -u $APPLE_ID -p $ITUNES_PWD &
	PID=$!
	wait $PID
	printState "finished verifying"
}

#
# upaload $PACKAGE to itunes connect
#
function uploadMetadata() {
	verifyMetadata
	$TRANSPORTER -m upload -f $PACKAGE -u $APPLE_ID -p $ITUNES_PWD &
	PID=$!
	wait $PID
	printState "finished uploading to itunes connect"
}

#
# adding a screenshots parent node to $METADATA
#
function addScreenshotsParentNode() {
	lang=$1
	cmd="xml ed -N x=\"http://apple.com/itunes/importer\" --subnode '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$lang\""]' --type elem -n software_screenshots -v '' $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
#	echo $cmd
	eval $cmd
	mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"
}

#
# adding a screenshot node to $METADATA
#
function addScreenshotNode() {
	lang=$1
	display_target=$2
	position=$3
	size=$4
	filename=$5
	md5_hash=$6

	cmd="xml ed -N x=\"http://apple.com/itunes/importer\" --subnode '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$lang\""]/x:software_screenshots' --type elem -n software_screenshot -v '' $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
#	echo $cmd
	eval $cmd
	mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"

	cmd="xml ed -N x=\"http://apple.com/itunes/importer\" --insert '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$lang\""]/x:software_screenshots/x:software_screenshot[not(@display_target)]' --type attr -n display_target -v $display_target $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
#	echo $cmd
	eval $cmd
	mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"

	cmd="xml ed -N x=\"http://apple.com/itunes/importer\" --insert '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$lang\""]/x:software_screenshots/x:software_screenshot[not(@position)]' --type attr -n position -v $position $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
#	echo $cmd
	eval $cmd
	mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"

	cmd="xml ed -N x=\"http://apple.com/itunes/importer\" --subnode '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$lang\""]/x:software_screenshots/x:software_screenshot[@display_target="\"$display_target\""][@position="\"$position\""]' --type elem -n size -v '"$size"' $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
#	echo $cmd
	eval $cmd
	mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"

	cmd="xml ed -N x=\"http://apple.com/itunes/importer\" --subnode '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$lang\""]/x:software_screenshots/x:software_screenshot[@display_target="\"$display_target\""][@position="\"$position\""]' --type elem -n file_name -v '"$filename"' $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
#	echo $cmd
	eval $cmd
	mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"

	cmd="xml ed -N x=\"http://apple.com/itunes/importer\" --subnode '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$lang\""]/x:software_screenshots/x:software_screenshot[@display_target="\"$display_target\""][@position="\"$position\""]' --type elem -n checksum -v '"$md5_hash"' $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
#	echo $cmd
	eval $cmd
	mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"

	cmd="xml ed -N x=\"http://apple.com/itunes/importer\" --insert '/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name="\"$lang\""]/x:software_screenshots/x:software_screenshot[@display_target="\"$display_target\""][@position="\"$position\""]/x:checksum[not(@type)]' --type attr -n type -v md5 $PACKAGE/$METADATA > $PACKAGE/tmp.xml"
#	echo $cmd
	eval $cmd
	mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"
}

function removeScreenshotNode() {
	lang=$1
	xml ed -N x="http://apple.com/itunes/importer" --delete "/x:package/x:software/x:software_metadata/x:versions/x:version/x:locales/x:locale[@name='"$lang"']/x:software_screenshots" $PACKAGE/$METADATA > $PACKAGE/tmp.xml
	mv "$PACKAGE/tmp.xml" "$PACKAGE/$METADATA"
}

#
# reading all screenshots from $SCREENSHOTS_DIR, calculating size and md5 hash, adding nodes to $METADATA and copying files to $PACKAGE
#
function updateScreenshots() {
	if [ -d "$SCREENSHOTS_DIR" ]; then

		for locale in $SCREENSHOTS_DIR/*
		do
			if [ -f "$locale" ]; then
					continue
			fi

			# remove old screenshots
			removeScreenshotNode $(basename $locale)

			addScreenshotsParentNode $(basename $locale)
			for display in $locale/*
			do
					if [ -f "$display" ]; then
							continue
					fi
					pos=0
				for screenshot in $display/*
				do

					if [ -f "$screenshot" ]; then
						md5=$(md5 -q $screenshot)
						file_size=$(stat -f%z $screenshot)
						file_name=$(basename $screenshot)
						display_category=$(basename $display)
						locale_category=$(basename $locale)
						pos=$(( pos + 1 ))

						# add new screenshots
						addScreenshotNode $locale_category $display_category $pos $file_size $file_name $md5

						# copy screenshot to upload package
						cp "$screenshot" "$PACKAGE/$file_name"
					fi
				done
				if [ $pos -eq 0 ]; then
					removeScreenshotNode $(basename $locale)
				fi
			done
		done

	else 
		echo "ERROR: screenshot directory "$SCREENSHOTS_DIR" not found"
	fi
}

#
# delete $PACKAGE and $UPLOAD_METADATA
#
function cleanUp() {
	if [ -d "$PACKAGE" ]; then 
		rm -rf $PACKAGE
		echo $PACKAGE" deleted"
	fi
	if [ -f "$UPLOAD_METADATA" ]; then 
		rm -rf $UPLOAD_METADATA
		echo $UPLOAD_METADATA" deleted"
	fi
}

function usage() {
	echo "usage: jaicu [-r | -ud <arg> | -ul | -os | -version | -help] "
	echo "jaicu - just another itunes connect uploader "$SCRIPT_VERSION
	echo "-r Downlad metadata and print the app's version number"
	echo "-ud Update the metadata with values specified in <arg> and upload to itunes connect"
	echo "-ul Upload to itunes connect"
	echo "-os Overwrite all screenshots with the ones provided in ./screenshots"
	echo "-clean Deletes locally stored data from the last job"
	echo "-version Print script version "
	echo "-help Print usage "
	echo ""
	echo "TODO: add info about metadata format and order structure"
}

function printState() {
	echo '*******************************'
	echo "$1"
	echo '*******************************'
	echo ''
}

#
# Download metadata -> edit xml -> verify metadata -> upload metadata
#
#readArguments
if [ $# -eq 0 ]
  then
    usage
fi
while [ "$1" != "" ]; do
    case $1 in
        -r | --read )           			shift
											readMetadata
                                			;;
        -ud | --update )    				shift
											if [ -z "$1" ]
											  then
											  	echo 'No path specified. Will look in '$UPLOAD_METADATA' for new values.'
											    updateAndUploadMetadata $UPLOAD_METADATA
											   else 
											   	updateAndUploadMetadata $1
											fi
                                			;;                      			
        -ul | --upload )     				uploadMetadata
                                			exit
                                			;;    
        -v | --verify )     				verifyMetadata
                                			exit
                                			;;                   			
        -os | --overwritescreenshots )      updateScreenshots
                                			exit
                                			;;
        -clean )				     	    cleanUp
                                			exit
                                			;;
        -version  )				     	    echo $SCRIPT_VERSION
                                			exit
                                			;;
        -help )							    usage
                                			exit
                                			;;
        * )                     			usage
                                			exit 1
    esac
    shift
done
