#!/bin/bash

Usage() {
    echo ""
    echo "Rob Frost, November 2018, srfrost@mgh.harvard.edu"
    echo "	adapted from Jon Polimeni's 2012 scripts (preprocess.sh, unwarp.sh)"
    echo ""
    echo "Script for fieldmap-based distortion correction of multi-echo FLASH data"
    echo "odd/even echoes are distorted in opposite directions in the readout dimension"
    echo "use a fieldmap acquisition (2D Siemens standard) to correct them"
    echo ""
    echo "Usage: $0 <nii_im> <dcm_fmap> <dcm_im> <Dfmap> <dir> <readout> <GradNonLin>"
    echo ""
    echo "nii_im 		-- hi-res FLASH nifti image"
    echo "dcm_fmap 		-- path to fieldmap DICOM (find in scan.log, or filelist.txt or other dcmunpack output)"
    echo "dcm_im 		-- path to hi-res FLASH DICOM (find in scan.log, or filelist.txt or other dcmunpack output)"
    echo "Dfmap 		-- directory containing fieldmap prepared with fmap_prep.sh"
    echo "dir	 		-- distortion dimension in the images (1,2, or 3)"
    echo "readout 		-- pos or neg"
    echo "GradNonLin 		-- yes or no"
    echo ""
    echo "scripts:"
    echo "	1) fmap_prep.sh"
    echo "	2) fmap_distcorr.sh"
    echo "	3) fmap_applydistcorr.sh"
    echo ""
    exit -1
}

# check FreeSurfer has been sourced (. sourcefs6_0_0.sh)
FSpath=`which freeview`
FSnotsourced=$?
if [ "$FSnotsourced" = "1" ] ; then
	echo "need to source FreeSurfer and FSL! at martinos --> . sourcefs6_0_0.sh"
	exit 1
else
	echo "FreeSurfer has been sourced... freeview path is: $FSpath"
fi

[ "$7" = "" ] && Usage

#########################################
# define variables with user inputs
#########################################

echo ""
echo "$0 $*"

#PREFIX=field_mapping_2D_BC_run1
PREFIX=fmap2D
GRADNonL_str=__unwarp_grad
EMPTY_str=''

######### applying gradient nonlinearity correction
GradNonLin=$7
if [ "${GradNonLin}" = "yes" ] ; then
	echo ""
	echo "DOING GRADIENT NONLINEARITY CORRECTION"
	echo ""
	GNL_suffix=${GRADNonL_str}
elif [ "${GradNonLin}" = "no" ] ; then
	echo ""
	echo "NOT doing gradient nonlinearity correction"
	echo ""
	GNL_suffix=${EMPTY_str}
else
	echo "GradNonLin=${GradNonLin} -- must be 'yes' or 'no'!!"
	exit 1
fi

######### the high-res image nii.gz
im=$1
if [ `imtest $im` -ne 1 ]; then
  echo "$im not found/not an image file"
  exit 1
fi
im_noext=`remove_ext $im`
# dicom files:
######### fieldmap
dcm_fmap=$2
######### high-res image -- positive RO gradient
dcm_im=$3
######### directory containing fieldmap calculated by fmap_prep.sh
Dfmap=$4
######### output directory
opdir=$8

###### OUTPUT images - grad and B0 unwarping
OUTim_noext=`basename $im_noext`

final_dph=${Dfmap}/${PREFIX}${GNL_suffix}__unwarp_B0__dph.nii.gz
final_mask=${Dfmap}/${PREFIX}${GNL_suffix}__unwarp_B0__mask.nii.gz

for tmp in ${Dfmap}/${PREFIX}_scanner_mag.nii.gz ${Dfmap}/${PREFIX}_scanner_pha.nii.gz $final_dph ; do
  if [ `imtest $tmp` -ne 1 ]; then
    echo "image $tmp does not exist!"
    echo "supply directory containing final fieldmaps (processed with fmap_prep.sh)"
    exit 1
  fi
done
######### distortion direction in the images
dir=$5
if [ "$dir" = "x" ] || [ "$dir" = "y" ] || [ "$dir" = "z" ] ; then
  echo "distortion direction supplied is $dir ..."
else
  echo "supply x, y, or z distortion direction!"
  exit 1
fi
######### pos or neg, for naming the output
readout=$6
if [ "$readout" = "pos" ] || [ "$readout" = "neg" ] ; then
  echo "readout direction supplied is $readout ..."
else
  echo "supply pos or neg readout direction!"
  exit 1
fi

# pi constant... a(1) = arctan(1) = 45 degrees = pi/4 ...
twopi=$(echo "scale=10; 2 * 4*a(1)" | bc -l)

# frequency:
freq_fmap=`grep -m 1 -a 'lFrequency' $dcm_fmap | awk '{print $3}'`
freq_im=`grep -m 1 -a 'lFrequency' $dcm_im | awk '{print $3}'`
echo "Frequencies:"
echo " - fieldmap = $freq_fmap"
echo " - image = $freq_im"
echo "Frequencies:" > params_distcorr.txt
echo " - fieldmap = $freq_fmap" >> params_distcorr.txt
echo " - image = $freq_im" >> params_distcorr.txt

# echo times
te1=`grep -a 'alTE\[0\]' $dcm_fmap | awk '{print $3}'`
te2=`grep -a 'alTE\[1\]' $dcm_fmap | awk '{print $3}'`

# delta TE reported in microseconds

tediff=$(echo "scale=10; ($te2 - $te1) / 10^6" | bc -l)
echo "TEs:"
echo " - TE1 = $te1, TE2 = $te2"
echo " - delta TE = $tediff"
echo "TEs:" >> params_distcorr.txt
echo " - TE1 = $te1, TE2 = $te2" >> params_distcorr.txt
echo " - delta TE = $tediff" >> params_distcorr.txt

# dwell time:
# (alternatives: alDwellTime & sWiPMemBlock.adFree\[0\] )
dwelltime_fmap=`grep -a 'alDwellTime\[0\]' $dcm_fmap | awk '{print $3}'`
dwelltime_im=`grep -m 1 -a 'alDwellTime\[0\]' $dcm_im | awk '{print $3}'`
#dcm_dump_file -t $dcm_fmap | grep '0018 1030'
echo "Dwell times:"
echo " - fieldmap = $dwelltime_fmap"
echo " - image = $dwelltime_im"
echo "Dwell times:" >> params_distcorr.txt
echo " - fieldmap = $dwelltime_fmap" >> params_distcorr.txt
echo " - image = $dwelltime_im" >> params_distcorr.txt

# dwell time of image (reported in nanoseconds)
#dwell=$( echo "scale=10; 2 * $dwelltime_im / 10^9" | bc -l)
# try to correct factor of 2 "overcorrection":
dwell=$( echo "scale=10; $dwelltime_im / 10^9" | bc -l)
echo "dwell (for FUGUE) = $dwell"
echo "dwell (for FUGUE) = $dwell" >> params_distcorr.txt

# dwell time ratio -- readout oversampling cancels
dwell_ratio=$( echo "scale=10; ${dwelltime_im} / ${dwelltime_fmap} " | bc -l)
echo "Dwell ratio = $dwell_ratio"
echo "Dwell ratio = $dwell_ratio" >> params_distcorr.txt

rad_shift_pos=$( echo "scale=10; (${freq_fmap} - ${freq_im})" | bc -l )
echo "rad_shift_pos = $rad_shift_pos"

#Frequencies:
#- fieldmap = 297050853
#- image = 297050815
#TEs:
#- TE1 = 2830, TE2 = 3850
#- delta TE = .0010200000
#Dwell times:
#- fieldmap = 5900
#- image = 14500
#Dwell ratio = 2.4576271186

# from /autofs/cluster/exvivo/I25_lh_B0_unwarping/mri4__2012_01_27/unwarp/gre_200micron_fieldmap2D/params.sh
#tediff=.0010200000
#twopi=6.2831853064
#freq_fieldmap=297181143
#freq_pos=297181172
#rad_shift_pos=-.1858566213
#rad_shift_pos=-.1858566213
#dwell=.0000172000
#dwell=.0000172000
#dwell_ratio=3.2325581395


#echo "exiting HERE **************"
#exit

#============================================================================
# step 1: perform two corrections to VSM based on differences between
# fieldmap scan and image scans: (a) center frequency, then (b) dwell time

#----------------------------------------------------------------------------
# step 1a: frequency
echo "step 1a: frequency"
mri_vol2vol \
    --mov $final_dph \
    --targ $im \
    --o ${opdir}/gre_fmap__dph.nii.gz \
    --regheader --no-save-reg --keep-precision --cubic

mri_vol2vol \
    --mov $final_mask \
    --targ $im \
    --o  ${opdir}/gre_fmap__mask.nii.gz \
    --regheader --no-save-reg --keep-precision --nearest

# # freq_fieldmap - freq_pos
rad_shift_pos=$( echo "scale=10; (${freq_fmap} - ${freq_im}) * ${twopi} * ${tediff}" | bc -l )

fslmaths ${opdir}/gre_fmap__dph.nii.gz \
    -add ${rad_shift_pos} ${opdir}/gre_fmap_freqshift_${readout}__dph.nii.gz

fslmaths ${opdir}/gre_fmap_freqshift_${readout}__dph.nii.gz -mul 0 ${opdir}/ph_zeros.nii.gz

fslmerge -t ${opdir}/ph_freqshift_${readout}.nii.gz ${opdir}/ph_zeros.nii.gz ${opdir}/gre_fmap_freqshift_${readout}__dph.nii.gz


#    for dir in x; do
# echo "fugue -p ph_freqshift_${readout}.nii.gz -d $dwell_ratio --saveshift=vsm_${dir}_freqshift_${readout}.nii.gz"
echo "fugue -i $im -p ${Dfmap}/ph_freqshift_${readout}.nii.gz --dwell=${dwell} --asym=${tediff} --unwarpdir=${dir} --mask=${Dfmap}/gre_fmap__mask.nii.gz --saveshift=${Dfmap}/vsm_${dir}_freqshift_${readout}.nii.gz"

fugue \
    -i $im \
    -p ${opdir}/ph_freqshift_${readout}.nii.gz \
    --dwell=${dwell} --asym=${tediff} \
    --unwarpdir=${dir} \
    --mask=${opdir}/gre_fmap__mask.nii.gz \
    --saveshift=${opdir}/vsm_${dir}_freqshift_${readout}.nii.gz
#    done


#----------------------------------------------------------------------------
# step 1b: dwell time
echo "step 1b: dwell time"

#    for dir in x; do
echo "fslmaths ${opdir}/vsm_${dir}_freqshift_${readout}.nii.gz -mul ${dwell_ratio} ${opdir}/vsm_${dir}_freqshift_dwellscale_${readout}.nii.gz"
fslmaths ${opdir}/vsm_${dir}_freqshift_${readout}.nii.gz -mul ${dwell_ratio} ${opdir}/vsm_${dir}_freqshift_dwellscale_${readout}.nii.gz
