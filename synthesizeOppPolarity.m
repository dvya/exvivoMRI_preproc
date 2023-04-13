function synth_echo = synthesizeOppPolarity(te,t2,tenorm,rhoNorm,rho,mask)
%         th=0; see comment below. This is for the future.
    if nargin<6
        mask=ones(size(t2));
    end
    S = exp(-tenorm*1000./t2); 
    N = double(rhoNorm)./S;
%     R = double(rhoNorm);

    synth_echo = exp(-te*1000./t2).*N;
    temp = synth_echo;
    temp (t2 == 0) = rhoNorm(t2 == 0); % do we need this for fomblin?
    

    %    Might need to add more for fomblin or plp bag edges. 
%   One idea could be be informed from the fielmap and to maintain same
%   value in regions of no or very mild distortions.
%     if th == 1     
%         temp (t2 == 0 & mask == 1) = rho(t2 == 0 & mask == 1);
%         temp(t2>100) = rho(t2>100)
%     end
    synth_echo = temp;

    synth_echo(isnan(synth_echo)) = 0;
    synth_echo(synth_echo == inf) = 0;
end