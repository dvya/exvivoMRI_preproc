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

# exit if there is an error
# set -e  <-- can't do this because we use dcmftest to check the error code of dcm_im input

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
if [ `$FSLDIR/bin/imtest $im` -ne 1 ]; then
  echo "$im not found/not an image file"
  exit 1
fi
im_noext=`remove_ext $im`
# dicom files:
######### fieldmap
dcm_fmap=$2
######### high-res image -- positive RO gradient
dcm_im=$3
/usr/bin/dcmftest $dcm_im; dcmresult=$?
echo "dcmftest result = $dcmresult"
if [ "$dcmresult" = "0" ]; then
  echo "$dcm_im is a dicom file"
  DCMIMsupplied=yes
elif [ "$dcmresult" = "1" ]; then
  echo "$dcm_im is NOT an dicom file - it has been supplied as the FLASH dwell time = $dcm_im"
  DCMIMsupplied=no
else
  echo "dicom test error"
  exit 1
fi
######### directory containing fieldmap calculated by fmap_prep.sh 
Dfmap=$4

###### OUTPUT images - grad and B0 unwarping
OUTim_noext=`basename $im_noext`

final_dph=${Dfmap}/${PREFIX}${GNL_suffix}__unwarp_B0__dph.nii.gz
final_mask=${Dfmap}/${PREFIX}${GNL_suffix}__unwarp_B0__mask.nii.gz

for tmp in ${PREFIX}_scanner_mag.nii.gz ${PREFIX}_scanner_pha.nii.gz $final_dph ; do
  if [ `$FSLDIR/bin/imtest $tmp` -ne 1 ]; then
    echo "image $tmp does not exist!"
    echo "supply directory containing final fieldmaps (processed with fmap_prep.sh)"
    echo "THIS IS FOR HI-RES FMAP TEST - CONTINUE"
    ## exit 1
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
freq_fmap=`grep -a 'lFrequency' $dcm_fmap | awk '{print $3}'`
if [ "$DCMIMsupplied" = "yes" ]; then
  freq_im=`grep -a 'lFrequency' $dcm_im | awk '{print $3}'`
elif [ "$DCMIMsupplied" = "no" ]; then
  echo "no DCM available for image - setting image frequency to same as fieldmap!!!"
  freq_im=$freq_fmap
fi
echo "Frequencies:"
echo " - fieldmap = $freq_fmap"
echo " - image = $freq_im"
echo "Frequencies:" > params_distcorr.txt
echo " - fieldmap = $freq_fmap" >> params_distcorr.txt
if [ "$DCMIMsupplied" = "no" ]; then
  echo "no DCM available for image - setting image frequency to same as fieldmap!!!" >> params_distcorr.txt
fi
echo " - image = $freq_im" >> params_distcorr.txt

# echo times 
# te1=`grep -a 'alTE\[0\]' $dcm_fmap | awk '{print $3}'`
# te2=`grep -a 'alTE\[1\]' $dcm_fmap | awk '{print $3}'`
# te2 got corrupted using above method for /autofs/space/tiamat_001/users/matthew/projects/vandercoil/I38_BA4445/mri/FA15/fmap-num1
te1=`grep -A 1 -a 'alTE\[0\]' $dcm_fmap | awk 'NR==1 {print $3}'`
te2=`grep -A 1 -a 'alTE\[0\]' $dcm_fmap | awk 'NR==2 {print $3}'`

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
if [ "$DCMIMsupplied" = "yes" ]; then
  dwelltime_im=`grep -a 'alDwellTime\[0\]' $dcm_im | awk '{print $3}'`
elif [ "$DCMIMsupplied" = "no" ]; then
  dwelltime_im=$dcm_im
fi
#dcm_dump_file -t $dcm_fmap | grep '0018 1030'
echo "Dwell times:"
echo " - fieldmap = $dwelltime_fmap"
echo " - image = $dwelltime_im"
echo "Dwell times:" >> params_distcorr.txt
echo " - fieldmap = $dwelltime_fmap" >> params_distcorr.txt
if [ "$DCMIMsupplied" = "no" ]; then
  echo "no DCM available for image - using supplied argument for image dwell time!!!" >> params_distcorr.txt
fi
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
    --o gre_fmap__dph.nii.gz \
    --regheader --no-save-reg --keep-precision --cubic

mri_vol2vol \
    --mov $final_mask \
    --targ $im \
    --o  gre_fmap__mask.nii.gz \
    --regheader --no-save-reg --keep-precision --nearest

# freq_fieldmap - freq_pos
rad_shift_pos=$( echo "scale=10; (${freq_fmap} - ${freq_im}) * ${twopi} * ${tediff}" | bc -l )

fslmaths gre_fmap__dph.nii.gz \
    -add ${rad_shift_pos} gre_fmap_freqshift_${readout}__dph.nii.gz

fslmaths gre_fmap_freqshift_${readout}__dph.nii.gz -mul 0 ph_zeros.nii.gz

fslmerge -t ph_freqshift_${readout}.nii.gz ph_zeros.nii.gz gre_fmap_freqshift_${readout}__dph.nii.gz


#    for dir in x; do

        fugue \
            -i $im \
            -p ph_freqshift_${readout}.nii.gz \
            --dwell=${dwell} --asym=${tediff} \
            --unwarpdir=${dir} \
            --mask=gre_fmap__mask.nii.gz \
            --saveshift=vsm_${dir}_freqshift_${readout}.nii.gz

#    done


#----------------------------------------------------------------------------
# step 1b: dwell time
echo "step 1b: dwell time"

#    for dir in x; do

        fslmaths vsm_${dir}_freqshift_${readout}.nii.gz -mul ${dwell_ratio} vsm_${dir}_freqshift_dwellscale_${readout}.nii.gz

#    done


#============================================================================
# step 2: unwarp using the shifted and scaled maps
echo "step 2: unwarp"

#export PATH=/space/padkeemao/1/users/jonp/lwlab/PROJECTS/VISUOTOPY/mris_toolbox:$PATH
# RobF: we can use the following path (the script is not distributed with freesurfer because the gradient tables are proprietary):
export PATH=/autofs/space/freesurfer/unwarp/gradient_nonlin_unwarp:$PATH

echo "step 2a: gradient non linearity unwarping..."
if [ "${GradNonLin}" = "yes" ] ; then 
	echo ""
	echo "DOING GRADIENT NONLINEARITY CORRECTION"
	echo ""

        unwarp_input=${OUTim_noext}${GNL_suffix}.nii.gz

    gradient_nonlin_unwarp.sh \
        ${im_noext}.nii.gz \
        ${unwarp_input} \
        SC72

elif [ "${GradNonLin}" = "no" ] ; then 
	echo ""
	echo "NOT doing gradient nonlinearity correction"
	echo ""

	unwarp_input=${im_noext}.nii.gz
fi

echo "step 2b: B0 unwarping..."
    for unwarpdir in ${dir} ${dir}- ; do

    echo "unwarpdir = $unwarpdir ..."

    fugue     \
        -i ${unwarp_input} \
        -u ${OUTim_noext}${GNL_suffix}__unwarp_B0_${unwarpdir}.nii.gz \
        --loadshift=vsm_${dir}_freqshift_dwellscale_${readout}.nii.gz \
        --unwarpdir=${unwarpdir}
	
    done


#============================================================================
# step 3: verify unwarping with freeview

#freeview -v \
#    ${im_noext}.nii.gz \
#    ${im_noext}__unwarp_grad.nii.gz \
#    ${im_noext}__unwarp_grad__unwarp_B0_*.nii.gz &
