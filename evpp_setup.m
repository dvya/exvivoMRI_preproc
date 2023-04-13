function opts = evpp_setup(varargin)
disp('Reading input flags...')

% Default options struct
opts.hres = '';
opts.b1TxFile = '';
opts.op = 'output_dir';
opts.opname = 'op';
opts.rxcoil = '';
opts.txcoil = '';
opts.dcm_mag = '';
opts.dcm_ph = '';
opts.dcm_im = '';
opts.b0Corr = 0;
opts.ro_polarity = 'pos';
opts.use_topup = 0;
opts.run_topup = 0;
opts.topup_dir = opts.op;
opts.bw_per_pixel = 0;
opts.nPools = 20;
opts.mri_synth = 0;
opts.rout_dim = 1; % what is set in hemi, changes for infant scans to 2.
opts.tissue_type='adultHemi120um';

% Parsing flags
flag_cell = varargin;
nflags = nargin;
iflag = 1;
while(iflag < nflags)
     inpt = strtrim(lower(flag_cell{iflag}));
     
     switch inpt
          case '--hres'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--hres must be followed by the name of CSV file containing list of folders of all the high-res FLASH MRIs to be processed and their flip angles: : <FLASH MRI path> 30']);
             else
                % clean up input subdir
                opts.hres = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
                if opts.hres(end)=='/' || opts.hres(end)=='\'
                   opts.hres = opts.hres(1:end-1);
                end
             end
         case '--output-subdir'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--output-subdir must be followed by the name of the output folder.']);
             else
                % clean up input subdir
                opts.op = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
                if opts.op(end)=='/' || opts.op(end)=='\'
                   opts.op = opts.op(1:end-1);
                end
             end
        case '--output-name'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--output-name must be followed by the name that will be uses as prefix for all results.']);
             else
                opts.opname = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
             end
        case '--tissue_type'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--tissue_type must be followed by the keyword for the tissue.']);
             else
                opts.tissue_type = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
             end
         case '--mask'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--mask must be followed by the path to the brain mask file. Currently only.mgh/.mgz formats are supported.']);
             else
                % clean up input subdir
                opts.txcoil = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
                if opts.txcoil(end)=='/' || opts.txcoil(end)=='\'
                   opts.txcoil = opts.txcoil(1:end-1);
                end
             end             
         case '--fmap_mag'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--fmap_mag must be followed by the name of the field map magnitude dicom.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                opts.dcm_mag = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
             end
         case '--fmap_ph'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--fmap_ph must be followed by the name of the field map phase dicom.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                opts.dcm_ph = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
             end
         case '--im_hdr'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--im_hdr must be followed by the name of the hires header.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                opts.dcm_im = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
             end
         case '--readout_dim'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--bw_per_pixel must be followed readout dimension.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                opts.rout_dim = (flag_cell{iflag+1});
                iflag = iflag + 1;
             end
         case '--ro_polarity'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--fmap must be followed by the name of the hires header.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                opts.ro_polarity = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
             end      
         case '--mri_synth'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--mri_synth must be followed by 0 or 1.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                disp(class((flag_cell{iflag+1})));
                opts.mri_synth = (flag_cell{iflag+1});
                iflag = iflag + 1;
             end             
         case '--run_topup'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--use_topup must be followed by 1 or 0.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                opts.run_topup = (flag_cell{iflag+1});
                iflag = iflag + 1;
             end
         case '--use_topup'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--use_topup must be followed by 1 or 0.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                opts.use_topup = (flag_cell{iflag+1});
                iflag = iflag + 1;
             end         
         case '--bw_per_pixel'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--bw_per_pixel must be followed BW per pixel value.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                opts.bw_per_pixel = (flag_cell{iflag+1});
                iflag = iflag + 1;
             end
         case '--topup_dir'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--topup_dir must be followed by the name of the topup output folder.']);
             else
                % clean up input subdir
                opts.topup_dir = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
                if opts.topup_dir(end)=='/' || opts.topup_dir(end)=='\'
                   opts.topup_dir = opts.topup_dir(1:end-1);
                end
             end
         case '--b1tx'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--B1Tx must be followed by the name of CSV file containing list of folders containing GRE scans'...
                ' and the corresponding flip angle in degrees: <GRE path> 30']);
             else
                opts.b1TxFile = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
                if opts.b1TxFile(end)=='/' || opts.b1TxFile(end)=='\'
                   opts.b1TxFile = opts.b1TxFile(1:end-1);
                end
             end
         case '--headCoil'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--rxcoil must be followed by the path to the receive coil MRI (head coil). Currently only.mgh/.mgz formats are supported.']);
             else
                % clean up input subdir
                opts.rxcoil = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
                if opts.rxcoil(end)=='/' || opts.rxcoil(end)=='\'
                   opts.rxcoil = opts.rxcoil(1:end-1);
                end
             end
        case '--bodyCoil'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--txcoil must be followed by the path to the transmit coil MRI (body coil). Currently only.mgh/.mgz formats are supported.']);
             else
                % clean up input subdir
                opts.txcoil = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
                if opts.txcoil(end)=='/' || opts.txcoil(end)=='\'
                   opts.txcoil = opts.txcoil(1:end-1);
                end
             end
        case '--nPools'
             if (iflag+1 > nflags)
                error('ExVivoPreProcess : FlagError',['--nPools must be followed by numeric value.']);
             else
                opts.b0Corr = opts.b0Corr + 1; 
                opts.nPools = deblank(flag_cell{iflag+1});
                iflag = iflag + 1;
             end             
     end
     iflag = iflag+1;
end

if ~exist(opts.op,'dir')
    mkdir(opts.op);
end

if opts.b0Corr < 4 && opts.b0Corr > 0 
    disp('Warning: Have you provided all fieldmap/topup inputs and hires header for b0 correction? System detected less than 4 inputs.');
end

ro_chk = strcmp(opts.ro_polarity,{'h_pos','wb_neg','h_neg','wb_pos'}); 

if ro_chk(1) || ro_chk(2)
    opts.ro_polarity = 'pos';
end

if ro_chk(3) || ro_chk(4)
    opts.ro_polarity = 'neg';
end

end