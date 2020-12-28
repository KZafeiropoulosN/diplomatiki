%% This script is used to Set up the figure 

disp('Setting up the figure . . . . . ');

figureHandle = figure('NumberTitle','off',...
    'Name','Electrocardiography',...
    'Color',[0 0 0]);

%hold on;
%subplot(2,1,1);
plotHandle = plot(0,'Marker','.','LineWidth',1,'Color',[0.1328    0.5430    0.1328]);
axis([0 5000 -600 600]);

set(gca,...
    'XColor', [0.9375 1 1],...
    'YColor', [0.9375 1 1]);

% Create xlabel
xlabel('Data','FontWeight','bold','FontSize',12,'Color',[0.8516    0.6445    0.1250]);

% Create ylabel
ylabel('Amplitude','FontWeight','bold','FontSize',12,'Color',[0.8516    0.6445    0.1250]);

% Create title
title('Real Time Data','FontSize',12,'Color',[0.8516    0.6445    0.1250]);
