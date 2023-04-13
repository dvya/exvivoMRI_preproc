#!/bin/bash -p

# jonathan polimeni <jonp@nmr.mgh.harvard.edu>
# Monday, January 30, 2012 12:20:10 -0500

# /autofs/cluster/exvivo/I25_lh_B0_unwarping/mri4__2012_01_27/unwarp/B0/fieldmap2D/preprocess.sh

# modified by Rob Frost, 11 june 2017
# Jon says the 2D fieldmap seemed most reliable - judged by aligning accquisitions with opposite polarity. 3D fieldmap was different and gave some unexpected results. Also the automatic FISP-PSIF Siemens fieldmap method did not seem as good as the Siemens 2D fieldmap


export FSF_OUTPUT_FORMAT=nii.gz

###################################
# for grad non-linearity correction
###################################
matlab7.9 -nosplash -nodesktop -r "preprocess1; exit"

#
#export PATH=/space/padkeemao/1/users/jonp/lwlab/PROJECTS/VISUOTOPY/mris_toolbox:$PATH
# RobF: we can use the following path (the script is not distributed with freesurfer because the gradient tables are proprietary):
export PATH=/autofs/space/freesurfer/unwarp/gradient_nonlin_unwarp:$PATH

#for comp in real imag; do
#    gradient_nonlin_unwarp.sh \
#        field_mapping_2D_BC_run1____${comp}.nii \
#        field_mapping_2D_BC_run1__unwarp_grad__${comp}.nii \
#        SC72 \
#    gradient_nonlin_unwarp.sh \
#        field_mapping_2D_BC_run1__${comp}.nii \
#        field_mapping_2D_BC_run1__unwarp_grad_nojac__${comp}.nii \
#        SC72 \
#        --nojac
#    gradient_nonlin_unwarp.sh \
#        field_mapping_2D_BC_run2__${comp}.nii \
#        field_mapping_2D_BC_run2__unwarp_grad__${comp}.nii \
#        SC72 \
#    gradient_nonlin_unwarp.sh \
#        field_mapping_2D_BC_run2__${comp}.nii \
#        field_mapping_2D_BC_run2__unwarp_grad_nojac__${comp}.nii \
#        SC72 \
#        --nojac
#done
#
#matlab79 -nosplash -nodesktop -r "preprocess2; exit"


# 26  field_mapping_2D_BC  ok   64  64  60   1 212000-000026-000001.dcm
# 27  field_mapping_2D_BC  ok   64  64  60   1 899000-000027-000001.dcm
# 46  field_mapping_2D_BC  ok   64  64  60   1 351000-000046-000001.dcm
# 47  field_mapping_2D_BC  ok   64  64  60   1 227000-000047-000001.dcm

# RobF: this seems to be where the info used below is from
# /autofs/space/vault_020/users/I25_lh_B0_unwarping/mri4__2012_01_27/2012_01_27__I25_lh_B0_unwarp_8ch/meas_MID203_field_mapping_2D_BC_FID3681.hdr
# 14482 sRXSPEC.alDwellTime[0]                   = 8600
# 14483 sRXSPEC.alDwellTime[1]                   = 8600
# 14499 alTE[0]                                  = 2450
# 14500 alTE[1]                                  = 3470
# can't find sWiPMemBlock.adFree\[0\]
# 
# # mag
# grep -a RXSPEC...DwellTime ${DICOM_DIR}/*-000026-000001.dcm
# 
# # phz
# grep -a RXSPEC...DwellTime ${DICOM_DIR}/*-000027-000001.dcm
# 
# 
# grep -a 'alTE\[0\]' ${DICOM_DIR}/*-000026-000001.dcm
# grep -a 'alTE\[1\]' ${DICOM_DIR}/*-000026-000001.dcm
# grep -a 'sWiPMemBlock.adFree\[0\]' ${DICOM_DIR}/*-000026-000001.dcm
# 
# 
# # echo time reported in microseconds
# tediff=$(echo "scale=10; (3470 - 2450) / 10^6" | bc -l)
# 
# # dwell time reported in nanoseconds
# dwell=$( echo "scale=10; 2 * 8600 / 10^9" | bc -l)

# mag
grep -a RXSPEC...DwellTime fmap_dicoms/MR.1.3.12.2.1107.5.2.34.18001.2017051014360525745341432

# phz
grep -a RXSPEC...DwellTime fmap_dicoms/MR.1.3.12.2.1107.5.2.34.18001.2017051014360637283841911

fmap_mag=fmap_dicoms/MR.1.3.12.2.1107.5.2.34.18001.2017051014360525745341432

grep -a 'alTE\[0\]' $fmap_mag
grep -a 'alTE\[1\]' $fmap_mag
grep -a RXSPEC...DwellTime $fmap_mag
grep -a 'sWiPMemBlock.adFree\[0\]' $fmap_mag

# echo time reported in microseconds
tediff=$(echo "scale=10; (3210 - 2190) / 10^6" | bc -l)

# dwell time reported in nanoseconds
dwell=$( echo "scale=10; 2 * 2400 / 10^9" | bc -l)

#*********************************************************************#

# a(1) = arctan(1) = 45 degrees = pi/4 ...

twopi=$(echo "scale=10; 2 * 4*a(1)" | bc -l)
gamma=267510000 # rad/T
gammabar=42576000 # Hz/T

PREFIX=field_mapping_2D_BC_run1
# PREFIX=field_mapping_2D_BC_run1__unwarp_grad

prelude \
    -a ${PREFIX}__mag.nii \
    -p ${PREFIX}__phz.nii \
    -o ${PREFIX}__dph.nii \
    -f -v \
    --savemask=${PREFIX}__mask.nii

# for fun:
fslmaths ${PREFIX}__dph.nii.gz -div ${tediff} -div ${twopi} ${PREFIX}__Hz.nii
fslmaths ${PREFIX}__dph.nii.gz -div ${tediff} -div ${gamma} ${PREFIX}__Tesla.nii


# fugue expects two frames, so we fill one with zeros (c.f. doug's epidewarp.fsl)
fslmaths ${PREFIX}__dph.nii.gz -mul 0 ${PREFIX}__dph_zeros.nii.gz

fslmerge -t ph_${PREFIX}.nii.gz ${PREFIX}__dph_zeros.nii.gz ${PREFIX}__dph.nii.gz


# generate the voxel shift maps for each direction
for dir in x y z; do

    fugue \
        -i ${PREFIX}__mag.nii \
        -u ${PREFIX}__unwarp_B0__mag_${dir}.nii \
        -p ph_${PREFIX}.nii.gz \
        --dwell=${dwell} --asym=${tediff} \
        --unwarpdir=${dir}- \
        --mask=${PREFIX}__mask.nii.gz \
        --saveshift=vsm_run1__${dir}.nii.gz
        #--saveshift=vsm_run1__unwarp_grad__${dir}.nii.gz

done


###################################
# for grad non-linearity correction
###################################
# fieldmap is acquired with positive x readout, so must undistort it as well
for comp in real imag; do
    fugue \
        -i ${PREFIX}__${comp}.nii \
        -u ${PREFIX}__unwarp_B0__${comp}.nii \
        --loadshift=vsm_run1__x.nii.gz \
        --unwarpdir=x-
        #--loadshift=vsm_run1__unwarp_grad__x.nii.gz \
        #--unwarpdir=x-
done

matlab7.9 -nosplash -nodesktop -r "preprocess3; exit"

# calculate final, distortion-free unwrapped phase maps

prelude \
    -a ${PREFIX}__unwarp_B0__mag.nii \
    -p ${PREFIX}__unwarp_B0__phz.nii \
    -o ${PREFIX}__unwarp_B0__dph.nii \
    -f -v \
    --savemask=${PREFIX}__unwarp_B0__mask.nii

fslmaths ${PREFIX}__unwarp_B0__dph.nii.gz -div ${tediff} -div ${twopi} ${PREFIX}__unwarp_B0__Hz.nii
fslmaths ${PREFIX}__unwarp_B0__dph.nii.gz -div ${tediff} -div ${gamma} ${PREFIX}__unwarp_B0__Tesla.nii

