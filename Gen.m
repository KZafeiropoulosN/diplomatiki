clc;
clear all;
close all;
delete(instrfind);
disp('Starting the Characters Generator Application . . . . ');

%ecg_data=importdata('D:\Users\Zafeiropoulos7780\MatlabFiles\ecg_1.txt');
ecg_data=importdata('.\ecg_1.txt');

%ecg_data=int16(ecg_data);
Nc=length(ecg_data);        % amount of character to send
packet=1000;                % size of each packet
Nbuffer = 4000;             % Tx buffer length
pdelay = 0.035;             % minimum time between two packets
disptime=0.1;               % Time interval between displaying in graph

%%
disp('Opening the RS232 port . . . . . ');
s1 = serial('COM3','BaudRate',115200,'Parity','none', 'Terminator', '');
set(s1, 'FlowControl', 'none');
set(s1, 'InputBufferSize', Nbuffer);
set(s1, 'OutputBufferSize', Nbuffer);

fopen(s1)
disp('RS232 port activated');
disp(' ');

%%
cnt = 0;
disptic=tic;
tic;
while cnt<20000
    if s1.BytesToOutput <= Nbuffer-2*packet
            fwrite(s1,ecg_data(cnt+1:cnt+packet),'int16');          
            cnt = cnt + packet;
            timedif(cnt)=toc;
            tic;
            while toc<pdelay
            end
    end
    if toc(disptic)>disptime
        fprintf('\n  Outgoing Characters: %d  of %d  \n', cnt, Nc);
        disptic=tic;
    end
    
end

 if Nc-cnt<packet && s1.BytesToOutput == 0
    fwrite(s1,ecg_data(cnt+1:Nc));
    cnt=Nc
    timedif(cnt)=toc;
    tic;
 end

Ttotal=sum(timedif);     %  Total time
%M=(sum(timedif))/Nctest;
%V=var(timedif);
%%
disp(' ');
disp('Closing the RS232 port . . . . . ');
%record(s1,'off')
fclose(s1)
delete(s1)
clear s1

disp('RS232 port deactivated');
disp(' ');

fprintf('\nCharacters transmitted: %d\nTime elapsed: %4.3f secs\nData rate: %4.3f Chars/sec  \n\n', cnt, Ttotal, cnt/Ttotal);

disp(' . . . .  Ending the Characters Generator Application.');