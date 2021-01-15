%% Initialising the required variables for Generator Application
% Data values of the ecg signal are imported from a text file and stored
% in an array. The values have been created by sampling the analog ecg
% with a sampling frequency of 5kHz (5000 samples per second).
% A serial port is then initialised. We expect data values to be [-500, 500]
% aproximately. So we use int16 as data precision [-32768, 32767] in fwrite.
% Thus each value is sent as two bytes (16bits) through serial port.
% Serial port sends data in data frames. Each data frame contains 10 bits
% (8 data bits, 1 start bit and 1 stop bit). So in our communication
% each data value of the ecg signal is sent in two frames, thus we need to
% send 20 bits in order for the data value to be transmitted.
% We set Baud Rate to 115200 bauds. Thus we can send up to 115200/20=5760
% data values per second.
% In each write operation we send 1000 data.

clc;
clear all;
close all;
delete(instrfind);
disp('Starting the Characters Generator Application . . . . ');

ecg_data=importdata('ecg_1.txt');

%ecg_data=int16(ecg_data);
%Nc=length(ecg_data);        % amount of character to send
Nc = 50100;
packet=1000;                % size of each packet
Nbuffer = 2000;             % Tx buffer length
pdelay = 0.2;               % minimum time between two packets
disptime=0.1;               % Time interval between displaying in graph

%%
disp('Opening the RS232 port . . . . . ');
s1 = serial('COM3','BaudRate',115200,'Terminator', '');
set(s1, 'OutputBufferSize', Nbuffer);

fopen(s1)
disp('RS232 port activated');
disp(' ');

%%
cnt = 0;
disptic=tic;
totalTime=tic;
while Nc - cnt > 0
    if ~s1.BytesToOutput
      tic;
      if Nc - cnt >= packet
        fwrite(s1,ecg_data(cnt+1:cnt+packet),'int16');
      else
        disp('here')
        fwrite(s1,ecg_data(cnt+1:Nc),'int16');
      end
      cnt = s1.ValuesSent; 
      %while toc<pdelay
      %end
    end
    if toc(disptic)>disptime
        fprintf('\n  Outgoing Characters: %d  of %d  \n', cnt, Nc);
        disptic=tic;
    end
    
end

Ttotal=toc(totalTime);     %  Total time
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