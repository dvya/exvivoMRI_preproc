% Read csv file with commands for all subjects
function [path fa] = parseB1TxCSVfile(optsFile)
    if ~isempty(optsFile)
%         txt_cmd = dataread('file', optsFile, '%s', 'delimiter', '\n');
        fid = fopen(optsFile,'r')
        txt_cmd = textscan(fid, '%s', 'delimiter', '\n','delimiter', ',');
        txt_cmd = txt_cmd{1};
        fclose(fid);
        
        ind = 0;
        for num = 1:2:length(txt_cmd)
            ind = ind +1;
            path{ind,1} = txt_cmd{num,1};
            
            nst = find(txt_cmd{num+1,1}=='=');
            temp = txt_cmd{num+1,1};
            fa(ind,1) = str2num(temp(nst+1:end));
        end

    end
end