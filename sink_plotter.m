%% Start Fresh
clc;
clear all;
close all;
delete(instrfind);
disp('Starting the Characters Sink Application . . . . ');
DataArray=[];      % Array of data received
qrs=[];
[DataArray, qrs] = start(DataArray, qrs);

function [DataArray, qrs] = start(DataArray, qrs)
  %% Initialize Variables needed
  global flag2
  flag2=0;
  disp('Initializing Variables . . . . . ');

  pdelay=0.000198;   % Minimum time of writing a character in DataArray
  ReadBuffer=[];     % Temporary byffer in order to read data and downsample
                     % before we store them in DataArray
  
  timedif=[];
  disptime=0.1;      % Time interval between plotting data
  timeout=10;        % Time without receiving data that the program will end
  PossibleQrsCnt=2;

  Fs = 5000;
  DownsampleFs = 500;               % Target frequency to provide to pan_tomkins algorithm
  DownsampleStep = Fs/DownsampleFs; % Step to downsample based on original signal frequency
  PowStep=DownsampleFs/10;    % The window in which we check for possible QRS complexes by 
                              % computing the power of the signal. It should be 100ms
  qrswindow=4*DownsampleFs;   % A sufficient amount of data (4 second) in order to check for QRS

  offset=1;
  FirstTimeFlag=1;



  bigcnt=0;
  smallcnt=0;
  goodcnt=0;


  window=40000;
  qrsfile=[];

  RRIntervalArray=[];
  AdjIntervalArray=[];
  NN50=0;

  HRArray=[];
  FiveMinsMeanArray=[];
  FiveMinsDevArray=[];

  intervalcnt=1;
  
  %% Set up the figure
  disp('Setting up the figure . . . . . ');

  figureHandle = figure('NumberTitle','off',...
      'Name','Electrocardiography',...
      'Color',[0 0 0]);

  %hold on;
  %subplot(2,1,1);
  plotHandle = plot(0,'Marker','.','LineWidth',1,'Color',[0.1328    0.5430    0.1328]);
  axis([0 40000 -600 600]);

  set(gca,...
      'XColor', [0.9375 1 1],...
      'YColor', [0.9375 1 1]);

  % Create xlabel
  xlabel('Data','FontWeight','bold','FontSize',12,'Color',[0.8516    0.6445    0.1250]);

  % Create ylabel
  ylabel('Amplitude','FontWeight','bold','FontSize',12,'Color',[0.8516    0.6445    0.1250]);

  % Create title
  title('Real Time Data','FontSize',12,'Color',[0.8516    0.6445    0.1250]);
  
  
  %% Set up the serial port connection
  Nbuffer = 10000;   % Rx buffer length

  disp('Opening the RS232 port . . . . . ');
  s1 = serial('COM4','BaudRate',115200,'InputBufferSize', Nbuffer, 'Terminator', '');
  s1.BytesAvailableFcnMode = 'byte';
  s1.BytesAvailableFcnCount = 2000;
  s1.BytesAvailableFcn = @(src, ~)onBytesAvailable(src, @isQRSPossible, @pan_tompkin );
  fopen(s1);
  disp('RS232 port activated');
  disp(' ');

  %%
  disptic=tic;
  endtic=tic;
  while toc(endtic)<timeout
      %if length(DataArray)==0 % We are on the first iteration
      %    tstart=tic;
      %end
      %if offset==1
      %    limit=0;
      %else
      %    limit=1;
      %end
      %{
      if  s1.BytesAvailable >1  % wait to receive a new character
          %BytesToReadFromPort=floor(s1.BytesAvailable/2);
          % Store all data from port to a temporary buffer and then start processing
          %ReadBuffer(1:BytesToReadFromPort)= fread(s1,BytesToReadFromPort,'int16');
          tic;
          %for i=1:1:ceil(BytesToReadFromPort/DownsampleStep)-limit
              % append next value at the end of the downsampled data array
              %DataArray(end + 1) = ReadBuffer((i-1)*DownsampleStep+offset);
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
          %end
          %{ 
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
          %}
          endtic=tic;

      end
      %}
      if toc(disptic)>disptime

          if length(DataArray)<=40000
              set(plotHandle,'YData',DataArray); % draw all
          else
              set(plotHandle,'YData',DataArray(end-40000 +1:end)); % draw last 10000
          end
          snapnow;

          %fprintf('\n  Ingoing Characters: %d  \n', length(data.values));
          disptic=tic;
      end
      if s1.BytesAvailable
        endtic=tic;
      end
  end
  %{
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
  %}
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
  %{
  fprintf('\nCharacters received: %d\nTime elapsed: %4.3f secs\n Average Data rate: %4.3f Chars/sec  \n Transmition Errors: %d\n\n', Nc, Ttotal, 1/M,errcnt);
  fprintf('\n %4.3f percent chararacters came in less than 1.99e-04 sec',smallcnt/Nc);
  fprintf('\n %4.3f percent chararacters came between 1.99e-04 sec and 2.01e-04',goodcnt/Nc);
  fprintf('\n %4.3f percent chararacters came in more than 2.01e-04 sec\n\n',bigcnt/Nc);
  %}
  disp(' . . . .  Ending the Characters Sink Application.\n');

  function output = isQRSPossible(data)
    output = rms(data)^2 > 10000;
  end

  function onBytesAvailable(src, isQRSPossible, pan_tompkin)
    SamplesToReadFromPort=floor(src.BytesAvailable/2);
    ReadBuffer = fread(src, SamplesToReadFromPort, 'int16')'; % Read values
    ReadBuffer = downsample(ReadBuffer, DownsampleStep); % Downsample to 500Hz 
    DataArray = [DataArray ReadBuffer]; % Append received values to previously received data

    if length(DataArray) < 2*DownsampleFs % We need at least 2 second of information to run pan_tomkins
      return
    end

    for i=1:PowStep:length(ReadBuffer) % Iterate on the newly received data with 100ms step
      currentDataIndex = length(DataArray) - length(ReadBuffer) + i;

      if isQRSPossible(DataArray(currentDataIndex - PowStep:currentDataIndex))
        samlplesToProcess = getSamplesToProcess;
        [~,qrs_i_raw]=pan_tompkin(samlplesToProcess,DownsampleFs,0);
        qrs = getQRSIndexInDataArray(qrs);
      end
    end
    
    function [qrs] = getQRSIndexInDataArray(qrs)
      % Gets the current qrs array and adds the newly found indexes.
      % The indexes should represent the right position on the DataArray.
 
      % if it is the first time we return all found indexes
      if length(DataArray) < qrswindow
        qrs = qrs_i_raw;
        return 
      end
      disp(currentDataIndex)
      % else append the last value tranformed to the right index
      qrs(end + 1) = qrs_i_raw(end) + currentDataIndex - qrswindow;
    end
    
    function [samlplesToProcess] = getSamplesToProcess
      % Returns a slice of the DataArray to process with pan_tomkins
      % If we are at the beginning of the iteration (we don't have )
      samlplesToProcess = DataArray;
      if length(DataArray) > qrswindow
        samlplesToProcess = DataArray(currentDataIndex - qrswindow:currentDataIndex); % Get the window for which to run pan_tomkins
      end 

    end % end of function getSamplesToProcess
  end % end of function onBytesAvailable
end % end of function start