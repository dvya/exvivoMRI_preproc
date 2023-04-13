function [y_nv, ymin] = locMinZeroSin(y_vec,min_on)
if nargin <2 
    min_on = 1;
end
    y_nv =y_vec;
    % local minima
    TF = find(islocalmin(y_vec'));
    if ~isempty(TF)
        [vmin,imin] = min(y_vec);
        if ~ismember(TF,imin) & imin ~= size(y_vec,2)
            TF=[];
            y_nv(imin +1:end) = 0;
            ymin = imin;                
        else
            y_nv(TF(1)+1:end) = 0;
            ymin = TF(1);
        end
    else
        if min_on == 1
        [vmin,imin] = min(y_vec);
        y_nv(imin +1:end) = 0;
        ymin = imin; 
        else
            y_nv = y_vec;
            ymin = length(y_nv); % need to think if this is the right thing to do
        end;
    end
end