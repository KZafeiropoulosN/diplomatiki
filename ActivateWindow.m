function [ flag ] = ActivateWindow( Data,k,step )
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
global flag2
p=(rms(Data(k-step+1:k))^2);
if p>10000
    flag2=1;
    flag=0;
else
    if flag2==1
        flag=k;
        flag2=0;
    else flag=0;
    end
end
