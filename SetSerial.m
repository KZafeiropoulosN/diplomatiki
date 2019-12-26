%% This script is used to Set up the serial port connection

disp('Opening the RS232 port . . . . . ');
s1 = serial('COM4','BaudRate',115200,'Parity','none', 'Terminator', '');
set(s1, 'FlowControl', 'none');
set(s1, 'InputBufferSize', Nbuffer);
set(s1, 'OutputBufferSize', Nbuffer);
fopen(s1)
disp('RS232 port activated');
disp(' ');