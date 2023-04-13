function fmap_out = checkScanFOV(epi_in, fmap_in, epi_output_filename, options)
% check overlap of fieldmap and epi_data and returns the fieldmap data resampled in coordinate of
% epi_data

vox_diff_allowed = 1; % voxel difference allowed in FOV
[~, X_vol1, Y_vol1, Z_vol1, res1, Tvol1] = get_original_grid_data(epi_in);
[~, ~, ~, ~, res2, Tvol2] = get_original_grid_data(fmap_in);

if options.checkFOV && (~isequal(size(epi_in.img), size(fmap_in.img)) || norm(Tvol1(:)-Tvol2(:))>1e-2)
   
%    msg = {'\n', ['Fieldmap and EPI (diffusion) scan have different headers/acquisition scheme. '...
%       'PNG images showing their overlay will be generated with name: ' escape_filename(overlay_fname)], ...
%       '\n', ['It is *highly* recommended to check the overlay images to make sure fieldmap and EPI data '....
%       'overlap correctly. Input fieldmap scan should be pre-registered to EPI (diffusion) image for '...
%       'fieldmap-based correction. '], '\n'};
%    fprintf(bdp_linewrap(msg));
   
   if ~isempty(options.mask)
      msk = load_untouch_nii_gz(options.mask);
   else
      sz = size(epi_in.img);
      msk.img = true(sz(1:3));
   end
   
   if ~isempty(options.b0_file)
      b0 = load_untouch_nii_gz(options.b0_file, true);
   else
      b0.img = epi_in.img(:,:,:,1);
   end
   
   c(1,:) = X_vol1(msk.img>0);
   c(2,:) = Y_vol1(msk.img>0);
   c(3,:) = Z_vol1(msk.img>0);
   c(4,:) = 1;
   if size(c,2)>10^7
       ptvol = pinv(Tvol2);
       c = ptvol*c;
   else
        c = Tvol2\c;
   end;
   c_min = transpose(min(c,[],2)); c_min(end) = [];
   c_max = transpose(max(c,[],2)); c_max(end) = [];
   
   fmap_out = myreslice_nii(fmap_in, 'linear', X_vol1, Y_vol1, Z_vol1);
   fmap_sz = size(fmap_in.img);
   
   if options.overlay_on == 1
       fm_norm = normalize_intensity(fmap_out, [8 92], msk.img>0);
       epi_norm = normalize_intensity(b0.img(:,:,:,1), [8 96], msk.img>0);
       
       if size(epi_norm,3) <= 100 
           overlay_fname = [remove_extension(epi_output_filename) '.fielmap_overlay'];
           overlay_volumes2png(fm_norm, epi_norm, [0 1], overlay_fname, 'rview', [85 100]);
       else
           nvol = floor(size(epi_norm,3)/100);
           for num = 1:nvol
               num
               overlay_fname = [remove_extension(epi_output_filename) '_' num2str(num) '.fielmap_overlay'];
               overlay_volumes2png(fm_norm(:,:,(num-1)*100 +1:num*100), epi_norm(:,:,(num-1)*100 +1:num*100), [0 1], overlay_fname, 'rview', [85 100]);
           end;
           overlay_fname = [remove_extension(epi_output_filename) '_' num2str(nvol+1) '.fielmap_overlay'];
           overlay_volumes2png(fm_norm(:,:,nvol*100 +1:end), epi_norm(:,:,nvol*100 +1:end), [0 1], overlay_fname, 'rview', [85 100]);
       end
       clear fm_norm epi_norm

       if min(c_min)<(-vox_diff_allowed) || min(fmap_sz-c_max)<(1-vox_diff_allowed) % Allow one voxel differences due to partial volume errors
          num_vox_outside = sum( c(1,:)<-0.5 | c(2,:)<-0.5 | c(3,:)<-0.5 |...
             c(1,:)>fmap_sz(1)-0.5 | c(2,:)>fmap_sz(2)-0.5 | c(3,:)>fmap_sz(3)-0.5 );

          if options.ignore_FOV_errors
             msg = {'\n', ['EPI (diffusion) field of view (FOV) is not totally covered by input fieldmap. '...
                'Number of voxels in EPI (diffusion) scans outside FOV of fieldmap: ' num2str(num_vox_outside) '. ' ...
                'But --ignore-fieldmap-FOV is detected. So, BDP will ignore it and continue. '...
                'However, BDP has saved some images (.png files) which show the overlay of EPI (diffusion) data and fieldmap. '...
                'It is *highly* recommended to check the overlay images and make sure fieldmap and EPI (diffusion) data '...
                'overlap resonably. Input fieldmap scan should be pre-registered to EPI image for fieldmap-'...
                'based correction.\n']};
             fprintf(bdp_linewrap(msg));
          else
             msg = ['\nEPI (diffusion) field of view (FOV) is not totally covered by input fieldmap. '...
                'Number of voxels in EPI (diffusion) scans outside FOV of fieldmap: ' num2str(num_vox_outside) '. ' ...
                'BDP has saved some images (.png files) which show the overlay of EPI (diffusion) data and fieldmap. '...
                'Please check these overlay images and make sure that fieldmap file has correct header. '...
                'Input fieldmap scan should be pre-registered to EPI (diffusion) image for fieldmap-based correction. '...
                'If you think that you got this error in mistake then you can suppress this error by '...
                're-running BDP and appending flag --ignore-fieldmap-FOV.\n'];
             error('BDP:InsufficientFieldmapFOV', bdp_linewrap(msg));
          end
       end
   end;
else
   fmap_out = myreslice_nii(fmap_in, 'linear', X_vol1, Y_vol1, Z_vol1);
end
end


function [epi_out, shift] = EPI_correct_fieldmap_pixelshift(epi_vol, epi_res, deltaB0, echo_space, intensity_correct, method)
% epi_vol - 3D EPI volume, with 1st dimension as phase encode & second dimension as readout direction
% deltaB0 - in Hz; 3D volume (dimensions same as epi_vol)
% echo_spacing  - in sec
% epi_res - vector of length three

sz = size(epi_vol);
shift = double(deltaB0) * sz(1) * double(echo_space); % in voxels

% warp EPI
[x_g, y_g, z_g] = ndgrid(1:sz(1), 1:sz(2), 1:sz(3));
x_warp = x_g + shift;
epi_out = interpn(double(epi_vol), x_warp, y_g, z_g, method, 0);

if intensity_correct
   [~, grad_x, ~] = gradient(shift*epi_res(1), epi_res(1), epi_res(2), epi_res(3));
   epi_out = epi_out.*(1+grad_x);
end
end
