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
    echo "Usage: $0 <dcm_mag> <dcm_pha> <GradNonLin>"
    echo ""
    echo "dcm_mag 		-- path to fieldmap magnitude DICOM (find in scan.log, or filelist.txt or other dcmunpack output)"
    echo "dcm_mag 		-- path to fieldmap phase DICOM (find in scan.log, or filelist.txt or other dcmunpack output)"
    echo "<GradNonLin>		-- 'yes' for gradient nonlinearity correction; 'no' otherwise"
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

[ "$3" = "" ] && Usage

#########################################
# define variables with user inputs
#########################################

echo ""
echo "$0 $*"

#PREFIX=field_mapping_2D_BC_run1
PREFIX=fmap2D

# dicom files for the mag and phase data
dcm_mag=$1
dcm_pha=$2
# gradient non linearity option
GradNonLin=$3

if [ "${GradNonLin}" = "yes" ] ; then 
	echo ""
	echo "DOING GRADIENT NONLINEARITY CORRECTION"
	echo ""
elif [ "${GradNonLin}" = "no" ] ; then 
	echo ""
	echo "NOT doing gradient nonlinearity correction"
	echo ""
else
	echo "GradNonLin=${GradNonLin} -- must be 'yes' or 'no'!!"
	exit 1
fi

P=${PREFIX}_scanner_pha_float.nii.gz
M=${PREFIX}_scanner_mag_vol1.nii.gz
if [ `$FSLDIR/bin/imtest $P` -ne 1 ] || [ `$FSLDIR/bin/imtest $M` -ne 1 ] ; then
  tmpmag=${PREFIX}_scanner_mag.nii.gz
  tmppha=${PREFIX}_scanner_pha.nii.gz

  echo "creating $tmpmag and $tmppha from dicoms ..."
  mri_convert $dcm_mag ${tmpmag}
  mri_convert $dcm_pha ${tmppha}

  # take 1st echo of the two magnitude echoes
  fslroi ${PREFIX}_scanner_mag.nii.gz ${PREFIX}_scanner_mag_vol1 0 1
  # for preprocess1.m -- make sure that phase is a float type (fslmaths default output is float)
  fslmaths ${PREFIX}_scanner_pha.nii.gz -mul 1.0 ${PREFIX}_scanner_pha_float.nii.gz

else 
  echo "$P and $M already exist ... "
  echo "... supplied from a hi-res B0 acquisition (interleaved TE FLASH scan 20190329)?"
  echo "... or you want to re-run the B0 map processing?"
fi 
  
# read info about fieldmap acquisition
dwelltime=`grep -a 'alDwellTime\[0\]' $dcm_mag | awk '{print $3}'`
# te1=`grep -a 'alTE\[0\]' $dcm_mag | awk '{print $3}'`
# te2=`grep -a 'alTE\[1\]' $dcm_mag | awk '{print $3}'`
# te2 got corrupted using above method for /autofs/space/tiamat_001/users/matthew/projects/vandercoil/I38_BA4445/mri/FA15/fmap-num1

te1=`grep -A 1 -a 'alTE\[0\]' $dcm_mag | awk 'NR==1 {print $3}'`
te2=`grep -A 1 -a 'alTE\[0\]' $dcm_mag | awk 'NR==2 {print $3}'`

# echo time reported in microseconds
tediff=$(echo "scale=10; ($te2 - $te1) / 10^6" | bc -l)

# dwell time reported in nanoseconds
dwell=$( echo "scale=10; 2 * $dwelltime / 10^9" | bc -l)

# a(1) = arctan(1) = 45 degrees = pi/4 ...
twopi=$(echo "scale=10; 2 * 4*a(1)" | bc -l)
gamma=267510000 # rad/T
gammabar=42576000 # Hz/T

echo "te1 = $te1, te2 = $te2, dwell time = $dwelltime"
echo "tediff = $tediff, dwell = $dwell"

echo "te1 = $te1, te2 = $te2, dwell time = $dwelltime" > params_prep.txt
echo "tediff = $tediff, dwell = $dwell" >> params_prep.txt

###################################
# for grad non-linearity correction
###################################
export FSF_OUTPUT_FORMAT=nii.gz

###################################
# prepare fieldmap data
###################################
# convert to rad, save real/image & abs/pha
# see fsl_prepare_fieldmap - jon subtracts/scales by 2047.5 not 2048
# real/imag data needed for grad nonlinearity correction


######## fslcomplex results have wrong orientation...
# fslcomplex -complexpolar absvol phasevol complexvol
# fslcomplex -realcartesian complexvol realvol imagvol
# fslcomplex -realpolar complexvol absvol phasevol

# -4096 -> 4095
#fslmaths ${PREFIX}_scanner_pha -div 4095 -mul 3.14 ${PREFIX}_pha_rad

#fslcomplex -complexpolar ${PREFIX}_scanner_mag_vol1 ${PREFIX}_pha_rad ${PREFIX}__cmplx
#fslcomplex -realcartesian ${PREFIX}__cmplx ${PREFIX}__real ${PREFIX}__imag 
#fslcomplex -realpolar ${PREFIX}__cmplx ${PREFIX}__mag ${PREFIX}__pha 

#imcp ${PREFIX}_scanner_mag_vol1.nii.gz mag.nii
#gunzip mag.nii.gz 
########

matlab7.9 -nosplash -nodesktop -r "addpath('/autofs/cluster/gerenuk/user/rfrost/exvivo/distortioncorr/flashFieldmapScripts'); preprocess1; exit"
# matlab script
# inputs:
# - fmap2D_scanner_mag_vol1.nii.gz
# - fmap2D_scanner_pha.nii.gz
# output:
# - fmap2D__real.nii.gz
# - fmap2D__imag.nii.gz
# - fmap2D__mag.nii.gz
# - fmap2D__pha.nii.gz


if [ "${GradNonLin}" = "yes" ] ; then 
	echo ""
	echo "DOING GRADIENT NONLINEARITY CORRECTION"
	echo ""

    #export PATH=/space/padkeemao/1/users/jonp/lwlab/PROJECTS/VISUOTOPY/mris_toolbox:$PATH
    # RobF: we can use the following path (the script is not distributed with freesurfer because the gradient tables are proprietary):
    export PATH=/autofs/space/freesurfer/unwarp/gradient_nonlin_unwarp:$PATH
    
    echo "STARTING GRAD NON LIN UNWARP******************"
    for comp in real imag; do
        gradient_nonlin_unwarp.sh \
            ${PREFIX}__${comp}.nii.gz \
            ${PREFIX}__unwarp_grad__${comp}.nii.gz \
            SC72 \
        gradient_nonlin_unwarp.sh \
            ${PREFIX}__${comp}.nii.gz \
            ${PREFIX}__unwarp_grad_nojac__${comp}.nii.gz \
            SC72 \
            --nojac
    done
    
    matlab7.9 -nosplash -nodesktop -r "addpath('/autofs/cluster/gerenuk/user/rfrost/exvivo/distortioncorr/flashFieldmapScripts'); preprocess2; exit"
    # convert grad nonlinearity real/imag output to abs/pha
    # in:	- fmap2D__unwarp_grad__real.nii.gz
    # 	- fmap2D__unwarp_grad__imag.nii.gz
    # out: 	- fmap2D__unwarp_grad__mag.nii.gz
    # 	- fmap2D__unwarp_grad__pha.nii.gz

    PREFIX=${PREFIX}__unwarp_grad
    echo "-------------------------"
    echo "reset PREFIX to ${PREFIX}"
    echo "-------------------------"
    
else

    echo ""
    echo "NOT using grad non lin correction"
    echo ""
    # the original fmap2D__mag.nii.gz and fmap2D__pha.nii.gz from preprocess1.m will be used...

fi

prelude \
    -a ${PREFIX}__mag.nii \
    -p ${PREFIX}__pha.nii \
    -o ${PREFIX}__dph.nii \
    -f -v \
    --savemask=${PREFIX}__mask.nii

# for fun:
fslmaths ${PREFIX}__dph -div ${tediff} -div ${twopi} ${PREFIX}__Hz
fslmaths ${PREFIX}__dph -div ${tediff} -div ${gamma} ${PREFIX}__Tesla


# fugue expects two frames, so we fill one with zeros (c.f. doug's epidewarp.fsl)
fslmaths ${PREFIX}__dph -mul 0 ${PREFIX}__dph_zeros

fslmerge -t ph_${PREFIX} ${PREFIX}__dph_zeros ${PREFIX}__dph


# generate the voxel shift maps for each direction
for dir in x y z; do

    fugue \
        -i ${PREFIX}__mag \
        -u ${PREFIX}__unwarp_B0__mag_${dir} \
        -p ph_${PREFIX} \
        --dwell=${dwell} --asym=${tediff} \
        --unwarpdir=${dir}- \
        --mask=${PREFIX}__mask \
        --saveshift=vsm_${PREFIX}__${dir}
        #--saveshift=vsm_${PREFIX}__unwarp_grad__${dir}

done

# fieldmap is acquired with positive x readout, so must undistort it as well
for comp in real imag; do
    fugue \
        -i ${PREFIX}__${comp} \
        -u ${PREFIX}__unwarp_B0__${comp} \
        --loadshift=vsm_${PREFIX}__x \
        --unwarpdir=x-
        #--loadshift=vsm_${PREFIX}__unwarp_grad__x \
        #--unwarpdir=x-
done

if [ "${GradNonLin}" = "yes" ] ; then 
	echo ""
	echo "running preprocess3.m ... for grad non lin data "
	echo ""

    matlab7.9 -nosplash -nodesktop -r "addpath('/autofs/cluster/gerenuk/user/rfrost/exvivo/distortioncorr/flashFieldmapScripts'); preprocess3; exit"
    # convert grad nonlinearity and B0 corr real/imag output to abs/pha
    # in:	- fmap2D__unwarp_grad__unwarp_B0__real.nii.gz
    # 	- fmap2D__unwarp_grad__unwarp_B0__imag.nii.gz
    # out: 	- fmap2D__unwarp_grad__unwarp_B0__mag.nii.gz
    # 	- fmap2D__unwarp_grad__unwarp_B0__pha.nii.gz

elif [ "${GradNonLin}" = "no" ] ; then 
	echo ""
	echo "running preprocess3_noGradNonLin.m ..."
	echo ""

    matlab7.9 -nosplash -nodesktop -r "addpath('/autofs/cluster/gerenuk/user/rfrost/exvivo/distortioncorr/flashFieldmapScripts'); preprocess3_noGradNonLin; exit"
    # convert grad nonlinearity and B0 corr real/imag output to abs/pha
    # in:	- fmap2D__unwarp_B0__real.nii.gz
    # 	- fmap2D__unwarp_B0__imag.nii.gz
    # out: 	- fmap2D__unwarp_B0__mag.nii.gz
    # 	- fmap2D__unwarp_B0__pha.nii.gz

fi

# calculate final, distortion-free unwrapped phase maps

prelude \
    -a ${PREFIX}__unwarp_B0__mag \
    -p ${PREFIX}__unwarp_B0__pha \
    -o ${PREFIX}__unwarp_B0__dph \
    -f -v \
    --savemask=${PREFIX}__unwarp_B0__mask

fslmaths ${PREFIX}__unwarp_B0__dph -div ${tediff} -div ${twopi} ${PREFIX}__unwarp_B0__Hz
fslmaths ${PREFIX}__unwarp_B0__dph -div ${tediff} -div ${gamma} ${PREFIX}__unwarp_B0__Tesla

