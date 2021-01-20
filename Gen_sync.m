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

%%
clc;
clear all;
close all;
delete(instrfind);
disp('Starting the Application . . . . ');

ecg_data=importdata('ecg_1.txt');
Fs = 5000;
ReceivedData = [];
qrs = [];
RRIntervalArray = [];
FiveMinsMeanArray = [];
FiveMinsDeviationArray = [];
SuccessiveIntervalArray = [];
NN50 = 0;                         % The number of RR intervals differing by > 50ms from the preceding interval
[ReceivedData, qrs, RRIntervalArray, FiveMinsMeanArray, FiveMinsDeviationArray] = start(...
  ecg_data, Fs, ReceivedData, qrs, RRIntervalArray, FiveMinsMeanArray, FiveMinsDeviationArray);

for i=2:1:length(RRIntervalArray)
  SuccessiveInterval=RRIntervalArray(i)-RRIntervalArray(i-1);
  SuccessiveIntervalArray=[SuccessiveIntervalArray SuccessiveInterval];
  
  if abs(SuccessiveInterval)*1000 > 50
    NN50 = NN50 + 1;
  end
end

SDNN = std(RRIntervalArray);                     % Standard deviation of all normal to normal RR intervals
SDANN = std(FiveMinsMeanArray);                  % Standard deviation of 5-minute average RR intervals
ASDNN = mean(FiveMinsDeviationArray);            % Mean of the standard deviations of all RR intervals fow all 5 minute segments
rMSSD = sqrt(mean(SuccessiveIntervalArray.^2));  % Square root of the mean of the squares of successive RR interval differences
pNN50 = (NN50/length(RRIntervalArray))*100;      % The perventage of RR intervals differing by > 50ms from the preceding interval

function [DataArray, qrs, RRIntervalArray, FiveMinsMeanArray, FiveMinsDeviationArray] = start(...
  ecg_data, Fs, DataArray, qrs, RRIntervalArray, FiveMinsMeanArray, FiveMinsDeviationArray)
  %% Initialise variables and ports
  %Nc=length(ecg_data);       % amount of character to send
  Nc = 1570000;
  packet=1000;                % size of each packet
  s1OutpuBuffer = 2000;       % Tx buffer length
  s2InputBuffer = 2000;       % Rx buffer length
  disptime=0.1;               % Time interval between displaying in graph
  DownsampleFs = 500;         % We are downsampling data to that frequency
                              % before sending them to pan_tomkins
  qrswindow=2*DownsampleFs;   % A sufficient amount of data (2 seconds) in order to check for QRS
  PowStep=DownsampleFs/10;    % The window in which we check for possible QRS complexes by 
                              % computing the power of the signal. It should be 100ms
  fiveMinWindowLength = DownsampleFs*60*5;
  fiveMeanWindowIndex = 1;
  fiveMinWindowCnt = 1;

  disp('Opening RS232 ports . . . . . ');
  s1 = serial('COM3','BaudRate',115200, 'OutputBufferSize', s1OutpuBuffer);
  s2 = serial('COM4','BaudRate',115200,'InputBufferSize', s2InputBuffer);
  s2.BytesAvailableFcnMode = 'byte';
  s2.BytesAvailableFcnCount = 2000;
  s2.BytesAvailableFcn = @(src, ~)onBytesAvailable(src, @pan_tompkin, DownsampleFs, qrswindow, PowStep);
  fopen(s1); fopen(s2); 
  
  disp('RS232 receiver and transmitter ports activated');
  disp(' ');
  
  %% Set up plot
  figure('NumberTitle','off',...
      'Name','Electrocardiography',...
      'Color',[0 0 0]);
  plotHandle = plot(0,'Marker','.',...
    'LineWidth',1,'Color',[0.1328    0.5430    0.1328]);
  axis([0 10*DownsampleFs -600 600]);

  set(gca,...
      'XColor', [0.9375 1 1],...
      'YColor', [0.9375 1 1]);

  xlabel('Data','FontWeight','bold','FontSize',12,...
    'Color',[0.8516    0.6445    0.1250]);
  ylabel('Amplitude','FontWeight','bold','FontSize',12,...
    'Color',[0.8516    0.6445    0.1250]);
  title('Real Time Data','FontSize',12,...
    'Color',[0.8516    0.6445    0.1250]);
  %% Start sending data
  times = 1;
  cnt = 0;
  disptic=tic;
  while Nc - cnt > 0
    if times > 10
      break;
    end
    if ~s1.BytesToOutput
      tic;
      if Nc - cnt >= packet
        fwrite(s1,ecg_data(cnt+1:cnt+packet),'int16');
      else
        fwrite(s1,ecg_data(cnt+1:Nc),'int16');
      end
      cnt = cnt + packet;
      
      if cnt == Nc
        cnt = 0
        times = times + 1
      end
      %while toc<pdelay
      %end
    end
    if toc(disptic)>disptime
      if length(DataArray)<=10*DownsampleFs
        set(plotHandle,'YData',DataArray); % draw all
      else
        set(plotHandle,'YData',DataArray(end-10*DownsampleFs +1:end)); % draw last 10 seconds
      end
      snapnow;
      disptic=tic;
    end
  end

  %% Close ports, End application
  pause(5);
  disp(' ');
  disp('Closing the RS232 ports . . . . . ');
  fclose(s1); fclose(s2);
  delete(s1); delete(s2);
  clear s1; clear s2;

  disp('RS232 ports deactivated');
  disp(' ');
  %% Callback to receive and process data
  function onBytesAvailable(src, pan_tompkin, DownsampleFs, qrswindow, PowStep)
    % Just to be sure
    if ~src.BytesAvailable
      return
    end
    SamplesToReadFromPort=floor(src.BytesAvailable/2);
    ReadBuffer = fread(src, SamplesToReadFromPort, 'int16')';
    ReadBuffer = downsample(ReadBuffer, Fs/DownsampleFs); % Downsample to 500Hz 
    DataArray = [DataArray ReadBuffer]; % Append received values to previously received data
    fprintf('\nCharacters received: %d\n', src.ValuesReceived);
    
    if length(DataArray) < 1.2*qrswindow % We need at least 2 seconds of information to run pan_tomkins
      return
    end
    
    for i=1:PowStep:length(ReadBuffer) % Iterate on the newly received data with 100ms step
      currentDataIndex = length(DataArray) - length(ReadBuffer) + i;
      if isQRSPossible(DataArray(currentDataIndex - PowStep:currentDataIndex))
        % We provide the last 2 seconds of data to pan_tompkin
        samlplesToProcess = DataArray(currentDataIndex - qrswindow:currentDataIndex);
        [~,qrs_i_raw]=pan_tompkin(samlplesToProcess, DownsampleFs, 0);
        qrs = getQRSIndexInDataArray(qrs, qrs_i_raw, currentDataIndex, qrswindow, PowStep, DownsampleFs);
      end
      
      if currentDataIndex - fiveMinWindowCnt*fiveMinWindowLength >= 0
        FiveMinsMean=mean(RRIntervalArray(fiveMeanWindowIndex:end));
        FiveMinsMeanArray=[FiveMinsMeanArray FiveMinsMean];
        
        FiveMinsDeviation=std(RRIntervalArray(fiveMeanWindowIndex:end));
        FiveMinsDeviationArray=[FiveMinsDeviationArray FiveMinsDeviation];
        
        fiveMeanWindowIndex = length(RRIntervalArray) + 1;
        fiveMinWindowCnt = fiveMinWindowCnt + 1;
      end
    end
    
    function output = isQRSPossible(data)
      % Check if the power of the provided data is above threshold
      output = rms(data)^2 > 10000;
    end
    
    function [qrs] = getQRSIndexInDataArray(qrs, qrs_i_raw, currentDataIndex, qrswindow, PowStep, DownsampleFs)
      % Gets the current qrs array and adds the newly found indexes.
      % The indexes should represent the right position on the DataArray.
 
      % if it is the first time we return all found indexes
      if isempty(qrs)
        qrs = qrs_i_raw + currentDataIndex - qrswindow;
        for j=1:1:length(qrs)-1
          RRIntervalArray(j)=(qrs(j+1)-qrs(j))/DownsampleFs;
        end
        return 
      end

      % Transform qrs index to the corresponding DataArray index
      qrs_i_raw = qrs_i_raw + currentDataIndex - qrswindow;
      % make sure this is a new qrs by comparing its value
      % with the latest found qrs
      if abs(qrs_i_raw(end)-qrs(end)) > PowStep
        qrs(end + 1) = qrs_i_raw(end); % append the last found qrs to the ones we have
        RRInterval = (qrs(end)-qrs(end - 1))/DownsampleFs;
        RRIntervalArray = [ RRIntervalArray RRInterval ];
      end
    end
  end
end