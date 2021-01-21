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

% Values are sent in port s1 and received by port s2.

%%
clc;
clear all;
close all;
delete(instrfind);
disp('Starting the Application . . . . ');

FREQUENCY = 5000;

dataToTransmit = importdata('ecg_1.txt');
receivedDataArray = [];           % Array that contains the received data downsampled to 500hz.
qrsArray = [];                    % Array that contains the indexes of the qrs complex in the ReceivedData array.
RRIntervalArray = [];             % Array that contains the time difference (RRInterval) between each qrs complex and its successive qrs complex in seconds.
fiveMinsMeanArray = [];           % Array that contains the mean values of the RRIntervals for all five minute segments of the signal.
fiveMinsDeviationArray = [];      % Array that contains the standard diviation values of the RRIntervals for all five minute segments of the signal.
successiveIntervalArray = [];     % Array that contains the difference betwen each RRInterval and its successive RRInterval.
NN50 = 0;                         % The number of RR intervals differing by > 50ms from the preceding interval.
[receivedDataArray, qrsArray, RRIntervalArray, fiveMinsMeanArray, fiveMinsDeviationArray] = start(...
  dataToTransmit, FREQUENCY, receivedDataArray, qrsArray, RRIntervalArray, fiveMinsMeanArray, fiveMinsDeviationArray);

for i=2:1:length(RRIntervalArray)
  successiveInterval = RRIntervalArray(i) - RRIntervalArray(i - 1);
  successiveIntervalArray = [successiveIntervalArray successiveInterval];
  
  if abs(successiveInterval)*1000 > 50
    NN50 = NN50 + 1;
  end
end

SDNN = std(RRIntervalArray);                     % Standard deviation of all normal to normal RR intervals
SDANN = std(fiveMinsMeanArray);                  % Standard deviation of 5-minute average RR intervals
ASDNN = mean(fiveMinsDeviationArray);            % Mean of the standard deviations of all RR intervals fow all 5 minute segments
rMSSD = sqrt(mean(successiveIntervalArray.^2));  % Square root of the mean of the squares of successive RR interval differences
pNN50 = (NN50/length(RRIntervalArray))*100;      % The perventage of RR intervals differing by > 50ms from the preceding interval

function [receivedDataArray, qrsArray, RRIntervalArray, fiveMinsMeanArray, fiveMinsDeviationArray] = start(...
  dataToTransmit, FREQUENCY, receivedDataArray, qrsArray, RRIntervalArray, fiveMinsMeanArray, fiveMinsDeviationArray)
  %% Initialise variables
  %Nc=length(dataToTransmit);       % amount of character to send
  nValuesToSend = 1570000;
  FRAME_LENGTH = 1000;              % size of each frame
  S1_OUTPUT_BUFFER_LENGTH = 2000;   % Tx buffer length
  S2_INPUT_BUFFER_LENGTH = 2000;    % Rx buffer length
  BAUD_RATE = 115200;
  DISP_TIME = 0.1;                  % Time interval between displaying in graph in seconds
  DOWNSAMPLE_FREQUENCY = 500;       % We are downsampling data to that frequency
                                    % before sending them to pan_tomkins
  QRS_WINDOW = 2*DOWNSAMPLE_FREQUENCY; % A sufficient amount of data (2 seconds) in order to check for QRS
  POW_STEP = DOWNSAMPLE_FREQUENCY/10;  % The window in which we check for possible QRS complexes by 
                                       % computing the power of the signal. It should be 100ms.

  fiveMinWindowLength = DOWNSAMPLE_FREQUENCY*60*5; % The length of a five minute segment measured in data samples
  previousFiveMinWindowIndex = 1;                  % The index where the previous five minute segment ends.
  fiveMinWindowCnt = 1;                            % Counter of five minute segments
  
  %% Open ports
  disp('Opening RS232 ports . . . . . ');
  s1 = serial('COM3','BaudRate',BAUD_RATE, 'OutputBufferSize', S1_OUTPUT_BUFFER_LENGTH);
  s2 = serial('COM4','BaudRate',BAUD_RATE,'InputBufferSize', S2_INPUT_BUFFER_LENGTH);
  s2.BytesAvailableFcnMode = 'byte';
  s2.BytesAvailableFcnCount = 2000;
  s2.BytesAvailableFcn = @(src, ~)onBytesAvailable(src, @pan_tompkin, DOWNSAMPLE_FREQUENCY, QRS_WINDOW, POW_STEP);
  fopen(s1); fopen(s2); 
  
  disp('RS232 receiver and transmitter ports activated');
  disp(' ');
  
  %% Set up plot
  figure('NumberTitle','off', 'Name','Electrocardiography', 'Color',[0 0 0]);
  plotHandle = plot(0,'Marker','.', 'LineWidth',1, 'Color',[0.1328 0.5430 0.1328]);
  axis([0 10*DOWNSAMPLE_FREQUENCY -600 600]);
  set(gca, 'XColor',[0.9375 1 1], 'YColor',[0.9375 1 1]);
  xlabel('Data', 'FontWeight','bold', 'FontSize',12, 'Color',[0.8516 0.6445 0.1250]);
  ylabel('Amplitude', 'FontWeight','bold', 'FontSize',12, 'Color',[0.8516 0.6445 0.1250]);
  title('Real Time Data', 'FontSize',12, 'Color',[0.8516 0.6445 0.1250]);
  %% Start sending data
  REPEAT_SEND = 3;
  times = 1;
  valuesSentCnt = 0;
  disptic = tic;
  while nValuesToSend - valuesSentCnt > 0
    if times > REPEAT_SEND
      break;
    end
    if ~s1.BytesToOutput
      tic;
      if nValuesToSend - valuesSentCnt >= FRAME_LENGTH
        fwrite(s1, dataToTransmit(valuesSentCnt + 1:valuesSentCnt + FRAME_LENGTH), 'int16');
      else
        fwrite(s1, dataToTransmit(valuesSentCnt + 1:nValuesToSend), 'int16');
      end
      valuesSentCnt = valuesSentCnt + FRAME_LENGTH;
      
      if valuesSentCnt == nValuesToSend
        valuesSentCnt = 0;
        times = times + 1;
      end
    end
    if toc(disptic) > DISP_TIME
      if length(receivedDataArray) <= 10*DOWNSAMPLE_FREQUENCY
        set(plotHandle, 'YData', receivedDataArray); % draw all
      else
        set(plotHandle, 'YData', receivedDataArray(end-10*DOWNSAMPLE_FREQUENCY + 1:end)); % draw last 10 seconds
      end
      snapnow;
      disptic = tic;
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
  function onBytesAvailable(src, pan_tompkin, DOWNSAMPLE_FREQUENCY, QRS_WINDOW, POW_STEP)
    if ~src.BytesAvailable
      return
    end
    nSamplesToReadFromPort = floor(src.BytesAvailable/2);
    readBufferArray = fread(src, nSamplesToReadFromPort, 'int16')';
    readBufferArray = downsample(readBufferArray, FREQUENCY/DOWNSAMPLE_FREQUENCY); % Downsample to 500Hz 
    receivedDataArray = [receivedDataArray readBufferArray]; % Append received values to previously received data
    fprintf('\nCharacters received: %d\n', src.ValuesReceived);
    
    if length(receivedDataArray) < 1.2*QRS_WINDOW % We need at least 2 seconds of information to run pan_tomkins
      return
    end
    
    for i=1:POW_STEP:length(readBufferArray) % Iterate on the newly received data with 100ms step
      currentDataIndex = length(receivedDataArray) - length(readBufferArray) + i;
      if isQRSPossible(receivedDataArray(currentDataIndex - POW_STEP:currentDataIndex))
        % We provide the last 2 seconds of data to pan_tompkin
        samlplesToProcessArray = receivedDataArray(currentDataIndex - QRS_WINDOW:currentDataIndex);
        [~,qrs_i_raw] = pan_tompkin(samlplesToProcessArray, DOWNSAMPLE_FREQUENCY, 0);
        qrsArray = getQRSIndexInReceivedDataArray(qrsArray, qrs_i_raw, currentDataIndex, QRS_WINDOW, POW_STEP, DOWNSAMPLE_FREQUENCY);
      end
      
      if currentDataIndex - fiveMinWindowCnt*fiveMinWindowLength >= 0
        FiveMinsMean=mean(RRIntervalArray(previousFiveMinWindowIndex:end));
        fiveMinsMeanArray=[fiveMinsMeanArray FiveMinsMean];
        
        FiveMinsDeviation = std(RRIntervalArray(previousFiveMinWindowIndex:end));
        fiveMinsDeviationArray = [fiveMinsDeviationArray FiveMinsDeviation];
        
        previousFiveMinWindowIndex = length(RRIntervalArray) + 1;
        fiveMinWindowCnt = fiveMinWindowCnt + 1;
      end
    end
    
    function output = isQRSPossible(data)
      % Check if the power of the provided data is above threshold
      output = rms(data)^2 > 10000;
    end
    
    function [qrsArray] = getQRSIndexInReceivedDataArray(qrsArray, qrs_i_raw, currentDataIndex, QRS_WINDOW, POW_STEP, DOWNSAMPLE_FREQUENCY)
      % Gets the current qrs array and adds the newly found indexes.
      % The indexes should represent the right position on the receivedDataArray.
 
      % if it is the first time we return all found indexes
      if isempty(qrsArray)
        qrsArray = qrs_i_raw + currentDataIndex - QRS_WINDOW;
        for j=1:1:length(qrsArray)-1
          RRIntervalArray(j)=(qrsArray(j+1)-qrsArray(j))/DOWNSAMPLE_FREQUENCY;
        end
        return 
      end

      % Transform qrsArray index to the corresponding receivedDataArray index
      qrs_i_raw = qrs_i_raw + currentDataIndex - QRS_WINDOW;
      % make sure this is a new qrs by comparing its value
      % with the latest found qrs
      if abs(qrs_i_raw(end)-qrsArray(end)) > POW_STEP
        qrsArray(end + 1) = qrs_i_raw(end); % append the last found qrs to the ones we have
        RRInterval = (qrsArray(end)-qrsArray(end - 1))/DOWNSAMPLE_FREQUENCY;
        RRIntervalArray = [RRIntervalArray RRInterval];
      end
    end
  end
end