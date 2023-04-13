
% jonathan polimeni <jonp@nmr.mgh.harvard.edu>
% Monday, January 30, 2012 12:33:56 -0500

% /autofs/cluster/exvivo/I25_lh_B0_unwarping/mri4__2012_01_27/unwarp/B0/fieldmap2D/preprocess1.m

addpath('/usr/local/freesurfer/dev/matlab')
% addpath('/autofs/space/neptune_001/users/srf29/matlab/gSlider_rob/library/Nifti_Analyze');

nii_mag = load_nifti('fmap2D_scanner_mag_vol1.nii.gz');
nii_pha = load_nifti('fmap2D_scanner_pha_float.nii.gz');

dims_mag = size(nii_mag.vol);
dims_pha = size(nii_pha.vol);

if dims_mag(3) ~= dims_pha(3)
    disp('unequal number of slices in fmap mag and phase!!!!')
    disp(dims_mag)
    disp(dims_pha)
    if dims_mag(3) == (1 + dims_pha(3))
        disp('there is one more slice in mag than phase - delete last slice')
	nii_mag.vol(:,:,end,:) = [];
	disp(size(nii_mag.vol,3))
    else
    	error('can''t fix the unequal number of slices... exiting')
    end
end

% pi/2047.5 = 0.00153435539
pha_max = max(nii_pha.vol(:));
pha_min = min(nii_pha.vol(:));

% possible pixel range of Siemens EPI phase images
expected_max = 4095;
expected_min1 = -4096;
expected_min2 = 0;

disp('')
disp(['phase should be : ' num2str(expected_min1) ' -> ' num2str(expected_max) ...
    ' OR ' num2str(expected_min2) ' -> ' num2str(expected_max) ])

if ((pha_max / expected_max) < 1.1) && ((pha_max / expected_max) > 0.9 )   
    disp(['max phase value ' num2str(pha_max) ' is close to ...' num2str(expected_max)])
else
    error(['phase max should be ~' num2str(expected_max) '!'])
end    

if ((pha_min / expected_min1) < 1.1) && ((pha_min / expected_min1) > 0.9 )
    disp(['min phase value ' num2str(pha_min) ' is close to ...' num2str(expected_min1)])
    
    nii_rad = ( nii_pha.vol ) * pi/4095; % -4096 -> 4095
    
elseif (pha_min >= 0) && (pha_min < 1000)
    disp(['min phase value ' num2str(pha_min) ' is close to ...' num2str(expected_min2)])
    
    nii_rad = ( nii_pha.vol - 2047.5 ) * pi/2047.5; % 0 -> 4095

else   
%     error(['phase min should be ~' num2str(expected_min1) ' or ' num2str(expected_min2) '!'])
    disp('********* ROB -----------')
    warning(['phase min should be ~' num2str(expected_min1) ' or ' num2str(expected_min2) '!'])
    disp(['min phase value ' num2str(pha_min) ' .... '])
    
%     nii_rad = ( nii_pha.vol ) * pi/4095; % -4096 -> 4095
    nii_rad = ( nii_pha.vol - 2047.5 ) * pi/2047.5; % 0 -> 4095
end    
disp('')

cplx = nii_mag.vol(:,:,:,1) .* exp(1i*nii_rad);

nii_mag.vol = abs(cplx);
nii_pha.vol = angle(cplx);

save_nifti(nii_mag, 'fmap2D__mag.nii.gz');
save_nifti(nii_pha, 'fmap2D__pha.nii.gz');

% also real and imag for grad nonlinearity correction
nii_real = nii_mag;
nii_imag = nii_mag;

nii_real.vol = real(cplx);
nii_imag.vol = imag(cplx);

save_nifti(nii_real, 'fmap2D__real.nii.gz');
save_nifti(nii_imag, 'fmap2D__imag.nii.gz');

%mrir_nifti__save_header_mimic(real(cplx), 'fmap2Dmatlab__real.nii', 'mag.nii');
%mrir_nifti__save_header_mimic(imag(cplx), 'fmap2Dmatlab__imag.nii', 'mag.nii');

%mrir_nifti__save_header_mimic(abs(cplx), 'fmap2Dmatlab__mag.nii', 'mag.nii');
%mrir_nifti__save_header_mimic(angle(cplx), 'fmap2Dmatlab__pha.nii', 'mag.nii');

%%
%nii_mag = load_nifti('field_mapping_2D_BC_run1__mag_vol1.nii');
%nii_phz = load_nifti('field_mapping_2D_BC_run1__phz_scanner.nii');
%
% pi/2047.5 = 0.00153435539
%nii_rad = ( nii_phz.vol - 2047.5 ) * 0.00153435539;
%
%cplx = nii_mag.vol(:,:,:,1) .* exp(i*nii_rad);
%
%mrir_nifti__save_header_mimic(real(cplx), 'field_mapping_2D_BC_run1__real.nii', 'field_mapping_2D_BC_run1__mag_vol1.nii');
%mrir_nifti__save_header_mimic(imag(cplx), 'field_mapping_2D_BC_run1__imag.nii', 'field_mapping_2D_BC_run1__mag_vol1.nii');
%
%mrir_nifti__save_header_mimic(abs(cplx), 'field_mapping_2D_BC_run1__mag.nii', 'field_mapping_2D_BC_run1__mag_vol1.nii');
%mrir_nifti__save_header_mimic(angle(cplx), 'field_mapping_2D_BC_run1__phz.nii', 'field_mapping_2D_BC_run1__mag_vol1.nii');
