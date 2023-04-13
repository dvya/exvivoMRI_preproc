function [t1Image, AImage, KImage] = t1EstimateVarproVFA2NonLinear_singleTR(imageStack, alphaValues, trValue, ...
   possibleT1Values, possibleAvalues)
%--------------------------------------------------------------------------
% Fits the model (in a least-squares sense):
% S(tr) = K*(1-e^(-TR/T1))./(1-cos(A*alpha)*e^(-TR/T1))*sin(A*alpha)
%--------------------------------------------------------------------------

numVox = size(imageStack,2);
numObs = size(imageStack,1);

possibleR1Values = 1./possibleT1Values(:);
[alpha, R1s, Avals] = ndgrid(alphaValues(:), possibleR1Values(:), possibleAvalues(:));
Tcolumn1 = (1-exp(-trValue*R1s)) ./ (1-(cos(Avals.*alpha).*exp(-trValue*R1s))) .* sin(Avals.*alpha);

numT1 = length(possibleR1Values(:));
numA = length(possibleAvalues(:));
numPParam = numT1*numA;

bigTmatrix = zeros(numPParam*numObs, numObs);
bigcnt = 1;
for iA = 1:numA
   for iT1 = 1:numT1
      Tmatrix = vect(Tcolumn1(:,iT1,iA));
      [q,~] = qr(Tmatrix,0);
      bigTmatrix(1+(bigcnt-1)*numObs:bigcnt*numObs, :) = q*q';
      bigcnt = bigcnt+1;
   end
end

indices = zeros(numVox,1);
for iVox = 1:numVox
   costVal = sum(abs(reshape(bigTmatrix*imageStack(:,iVox), numObs, numPParam).^2), 1);
   [~, indices(iVox)] = max(costVal(:),[],1);
end

Aind = ceil(indices./numT1);
T1ind = indices - ((Aind-1).*numT1);
t1Image = possibleT1Values(T1ind);
AImage = possibleAvalues(Aind);AImage = AImage';

if nargout>2
   KImage = zeros(numVox,1);
   for iVox = 1:numVox
      Tmatrix = vect(Tcolumn1(:,T1ind(iVox), Aind(iVox)));
      KImage(iVox) = Tmatrix\imageStack(:,iVox);
   end
end

end

function out = vect(in)
out=in(:);
end
