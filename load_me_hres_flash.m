function [data, data_e0_nii,hres_nii_path] = load_me_hres_flash(path,op,save_on)
    if nargin<3
        save_on =1;
    end
    
    echo_files = dir([path '/echo*_whitened_rms.mgh']);
    if isempty(echo_files)
        mef_files = dir([path '/mef*']);
    end
    
    if ~isempty(echo_files)
        for ne = 1:length(echo_files)
            dname = echo_files(ne).name;
            disp(['Image file: ' dname]);
            data(:,:,:,ne) = load_mgh([path '/' dname]);
        end
        if save_on == 1
            dname = 'echo0_whitened_rms';
            if ~exist([op '/' dname '.nii.gz'])
                system(['mri_convert ' path '/' dname '.mgh ' op '/' dname '.nii.gz']);
            end
            data_e0_nii = load_untouch_nii_gz([op '/' dname '.nii.gz']);
            hres_nii_path = [op '/' dname '.nii.gz'];
        else
            data_e0_nii = [];
            hres_nii_path =[];
        end

    elseif ~isempty(mef_files)
        dname = mef_files(1).name;
        disp(['Image file: ' dname]);
        data_nii = load_untouch_nii_gz([path '/' dname]);
        data = data_nii.img;
        dname = 'mef0_whitened_rms';
        if ~exist([op '/' dname '.nii.gz'])
            data_e0_nii = data_nii;
            data_e0_nii.hdr.dime.dim(5) = 1;
            data_e0_nii.hdr.dime.dim(1) = 3;
            data_e0_nii.img = data(:,:,:,1);
            save_untouch_nii_gz(data_e0_nii,[op '/' dname '.nii.gz']);
            hres_nii_path = [op '/' dname '.nii.gz'];
        else
            data_e0_nii = load_untouch_nii_gz([op '/' dname '.nii.gz']);
            hres_nii_path = [op '/' dname '.nii.gz'];
        end
    else
        disp(['Files missing: Could not find mef/meflash/echo files at ' path ' Please check your input paths.'])
    end
end