#!/bin/bash

Usage() {
    echo ""
    echo "Rob Frost, November 2018, srfrost@mgh.harvard.edu"
    echo "	adapted from Jon Polimeni's 2012 scripts (preprocess.sh, unwarp.sh, compose.sh)"
    echo ""
    echo "Script for fieldmap-based distortion correction of multi-echo FLASH data"
    echo "odd/even echoes are distorted in opposite directions in the readout dimension"
    echo "use a fieldmap acquisition (2D Siemens standard) to correct them"
    echo ""
    echo "Usage: $0 <nii_im> <dir> <readout> <GradNonLin>"
    echo ""
    echo "** fmap_distcorr.sh must have been run to create vsm already **"
    echo ""
    echo "nii_im 		-- hi-res FLASH nifti image"
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

[ "$4" = "" ] && Usage

#########################################
# define variables with user inputs
#########################################

echo ""
echo "$0 $*"

# the high-res image nii.gz or create it
im=$1
if [ `$FSLDIR/bin/imtest $im` -ne 1 ]; then
  echo "$im not found/not an image file"
  exit 1
fi
im_noext=`remove_ext $im`

###### OUTPUT images - grad and B0 unwarping
OUTim_noext=`basename $im_noext`

######### distortion direction in the images
dir=$2
if [ "$dir" = "x" ] || [ "$dir" = "y" ] || [ "$dir" = "z" ] ; then
  echo "distortion direction supplied is $dir ..."
else
  echo "supply x, y, or z distortion direction!"
  exit 1
fi
######### pos or neg, for naming the output
readout=$3
if [ "$readout" = "pos" ] || [ "$readout" = "neg" ] ; then
  echo "readout direction supplied is $readout ..."
else
  echo "supply pos or neg readout direction!"
  exit 1
fi
######### applying gradient nonlinearity correction
GradNonLin=$4
GRADNonL_str=__unwarp_grad
EMPTY_str=''

#export PATH=/space/padkeemao/1/users/jonp/lwlab/PROJECTS/VISUOTOPY/mris_toolbox:$PATH
# RobF: we can use the following path (the script is not distributed with freesurfer because the gradient tables are proprietary):
export PATH=/autofs/space/freesurfer/unwarp/gradient_nonlin_unwarp:$PATH

echo "step 1a: gradient non linearity unwarping..."
#for readout in pos; do
if [ "${GradNonLin}" = "yes" ] ; then 
	echo ""
	echo "DOING GRADIENT NONLINEARITY CORRECTION"
	echo ""

	GNL_suffix=${GRADNonL_str}

        unwarp_input=${OUTim_noext}${GNL_suffix}.nii.gz

    gradient_nonlin_unwarp.sh \
        ${im_noext}.nii.gz \
        ${unwarp_input} \
        SC72

elif [ "${GradNonLin}" = "no" ] ; then 
	echo ""
	echo "NOT doing gradient nonlinearity correction"
	echo ""

	GNL_suffix=${EMPTY_str}

	unwarp_input=${im_noext}.nii.gz
else
	echo "GradNonLin=${GradNonLin} -- must be 'yes' or 'no'!!"
	exit 1
fi
#done

echo "step 1b: B0 unwarping..."
#for readout in pos; do

    #for absrel in abs rel ; do
    for absrel in abs ; do
    for unwarpdir in ${dir} ${dir}- ; do

    echo "unwarpdir = $unwarpdir ..."

#    fugue     \
#        -i ${unwarp_input} \
#        -u ${OUTim_noext}${GNL_suffix}__unwarp_B0_${unwarpdir}.nii.gz \
#        --loadshift=vsm_${dir}_freqshift_dwellscale_${readout}.nii.gz \
#        --unwarpdir=${unwarpdir}
	
# these should be the same as fugue output... but different unwarpdir sign

deftest=deform_B0_${absrel}__pos_${unwarpdir}
if [ `$FSLDIR/bin/imtest $deftest` -ne 1 ]; then
  echo "$deftest not created yet..."
convertwarp \
    --ref=${unwarp_input} \
    --shiftmap=vsm_${dir}_freqshift_dwellscale_${readout}.nii.gz \
    --shiftdir=${unwarpdir} \
    --${absrel}out \
    --out=deform_B0_${absrel}__pos_${unwarpdir} --jstats --jacobian=jacobian_B0__pos_${unwarpdir}
else
  echo "$deftest exists... skip to applywarp"
fi

applywarp \
    --ref=${unwarp_input} \
    --in=${unwarp_input} \
    --warp=deform_B0_${absrel}__pos_${unwarpdir}.nii.gz \
    --${absrel} \
    --out=${OUTim_noext}${GNL_suffix}__unwarp_B0__apply_${absrel}_${unwarpdir}.nii.gz \
    --interp=trilinear \
    --datatype=float

#convertwarp \
#    --ref=flash_200um_BW_30_fa20_pos.nii \
#    --shiftmap=vsm_x_freqshift_dwellscale_pos.nii.gz \
#    --shiftdir=${SHIFTDIR_pos_fwd} \
#    --absout \
#    --out=deform_B0_abs__pos --jstats --jacobian=jacobian_B0__pos
#
#applywarp \
#    --ref=flash_200um_BW_30_fa20_pos.nii \
#    --in=flash_200um_BW_30_fa20_pos.nii \
#    --warp=deform_B0_abs__pos.nii.gz \
#    --abs \
#    --out=flash_200um_BW_30_fa20_pos_unwarp_B0__apply_abs.nii.gz \
#    --interp=trilinear \
#    --datatype=float

    done
    done
#done
