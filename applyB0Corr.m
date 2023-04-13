function applyB0Corr(hres_path,data,data_e0_nii,hres_nii_path,ro_polarity,te,tr,fa,dcm_mag,dcm_pha,dcm_im,op,opname)

disp('Beginning B0 correction...');
calc_vsm = 1; % for future
op = [op '/'];
te = te*10^-3;

%% T2star estimate
op_pos= [op opname '_parameter_maps_e02/'];
op_neg= [op opname '_parameter_maps_e13/'];

mkdir(op_pos);
system(['mri_ms_fitparms -n 0 -tr ' num2str(tr) ' -te ' num2str(te(1)*1000) ' -fa ' num2str(fa) ' ' hres_path '/echo0_whitened_rms.mgh -tr ' num2str(tr) ' -te ' num2str(te(3)*1000) ' -fa ' num2str(fa) ' ' hres_path '/echo2_whitened_rms.mgh ' op_pos]);

mkdir(op_neg);
system(['mri_ms_fitparms -n 0 -tr ' num2str(tr) ' -te ' num2str(te(2)*1000) ' -fa ' num2str(fa) ' ' hres_path '/echo1_whitened_rms.mgh -tr ' num2str(tr) ' -te ' num2str(te(4)*1000) ' -fa ' num2str(fa) ' ' hres_path '/echo3_whitened_rms.mgh ' op_neg]);

% Load and synthesize:
tic
t2pos = load_mgh([op_pos 'T2star.mgz']);
t2neg = load_mgh([op_neg 'T2star.mgz']);
toc

%% mask for high resolution image
disp('Creating mask...')
mask_mag = data_e0_nii.img;
th = median(data_e0_nii.img(:)); %+ std(data_e0.img(:));
mask_mag(data_e0_nii.img<th) = 0;
mask_mag(data_e0_nii.img>=th) = 1;

mask_mag = medfilt3(mask_mag);
mask_mag = medfilt3(mask_mag);
%     display_volume(mask_mag);
disp('Mask created...');

%% VSM - call FSL FUGUE
disp('Calling FUGUE to calculate the shift map...')
if calc_vsm == 1
    addpath(genpath('flashFieldmapScripts'));
    
    % prepare the fieldmap
    op_fmap = [op opname '_fmap'];
    mkdir(op_fmap);
    GradNonLin = 'no';
    curr = pwd;
    cd(op_fmap);
    system(['flashFieldmapScripts/fmap_prep_1dwell.sh ' dcm_mag ' ' dcm_pha ' ' GradNonLin]);
    
%     op_fmap = [op opname '_fmap'];
%     mkdir(op_fmap);
%     movefile('./vsm_fmap2D*', op_fmap);
%     movefile('./ph_fmap2D*', op_fmap);
%     movefile('./fmap2D*', op_fmap);
%     movefile('./params*.txt',op_fmap);
    
    % $0 <nii_im> <dcm_fmap> <dcm_im> <Dfmap> <dir> <readout> <GradNonLin>
    nii_im = hres_nii_path;
    dcm_fmap = dcm_mag;
    Dfmap = op_fmap;
    opdir = op_fmap;
    dir = 'x';
    readout = 'pos';
    system(['flashFieldmapScripts/fmap_save_vsm.sh ' nii_im ' ' dcm_fmap ' ' dcm_im ' ' Dfmap ' ' dir ' ' readout ' ' GradNonLin ' ' opdir]);
    
    % $0 <nii_im> <dcm_fmap> <dcm_im> <Dfmap> <dir> <readout> <GradNonLin>
    readout = 'neg';
    system(['flashFieldmapScripts/fmap_save_vsm_no_v2v.sh ' nii_im ' ' dcm_fmap ' ' dcm_im ' ' Dfmap ' ' dir ' ' readout ' ' GradNonLin ' ' opdir]);
    cd(curr);
end

opdir = [op opname '_fmap'];
epol_Kpos_fugue = load_untouch_nii_gz([opdir '/vsm_x_freqshift_dwellscale_pos.nii.gz']);

%% All initializations and options for the optimization
rho_e0 = data(:,:,:,1);
rho_e1 = data(:,:,:,2);
rho_e2 = data(:,:,:,3);
rho_e3 = data(:,:,:,4);
clear data;
N_echo = 4;

N_rd = size(rho_e0,1);
N_pe = size(rho_e0,2);
N=N_rd*N_pe; % 2 multipled for topup

% [D] = createDWithPeriodicBoundary_diffusionJointReconstruction_VD(N_rd,N_pe);
% Dp = D';
[D] = createDWithPeriodicBoundary_diffusionJointReconstruction_VD(N_rd,N_pe);

% D  = [D,sparse(2*N,N);sparse(2*N,N),D]; % sparse([],[],[],2*N,2*N);sparse([],[],[],2*N,2*N),D sparse([],[],[],2*N,N); sparse([],[],[],2*N,3*N),D];
Dp = D';

% Heuristic method from Justin Haldar's paper
wb = 1./exp(-te/0.02);
wb = wb/sum(wb);
wb = wb';
wb = sqrt(wb(:));
% wb = [1 1 1 1]';
wb = wb/norm(wb);

med = median(abs(rho_e3(mask_mag == 1)));
med = median(abs(rho_e3(abs(rho_e3(:))>med)));
med = median(abs(rho_e3(abs(rho_e3(:))>med)));
ep =0.05;
xi = ep*med*min(wb);

% numbers recommended in haldar et al, MRM 2013
numIter = 20;
cgIter = 50;
tol = 1e-8;
lambda = 0.5; %0.02*sqrt(N_echo);

for nslice = 1:size(rho_e0,3), % this is specific for I51 to make it faster
    nslice
    % B0 distortion image
    tic
    [~, Kpos] = EPI_distort_fieldmap_image_withshiftmap(rho_e0(:,:,nslice), 1, 1,epol_Kpos_fugue.img(:,:,nslice));
    [~, Kneg] = EPI_distort_fieldmap_image_withshiftmap(rho_e1(:,:,nslice), 1, 1, -epol_Kpos_fugue.img(:,:,nslice));
%     toc
% tic
    synth_echo(:,:,1) = synthesizeOppPolarity(te(1),t2neg(:,:,nslice),te(2),rho_e1(:,:,nslice),rho_e0(:,:,nslice));
    synth_echo(:,:,2) = synthesizeOppPolarity(te(2),t2pos(:,:,nslice),te(1),rho_e0(:,:,nslice),rho_e1(:,:,nslice));
    synth_echo(:,:,3) = synthesizeOppPolarity(te(3),t2neg(:,:,nslice),te(2),rho_e1(:,:,nslice),rho_e2(:,:,nslice));
    synth_echo(:,:,4) = synthesizeOppPolarity(te(4),t2pos(:,:,nslice),te(1),rho_e0(:,:,nslice),rho_e3(:,:,nslice));
    
    r0 = double([vect(rho_e0(:,:,nslice)) vect(rho_e1(:,:,nslice)) vect(rho_e2(:,:,nslice)) vect(rho_e3(:,:,nslice))]);
    r0_synth = (r0 + double(reshape(synth_echo,[],N_echo)))/2;
    
    y_acq = double([vect(rho_e0(:,:,nslice)) vect(rho_e1(:,:,nslice)) vect(rho_e2(:,:,nslice)) vect(rho_e3(:,:,nslice))]);
    y_acq_synth = [r0 ;double(reshape(synth_echo,[],N_echo))];
    
    clear rK;
    clear r0;
 
%     tic
    err = 100;
    while err > 1e-3
        %line process  
     d = zeros(N_rd*N_pe*2,1);
     for ne = 1:N_echo,
        d =d + abs(D*double(r0_synth(:,ne))*wb(ne)).^2;
     end    
        t = sqrt(d);
        w = zeros(size(t));
        w(t<=xi) = 1;
        w(t>xi) = xi./t(t>xi);
        
        % optimal solution
        for ne = 1:N_echo
            if ro_polarity == 'neg'
                if mod(ne,2) ~= 0
                    Kmat = [Kneg;Kpos];
                else
                    Kmat = [Kpos;Kneg];
                end
            else
                if mod(ne,2) == 0
                    Kmat = [Kneg;Kpos];
                else
                    Kmat = [Kpos;Kneg];
                end 
            end
            Kpmat = Kmat';
            [rK_synth(:,ne),fl1,rr1,it1,rv1] = pcg(@(x) Kpmat*(Kmat*x)  + lambda*(Dp*(w.*(D*x))), Kpmat*y_acq_synth(:,ne),tol,cgIter,[],[],r0_synth(:,ne));            
            rK_synth(rK_synth<0) = 0;
%             d = d + abs(D(1:2*N,1:N)*double(rK_synth(:,ne))*wb(ne)).^2 - abs(D(1:2*N,1:N)*double(r0_synth(:,ne))*wb(ne)).^2;
        end
        err = norm(rK_synth - r0_synth)/norm(r0_synth);
        r0_synth =rK_synth;
    end

    corr_synth(nslice,:,:,:) = reshape(rK_synth,[size(rho_e0(:,:,nslice),1) size(rho_e0(:,:,nslice),2) 4]);
    toc    
    
end;

corr_synth = permute(corr_synth,[2 3 1 4]);
nii_corr = data_e0_nii;
for ne = 1:N_echo,
    nii_corr.img = corr_synth(:,:,:,ne);
    save_untouch_nii_gz(nii_corr, [op 'echo' num2str(ne-1) '_whitened_rms_b0Corr_ep0' num2str(100*ep) '_lp' num2str(lambda*10) '_FA' num2str(fa) '.nii.gz']);
end
rms = sqrt(sum(corr_synth.^2,4));
nii_corr.img = rms;
save_untouch_nii_gz(nii_corr, [op 'FA' num2str(fa) '_echorms_b0Corr.nii.gz']);

rms_orig = sqrt(rho_e0.^2 + rho_e1.^2 + rho_e2.^2 + rho_e3.^2);
nii_corr.img = rms_orig;
save_untouch_nii_gz(nii_corr, [op 'FA' num2str(fa) '_echorms_orig.nii.gz']);
end
