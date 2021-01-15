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
[ReceivedData, qrs] = start(ecg_data, Fs, ReceivedData, qrs);

validation = (downsample(ecg_data(1:10000),10))';

for i=1:1:length(ReceivedData)
  dif = ReceivedData(i) - validation(i);
  if dif ~= 0 
    disp('Error found %d', i);
  end
end

function [DataArray, qrs] = start(ecg_data, Fs, DataArray, qrs)
  %% Initialise variables and ports
  %Nc=length(ecg_data);       % amount of character to send
  Nc = 200000;
  packet=1000;                % size of each packet
  s1OutpuBuffer = 2000;       % Tx buffer length
  s2InputBuffer = 2000;       % Rx buffer length
  pdelay = 0.2;               % minimum time between two packets
  disptime=0.1;               % Time interval between displaying in graph
  DownsampleFs = 500;
  DownsampleStep = Fs/DownsampleFs;
  qrswindow=2*DownsampleFs;   % A sufficient amount of data (2 seconds) in order to check for QRS
  PowStep=DownsampleFs/10;    % The window in which we check for possible QRS complexes by 
                              % computing the power of the signal. It should be 100ms

  disp('Opening RS232 ports . . . . . ');
  s1 = serial('COM3','BaudRate',115200, 'OutputBufferSize', s1OutpuBuffer);
  s2 = serial('COM4','BaudRate',115200,'InputBufferSize', s2InputBuffer);
  s2.BytesAvailableFcnMode = 'byte';
  s2.BytesAvailableFcnCount = 2000;
  s2.BytesAvailableFcn = @(src, ~)onBytesAvailable(src, @pan_tompkin, DownsampleStep, qrswindow, PowStep);
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
  cnt = 0;
  disptic=tic;
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
  function onBytesAvailable(src, pan_tompkin, DownsampleStep, qrswindow, PowStep)
    % Just to be sure
    if ~src.BytesAvailable
      return
    end
    SamplesToReadFromPort=floor(src.BytesAvailable/2);
    ReadBuffer = fread(src, SamplesToReadFromPort, 'int16')';
    ReadBuffer = downsample(ReadBuffer, DownsampleStep); % Downsample to 500Hz 
    DataArray = [DataArray ReadBuffer]; % Append received values to previously received data
    fprintf('\nCharacters received: %d\n', src.ValuesReceived);
    
    if length(DataArray) < qrswindow % We need at least 2 seconds of information to run pan_tomkins
      return
    end
    
    for i=1:PowStep:length(ReadBuffer) % Iterate on the newly received data with 100ms step
      currentDataIndex = length(DataArray) - length(ReadBuffer) + i;
      if isQRSPossible(DataArray(currentDataIndex - PowStep:currentDataIndex))
        % We provide the last 2 seconds of data to pan_tompkin
        samlplesToProcess = DataArray(currentDataIndex - qrswindow:currentDataIndex);
        [~,qrs_i_raw]=pan_tompkin(samlplesToProcess, DownsampleFs, 0);
        qrs = getQRSIndexInDataArray(qrs, qrs_i_raw, currentDataIndex, qrswindow, PowStep);
      end
    end
    
    function output = isQRSPossible(data)
      % Check if the power of the provided data is above threshold
      output = rms(data)^2 > 10000;
    end
    
    function [qrs] = getQRSIndexInDataArray(qrs, qrs_i_raw, currentDataIndex, qrswindow, PowStep)
      % Gets the current qrs array and adds the newly found indexes.
      % The indexes should represent the right position on the DataArray.
 
      % if it is the first time we return all found indexes
      if isempty(qrs)
        qrs = qrs_i_raw + currentDataIndex - qrswindow;
        return 
      end

      % Transform qrs index to the corresponding DataArray index
      qrs_i_raw = qrs_i_raw + currentDataIndex - qrswindow;
      % make sure this is a new qrs by comparing its value
      % with the latest found qrs
      if abs(qrs_i_raw(end)-qrs(end)) > PowStep
        qrs(end + 1) = qrs_i_raw(end); % append the last found qrs to the ones we have
      end
    end
  end
end