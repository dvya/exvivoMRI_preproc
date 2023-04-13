
% jonathan polimeni <jonp@nmr.mgh.harvard.edu>
% Monday, January 30, 2012 13:00:51 -0500

% /autofs/cluster/exvivo/I25_lh_B0_unwarping/mri4__2012_01_27/unwarp/B0/fieldmap2D/preprocess3.m



nii_real = load_nifti('fmap2D__unwarp_B0__real.nii.gz');
nii_imag = load_nifti('fmap2D__unwarp_B0__imag.nii.gz');

cplx = nii_real.vol + i*nii_imag.vol;

nii_mag = load_nifti('fmap2D__mag.nii.gz');
nii_pha = load_nifti('fmap2D__pha.nii.gz');

nii_mag.vol = abs(cplx);
nii_pha.vol = angle(cplx);

save_nifti(nii_mag, 'fmap2D__unwarp_B0__mag.nii.gz');
save_nifti(nii_pha, 'fmap2D__unwarp_B0__pha.nii.gz');
