function status = saveB1Tx(b1TxFile, hres_nii, op, opname)
% read filenames and flip angles
[path fa] = parseB1TxCSVfile(b1TxFile);

% load data
ind=0;fv=[];
Nfiles = size(fa,1);

for nS = 1:Nfiles,
    gre_name = dir([path{nS} '*.mgz']);
    disp(['Reading ' gre_name.name])
    ind = ind+1;
    
    [I m1,m2] = load_mgh([path{nS} gre_name.name]);
    ymag(:,:,:,ind) = I;
end
nsamp = ind;

% mask - heuristic, might need to change
mask = ymag(:,:,:,1);
mask(mask < prctile(mask(:),70)) = 0; 
mask(mask ~=0) =1;

% Estimate B1+ map
for nSlice =1:size(ymag,3),
    y = ymag(:,:,nSlice,:); %.* 
    y_vec = reshape(y, [], nsamp);
    mask_vec = mask(:,:,nSlice); mask_vec = mask_vec(:);
    
    for nv = 1: size(y_vec,1)
        if mask_vec(nv) == 1,
            [y_nv ind(nv,nSlice)] = locMinZeroSin(y_vec(nv,3:end),0);
            y_nv = [y_vec(nv,1:2) y_nv]; ind(nv,nSlice) = ind(nv,nSlice) + 2;
            if ind(nv,nSlice) > 1
                [t1Image(nv,nSlice), AImage(nv,nSlice), KImage(nv,nSlice)] = t1EstimateVarproVFA2NonLinear_singleTR(y_nv(1:ind(nv,nSlice))', deg2rad(fa(1:ind(nv,nSlice))), 5, 1,0.1:0.001:3);
            else
                t1Image(nv,nSlice)=0;
                AImage(nv,nSlice)= 1;
                KImage(nv,nSlice)= 0;
            end
        else
            t1Image(nv,nSlice)= 0;
            AImage(nv,nSlice) = 1;
            KImage(nv,nSlice) = 0;
        end
    end
    nSlice
end

% save B1+ map
save_mgh(reshape(AImage,size(mask)),[op '/' opname '_B1Txmap.mgz'],m1,m2);
mov_nii = [op '/' opname '_B1Txmap.nii.gz'];
system(['mri_convert ' op '/' opname '_B1Txmap.mgz ' mov_nii]);

% Mask and Extrapolate
mask_eroded = erode3d(mask, 2);
% b1Tx_epol_sm = extrapolateInVolSmooth(reshape(AImage,size(mask)), mask_eroded, [2 2 2],4);
b1Tx_epol = extrapolateInVol(reshape(AImage,size(mask)), mask_eroded, [2 2 2],4);
% save_mgh(b1Tx_epol_sm,[op '/' opname '_B1Txmap_epol_sm.mgz'],m1,m2);
save_mgh(b1Tx_epol,[op '/' opname '_B1Txmap_epol.mgz'],m1,m2); 

% mov_epol_sm_nii = [op '/' opname '_B1Txmap_epol_sm.nii.gz'];
% system(['mri_convert ' op '/' opname '_B1Txmap_epol_sm.mgz ' mov_epol_sm_nii]);
mov_epol_nii = [op '/' opname '_B1Txmap_epol.nii.gz'];
system(['mri_convert ' op '/' opname '_B1Txmap_epol.mgz ' mov_epol_nii]);

% Interpolate B1+ map to high resolution
options = struct(...
'b0_file', [], ...
'mask', [], ...
'checkFOV', true, ... when false, completely skips FOV checks
'ignore_FOV_errors', false, ...
'overlay_on', 0);

% dst_nii = [op opname '_highres.nii.gz'];
% system(['mri_convert ' hres ' ' dst_nii]);
% nii_1 = load_untouch_nii_gz(dst_nii);

% nii_2 = load_untouch_nii_gz(mov_nii);
% b1Tx_resamp = checkScanFOV(hres_nii, nii_2, [op opname '_checkFov'], options);
% b1_tx_nii = hres_nii;
% b1_tx_nii.img = b1Tx_resamp;
% save_untouch_nii_gz(b1_tx_nii,[op '/' opname '_B1Txmap_resamp.nii.gz']);
% 
% nii_2 = load_untouch_nii_gz(mov_epol_sm_nii);
% b1Tx_resamp = checkScanFOV(hres_nii, nii_2, [op '/' opname '_checkFovEpolSm'], options);
% b1_tx_nii = hres_nii;
% b1_tx_nii.img = b1Tx_resamp;
% save_untouch_nii_gz(b1_tx_nii,[op '/' opname '_B1Txmap_resamp_epol_sm.nii.gz']);

nii_2 = load_untouch_nii_gz(mov_epol_nii);
b1Tx_resamp = checkScanFOV(hres_nii, nii_2, [op '/' opname '_checkFovEpol'], options);
b1_tx_nii = hres_nii;
b1_tx_nii.img = b1Tx_resamp;
disp(['Saving ' op '/' opname '_B1Txmap_resamp_epol.nii.gz']);
save_untouch_nii_gz(b1_tx_nii,[op '/' opname '_B1Txmap_resamp_epol.nii.gz']);
disp('Done.');
disp('B1 transmit map saved.')
end