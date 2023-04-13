function varargout = mrir_nifti__save_header_mimic(data, filename, template, varargin)
%MRIR_NIFTI__SAVE_HEADER_MIMIC  save NIFTI file with header poached from existing file
%
% mrir_nifti__save_header_mimic(data, filename, template)

% jonathan polimeni <jonp@nmr.mgh.harvard.edu>, 2010/mar/19
% $Id: mrir_nifti__save_header_mimic.m,v 1.1 2012/08/29 22:04:13 jonp Exp $
%**************************************************************************%

  VERSION = '$Revision: 1.1 $';
  if ( nargin == 0 ), help(mfilename); return; end;


  %==--------------------------------------------------------------------==%

  if ( isstruct(template) ),
    nii.hdr = template;
  else,
    if ( ~exist(template, 'file') ),
      error('NIFTI file "%s" not found', template);
    end;

    nii.hdr = load_nii_hdr(template);

  end;


  nii.img = data;

  nii.hdr.dime.bitpix = 64;
  nii.hdr.dime.datatype = 64;

  if ( ~isreal(data) ),
    nii.hdr.dime.bitpix = 64
    nii.hdr.dime.datatype = 32
  end;
  
  save_nii(nii, filename);



  return;


  %************************************************************************%
  %%% $Source: /space/padkeemao/1/users/jonp/cvsjrp/PROJECTS/IMAGE_RECON/mrir_toolbox/mrir_nifti__save_header_mimic.m,v $
  %%% Local Variables:
  %%% mode: Matlab
  %%% fill-column: 76
  %%% comment-column: 0
  %%% End:



