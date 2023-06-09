function [D,Dp] = createDwithMask(N1,N2,N3,msk,wt)
% Generates sparse finite difference (first-order neighborhoods) matrix operator D for an image of
% dimensions N1xN2xN3 such that it computes finite differences only using voxel inside the input
% mask i.e. boundary voxels (of mask or volume) for which the "forward" voxel lies outside
% mask/volume is not used.
%
% This function is memory efficient version (but probably slow to compute the operator) of
% createDNoBoundary3D() when finite difference has to be computed only inside a mask. 
% 
% wt is a weight vector of length 3, which represents weights along each dimension (due to possible
% differences of resolution). Optional input - when not defined same weight is applied to all dimension. 
%
% Dp is the transpose of D.

if (not(isreal(N1)&&(N1>0)&&not(N1-floor(N1))&&isreal(N2)&&(N2>0)&&not(N2-floor(N2))))
    error('Inputs must be real positive integers');
end

if ((N1==1)&&(N2==1)&&(N3==1))
    error('Finite difference matrix can''t be generated for a single-pixel image');
end

if ~isequal(size(msk), [N1, N2, N3])
   error('Mask size does not match!')
end

if ~exist('wt', 'var')
   wt = [1 1 1];
end

msk = msk>0; 
msk_ind = find(msk);
m = N1*N2*N3;

% D along dim 1
ind_incr = 1;
edge_mask = false(N1,N2,N3);
edge_mask(end,:,:) = true;
D = DinMask(msk_ind, edge_mask, ind_incr, m);

% D along dim 2
ind_incr = N1;
edge_mask = false(N1,N2,N3);
edge_mask(:,end,:) = true;
D2 = DinMask(msk_ind, edge_mask, ind_incr, m);

% D along dim 1
ind_incr = N1*N2;
edge_mask = false(N1,N2,N3);
edge_mask(:,:,end) = true;
D3 = DinMask(msk_ind, edge_mask, ind_incr, m);

D = [D.*wt(1); D2.*wt(2)];
clear D2;
D = [D; D3.*wt(3)];
clear D3;

% remove tonnes of zeros rows
temp = any(D,2);
D = D(temp,:);

if (nargout > 1)
    Dp = D';
end

clearvars -except D Dp
end

function D = DinMask(msk_ind, edge_mask, ind_incr, m)
edge_ind = find(edge_mask);
i = setdiff(msk_ind, edge_ind); % throw away volume edge voxels
clear edge_ind

Lia = ismember(i+ind_incr, msk_ind);
i = i(Lia);

s = ones(size(i));
j = [i; i+ind_incr];
i = [i; i];
s = [s; -s];
D = sparse(i,j,s,m,m);
clearvars -except D
end
