clc;
clear all;
close all;
delete(instrfind);
disp('Starting the Characters Sink Application . . . . ');

global flag2
flag2=0;
Variables;  % Initialize Variables needed
SetFigure;  % Set up the figure
SetSerial;  % Set up the serial port connection

%%
disptic=tic;
endtic=tic;
while toc(endtic)<timeout
    if length(DataArray)==0 % We are on the first iteration
        tstart=tic;
    end
    if offset==1
        limit=0;
    else
        limit=1;
    end
    if  s1.BytesAvailable >1  % wait to receive a new character
        BytesToReadFromPort=floor(s1.BytesAvailable/2);
        % Store all data from port to a temporary buffer and then start processing
        ReadBuffer(1:BytesToReadFromPort)= fread(s1,BytesToReadFromPort,'int16');
        tic;
        for i=1:1:ceil(BytesToReadFromPort/DownsampleStep)-limit
            % append next value at the end of the downsampled data array
            DataArray(end + 1) = ReadBuffer((i-1)*DownsampleStep+offset);
            %{
                if mod(length(DataArray),PowStep)==0
                    [PossibleQrs(PossibleQrsCnt)]=ActivateWindow(DataArray,length(DataArray),PowStep);
                    AddToCnt=PossibleQrs(PossibleQrsCnt-1)-qrswindow;
                    if PossibleQrs(PossibleQrsCnt)~=0
                        if FirstTimeFlag==0
                            [qrs_amp_raw,qrs_i_raw,delay]=pan_tompkin(DataArray(AddToCnt:AddToCnt+qrswindow),1000,0);
                            qrs_i_raw=qrs_i_raw+AddToCnt;
                            if abs(qrs_i_raw(length(qrs_i_raw))-qrs(length(qrs)))>200
                                qrs=[qrs qrs_i_raw(length(qrs_i_raw))];
                                qrsfile=[qrsfile qrs_i_raw];
                                RRInterval=(qrs(length(qrs))-qrs(length(qrs)-1))*1000/DSFs;
                                RRIntervalArray=[RRIntervalArray RRInterval];
                                AdjInterval=RRInterval-RRIntervalArray(length(RRIntervalArray)-1);
                                AdjIntervalArray=[AdjIntervalArray AdjInterval]; 
                                HR=60/RRInterval;
                                HRArray=[HRArray HR];
                            end
                        elseif length(DataArray)>5000 && FirstTimeFlag==1
                            [qrs_amp_raw,qrs_i_raw,delay]=pan_tompkin(DataArray(1:PossibleQrs(PossibleQrsCnt-1)),1000,0);
                            qrs=qrs_i_raw;
                            for j=1:1:length(qrs)-1
                                RRIntervalArray(j)=(qrs(j+1)-qrs(j))*1000/DSFs;
                            end
                            for j=1:1:length(RRIntervalArray)-1
                                AdjIntervalArray(j)=RRIntervalArray(j+1)-RRIntervalArray(j);
                            end
                            FirstTimeFlag=0;
                        end
                        PossibleQrsCnt=PossibleQrsCnt+1;
                    end
                end
            %}
            timedif(end + 1)=toc;
            tic;
            while toc<pdelay
            end
        end
        if mod(s1.ValuesReceived,DownsampleStep)==0
            offset=1;
        else
            offset=DownsampleStep-mod(s1.ValuesReceived,DownsampleStep)+1;
        end

        if length(DataArray)>0 && mod(length(DataArray),300000)==0
            FiveMinsMean=mean(RRIntervalArray(intervalcnt:length(RRIntervalArray)));
            FiveMinsMeanArray=[FiveMinsMeanArray FiveMinsMean];
            FiveMinsDev=std(RRIntervalArray(intervalcnt:length(RRIntervalArray)));
            FiveMinsDevArray=[FiveMinsDevArray FiveMinsDev];

            intervalcnt=length(RRIntervalArray);
        end
        endtic=tic;

    end
    if toc(disptic)>disptime

        if length(DataArray)<=10000
            set(plotHandle,'YData',DataArray); % draw all
        else
            set(plotHandle,'YData',DataArray(end-10000 +1:end)); % draw last 10000
        end
        snapnow;

        fprintf('\n  Ingoing Characters: %d  \n', length(DataArray));
        disptic=tic;
    end

end
Ttotal=toc(tstart);

SDNN=std(RRIntervalArray);
SDANN=std(FiveMinsMeanArray);
ASDNN=mean(FiveMinsDevArray);
SDSD=std( AdjIntervalArray);
RMSSD=sqrt(sum(AdjIntervalArray.^2)/length(AdjIntervalArray));
for i=1:1:length(AdjIntervalArray)
    if abs(AdjIntervalArray(i))>50
        NN50=NN50+1;
    end
end
pNN50=NN50/length(RRIntervalArray);

Nc=length(DataArray);
ecg_data=importdata('ecg_1.txt');
A=downsample(ecg_data(1:DownsampleStep*Nc),DownsampleStep)';
errcnt=0;
for i=1:1:Nc
    dif(i)=DataArray(i)-A(i);
    if dif(i)~=0
        errcnt=errcnt+1;
        %fprintf('\nError happened in: %d\nCharacter transmitted: %d\nCharacter received: %d\n',i,A(i),DataArray(i));
    end
    if timedif(i)>0.000201
        bigcnt=bigcnt+1;
    end
    if timedif(i)<0.000199
        smallcnt=smallcnt+1;
    end
    if timedif(i)>=0.000199 && timedif(i)<=0.000201
        goodcnt=goodcnt+1;
    end
    i=i+1;
end
S=sum(dif);


M=mean(timedif);
V=var(timedif);
figure();
plot(qrs);
%{
figure();
edges=[0.00018 0.00019:0.000001:0.00022 0.00023];
h=histogram(timedif,edges);
title('Histogram of the time defferences between two charactes arrival')
xlabel('Time differences in sec')
ylabel('Amount of time differences')
%}
%%
disp(' ');
disp('Closing the RS232 port . . . . . ');
%record(s1,'off')
fclose(s1);
delete(s1)
clear s1

disp('RS232 port deactivated');
disp(' ');

fprintf('\nCharacters received: %d\nTime elapsed: %4.3f secs\n Average Data rate: %4.3f Chars/sec  \n Transmition Errors: %d\n\n', Nc, Ttotal, 1/M,errcnt);
fprintf('\n %4.3f percent chararacters came in less than 1.99e-04 sec',smallcnt/Nc);
fprintf('\n %4.3f percent chararacters came between 1.99e-04 sec and 2.01e-04',goodcnt/Nc);
fprintf('\n %4.3f percent chararacters came in more than 2.01e-04 sec\n\n',bigcnt/Nc);
disp(' . . . .  Ending the Characters Sink Application.\n');

%function readFromPort
