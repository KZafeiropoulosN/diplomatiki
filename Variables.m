%% This script is used to initialize the values of the sink_plotter

disp('Initializing Variables . . . . . ');

Fs=5000;
Nbuffer = 10000;            % Rx buffer length
pdelay=0.000198;            % Minimum time of writing a character in DataArray
Rbuffer=zeros(1,5000,'int16');
DataArray=zeros(1,2000,'double');
disptime=1;                 % Time interval between showing the status of receive
timeout=10;                 % Time without receiving data the the program will end
BAcnt=1;
cnt = 0;
qrswindow=3000;
PossibleQrsCnt=2;


DSstep=5;
DSFs=Fs/DSstep;
PowStep=30;

offset=1;
FirstTimeFlag=1;



bigcnt=0;
smallcnt=0;
goodcnt=0;


window=40000;
qrs=[];
qrsfile=[];

RRIntervalArray=[];
AdjIntervalArray=[];
NN50=0;

HRArray=[];
FiveMinsMeanArray=[];
FiveMinsDevArray=[];

intervalcnt=1;
