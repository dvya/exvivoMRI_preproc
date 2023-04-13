%% Ex vivo pre-processing pipeline
%% Divya Varadarajan 06/03/2019

function [status, err] = ex_vivo_preprocess(varargin)

%% Dependencies - hacky, instead create a dependences folder with all the files.
addpath(genpath('./'))

%% setup
opts = evpp_setup(varargin{:});

%% read scan parameters from hres path
disp(opts.hres);
[path,fa,te,tr] = parseHresCSVfile(opts.hres);

%% Loop FA and apply artifact corrections
if opts.b0Corr
    for nFA = 1:length(fa),

        % Load all echoes of hres MRI
        disp(['Loading  flip angle ' num2str(fa(nFA))]);
        [data, data_e0_nii,hres_nii_path] = load_me_hres_flash(path{nFA},opts.op);
        %data_e0_nii.img = []; % Just getting the header might be more elegant, but there are other field and we delete img to save space.

        % Create Brain mask - its okay if PLP is included here. We just need to
        % eliminate noise.
%         disp('Creating mask');
%         mask = createMask(data,data_e0_nii,opts.op,opts.opname);

        % B0 : joint correction
        disp('B0 inhomogeneity correction ...')
        applyB0Corr(path{nFA},data,data_e0_nii,hres_nii_path,opts.ro_polarity,te(nFA,:),tr(nFA),fa(nFA),opts.dcm_mag,opts.dcm_ph,opts.dcm_im, opts.op,opts.opname);

        % Denoise

        % Gradient non-linearity
    end
else
	disp(['Loading  flip angle ' num2str(fa(1))]);
        [data, data_e0_nii] = load_me_hres_flash(path{1},opts.op);
        %data_e0_nii.img = []; % Just getting the header might be more elegant, but there are other field and we delete img to save space.
end

%% Parameter maps
% B1+ (Tx)
if ~isempty(opts.b1TxFile)
    disp('Estimating flip angle map (B1 transmit correction)')
    saveB1Tx(opts.b1TxFile,data_e0_nii,opts.op,opts.opname);
end

% mris_ms_fitparms
% system(['mris_ms_fitparms'])

% B1- (Rx)
% if opts.b1Rx_on
%     disp('')
%     if ~isempty(opts.headCoil) && ~isempty(opts.bodyCoil) 
%         [data,datapath] = applyB1RxCorr(opts.rxcoil,opts.txcoil,data,data_nii,mask,opts.op,opts.opname);
%     else
%         % Not supported yet!
% %             applyB1RxCorr_LPF(opts.rxcoil,opts.txcoil,data,data_nii,opts.op,opts.opname);
%     end
% end
