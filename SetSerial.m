%% This script is used to Set up the serial port connection
Nbuffer = 10000;   % Rx buffer length

disp('Opening the RS232 port . . . . . ');
s1 = serial('COM4','BaudRate',115200,'Terminator', '');
set(s1, 'FlowControl', 'none');
set(s1, 'InputBufferSize', Nbuffer);
fopen(s1)
disp('RS232 port activated');
disp(' ');