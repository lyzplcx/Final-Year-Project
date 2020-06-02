function Feasible = MULP_Rate_Region_feasibility(Rth, M,weights,H_est,H_error_1,H_error_2,SNR,tolerance)

% The algorithm used is from papers:
% Weighted Sum-Rate Maximization using Weighted MMSE for MIMO-BC 
% Beamforming Design, 2008 TWC, Christensen, Agarval, Carvalho, Cioffi
% "Sum-Rate Maximization for Linearly Precoded Downlink Multiuser MISO Systems with Partial CSIT: A Rate-Splitting Approach"
% by Hamdi Joudeh and Bruno Clerks

% % % test only
% Rth = 2.5; 
% weights = [1,1];
% SNR = 10;

[Nr,Nt,K] = size(H_est);  
Pk = SNR/K;
R_1 = zeros(1,M);        R_2 = zeros(1,M);
p1 = H_est(:,:,1)'/norm(H_est(:,:,1))*sqrt(Pk);
p2 = H_est(:,:,2)'/norm(H_est(:,:,2))*sqrt(Pk);

feasible = zeros(1,2);

for i=1:M
    H_1(:,:,i) = H_est(:,:,1)+H_error_1(:,:,i);
    H_2(:,:,i) = H_est(:,:,2)+H_error_2(:,:,i);
end

for method = 1:2 % loop through 2 different initializaiton methods
    % no more precoder for common message
    % 2 variation of initialzation for private parts
    % MRC->method_1 and ZF->method_3
    if method == 2 % fixing the index problem
        [p1,p2,pc] = initialize_precoders(H_est, SNR, 3);
    else
        [p1,p2,pc] = initialize_precoders(H_est, SNR, 1);
    end
    
    
    loop = 1;
    WMSE_old = 100;
    count = 0;
    while(loop)

        t1 = 0;                 t2 = 0;
        psi_1 = 0;              psi_2 = 0;
        f1 = zeros(Nt,Nr);      f2 = zeros(Nt,Nr);
        v1 = 0;                 v2 = 0;
        U1 = 0;                 U2 = 0;

        for i=1:M
            h1 = H_1(:,:,i);            h2 = H_2(:,:,i);                
            I1 = abs(h1*p2)^2+1;        I2 = abs(h2*p1)^2+1;
            T1 = abs(h1*p1)^2+I1;       T2 = abs(h2*p2)^2+I2;

            E1 = inv(T1)*I1;            E2 = inv(T2)*I2;    
            g1 = inv(T1)*p1'*h1';       g2 = inv(T2)*p2'*h2';
            u1 = inv(E1);               u2 = inv(E2);

            U1 = U1+u1;                 U2 = U2+u2;
            t1 = t1+u1*abs(g1)^2;       t2 = t2+u2*abs(g2)^2;        
            psi_1 = psi_1+(u1*abs(g1)^2)*h1'*h1;
            psi_2 = psi_2+(u2*abs(g2)^2)*h2'*h2;
            f1 = f1+u1*h1'*g1';         f2 = f2+u2*h2'*g2';
            v1 = v1+log2(u1);           v2 = v2+log2(u2);
        end

        % SAFs
        U1=U1./M;           U2=U2./M;    
        t1=t1./M;           t2=t2./M;
        psi_1=psi_1./M;     psi_2=psi_2./M;    
        f1=f1./M;           f2=f2./M;    
        v1=v1./M;           v2=v2./M;

        % cvx optimization
%         [WMSE,p1,p2]=MULP_update_P(M,weights,H_est,SNR,U1,U2,t1,t2,psi_1,psi_2,f1,f2,v1,v2);
        [feasible(method),WMSE,p1,p2]=MULP_update_P_feasibility(Rth,weights,H_est,SNR,U1,U2,t1,t2,psi_1,psi_2,f1,f2,v1,v2);

        if feasible(method) == 0 
            loop = 0;
            break; % while
        end
        
        if abs((WMSE-WMSE_old)/WMSE_old)<=tolerance
            loop=0;
        else
            WMSE_old=WMSE;
            count = count+1;
        end

        if count >= 500
            loop=0;
        end

    end
end

if feasible == zeros(1,2)
    Feasible = 0;
else
    Feasible = 1;
end
