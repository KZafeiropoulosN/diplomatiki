%%real time data plot from a serial port 
% This matlab script is for ploting a graph by accessing serial port data in
% real time. Change the com values and all variable values accroding to
% your requirements. Dont forget to add terminator in to your serial device program.
% This script can be modified to be used on any platform by changing the
% serialPort variable. 
% Author: Moidu thavot.

%%Clear all variables
clc;
clear all;
close all;
delete(instrfind);
%%Variables (Edit yourself)

SerialPort='com4'; %serial port
%MaxDeviation = 3;%Maximum Allowable Change from one value to next 
TimeInterval=0.1;%time interval between each input.
loop=5000;%count values
%%Set up the serial port object

time =now;
voltage = 0;
%% Set up the figure 
figureHandle = figure('NumberTitle','off',...
    'Name','Voltage Characteristics',...
    'Color',[0 0 0],'Visible','off');


% Set axes
axesHandle = axes('Parent',figureHandle,...
    'YGrid','on',...
    'YColor',[0.9725 0.9725 0.9725],...
    'XGrid','on',...
    'XColor',[0.9725 0.9725 0.9725],...
    'Color',[0 0 0]);

hold on;

plotHandle = plot(axesHandle,time,voltage,'Marker','.','LineWidth',1,'Color',[0 1 0]);

xlim(axesHandle,[min(time) max(time+0.001)]);

% Create xlabel
xlabel('Time','FontWeight','bold','FontSize',14,'Color',[1 1 0]);

% Create ylabel
ylabel('Voltage in V','FontWeight','bold','FontSize',14,'Color',[1 1 0]);

% Create title
title('Real Time Data','FontSize',15,'Color',[1 1 0]);


%%
Nbuffer = 10000;
disp('Opening the RS232 port . . . . . ');
s1 = serial('COM4','BaudRate',115200,'Parity','none', 'Terminator', '');
set(s1, 'FlowControl', 'none');
set(s1, 'InputBufferSize', Nbuffer);
set(s1, 'OutputBufferSize', Nbuffer);
fopen(s1)
disp('RS232 port activated');
disp(' ');
%% Initializing variables
BA=[];
voltage(1)=0;
time(1)=0;
count = 1;
k=1;
BAcnt=1;
while ~isequal(count,loop)
   
    %%Re creating Serial port before timeout
%{    
    k=k+1;  
    if k==25
        fclose(s);
delete(s);
clear s;        
s = serial('com4');
fopen(s)
k=0;
    end
 %}  
    if  s1.BytesAvailable >1
    %%Serial data accessing 
     BA(BAcnt)=floor(s1.BytesAvailable/2);
     voltage(count:count+BA(BAcnt)-1) = fread(s1,BA(BAcnt),'int16');
     
     %%For reducing Error Use your own costant
     %{
     voltage(1)=0;     
     if (voltage(count)-voltage(count-1)>MaxDeviation)
         voltage(count)=voltage(count-1);
     end
     %}
    
    time(count) = count;
    set(plotHandle,'YData',voltage,'XData',time);
    set(figureHandle,'Visible','on');
    datetick('x','mm/DD HH:MM');
    drawnow;
    
  %  pause(TimeInterval);
    count = count +BA(BAcnt);
    BAcnt=BAcnt+1;
    end
end



%% Clean up the serial port
fclose(s);
delete(s);
clear s;