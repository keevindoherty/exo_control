%%RealTime Data Streaming with Delsys SDK

% Copyright (C) 2011 Delsys, Inc.
% 
% Permission is hereby granted, free of charge, to any person obtaining a 
% copy of this software and associated documentation files (the "Software"), 
% to deal in the Software without restriction, including without limitation 
% the rights to use, copy, modify, merge, publish, and distribute the 
% Software, and to permit persons to whom the Software is furnished to do so, 
% subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in 
% all copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
% DEALINGS IN THE SOFTWARE.

%% Human Hand Exoskeleton Control Script

% Sensorimotor Control Lab
% Stevens Institute of Technology
% Summer 2014
% Author: Kevin Doherty
% 
%
% Revision 2 (ALPHA)
% The following runs training and real-time classification of grasps.
% Included:
%   Delsys TCP/IP EMG Interface (Delsys SDK)
%   Grasp display for feedback during testing without the hand exoskeleton.
%   Necessary utilities for serial communication with Arduino (commented).
%   
% NOTE: The following is prototype code. All of the code written here
% is still subject to testing and modification. We have thus far
% demonstrated control of a prototype hand exoskeleton with 2 grasps,
% but the code presented here can be easily scaled to the number of sensors
% on the Delsys EMG System (16) and any number of grasps desired.
%
% Commented code remains for various testing purposes.

function exoControl_rev2


% CHANGE THIS TO THE IP OF THE COMPUTER RUNNING THE TRIGNO CONTROL UTILITY
HOST_IP = '155.246.72.128';
%%
%This example program communicates with the Delsys SDK to stream 16
%channels of EMG data and 48 channels of ACC data.

task = input('Train or Load Training Data? (Enter Train or Load)\n', 's');
numSensorsUsed = input('Number of Electrodes?\n', 's');


%% Create the required objects

%Define number of sensors
NUM_SENSORS = 16;

%handles to all plots
global plotHandlesEMG;
plotHandlesEMG = zeros(NUM_SENSORS,1);
global plotHandlesACC;
plotHandlesACC = zeros(NUM_SENSORS*3, 1);
global count;
count = 1;
global num_Bins;
global bins;
bins = zeros(20,1);
global comcount;
comcount = 0;

%TCPIP Connection to stream EMG Data
interfaceObjectEMG = tcpip(HOST_IP,50041);
interfaceObjectEMG.InputBufferSize = 6400;

%TCPIP Connection to stream ACC Data
interfaceObjectACC = tcpip(HOST_IP,50042);
interfaceObjectACC.InputBufferSize = 6400;

%TCPIP Connection to communicate with SDK, send/receive commands
commObject = tcpip(HOST_IP,50040);

%Timer object for drawing plots.
t = timer('Period', .1, 'ExecutionMode', 'fixedSpacing', 'TimerFcn', {@updatePlots, plotHandlesEMG});
global data_arrayEMG
data_arrayEMG = [];
global data_arrayACC
data_arrayACC = [];

%% Set up the plots


axesHandlesEMG = zeros(NUM_SENSORS,1);
axesHandlesACC = zeros(NUM_SENSORS,1);

%initiate the EMG figure
figureHandleEMG = figure('Name', 'EMG Data','Numbertitle', 'off',  'CloseRequestFcn', {@localCloseFigure, interfaceObjectEMG, interfaceObjectACC, commObject, t});
set(figureHandleEMG, 'position', [50 200 750 750])

for i = 1:NUM_SENSORS
    axesHandlesEMG(i) = subplot(4,4,i);

    plotHandlesEMG(i) = plot(axesHandlesEMG(i),0,'-y','LineWidth',1);

    set(axesHandlesEMG(i),'YGrid','on');
    %set(axesHandlesEMG(i),'YColor',[0.9725 0.9725 0.9725]);
    set(axesHandlesEMG(i),'XGrid','on');
    %set(axesHandlesEMG(i),'XColor',[0.9725 0.9725 0.9725]);
    set(axesHandlesEMG(i),'Color',[.15 .15 .15]);
    set(axesHandlesEMG(i),'YLim', [-.005 .005]);
    set(axesHandlesEMG(i),'YLimMode', 'manual');
    set(axesHandlesEMG(i),'XLim', [0 2000]);
    set(axesHandlesEMG(i),'XLimMode', 'manual');
    
    if(mod(i, 4) == 1)
        ylabel(axesHandlesEMG(i),'V');
    else
        set(axesHandlesEMG(i), 'YTickLabel', '')
    end
    
    if(i >12)
        xlabel(axesHandlesEMG(i),'Samples');
    else
        set(axesHandlesEMG(i), 'XTickLabel', '')
    end
    
    title(sprintf('EMG %i', i)) 
end

%initiate the ACC figure
figureHandleACC = figure('Name', 'ACC Data', 'Numbertitle', 'off', 'CloseRequestFcn', {@localCloseFigure, interfaceObjectEMG, interfaceObjectACC, commObject, t});
set(figureHandleACC, 'position', [850 200 750 750]);

for i= 1:NUM_SENSORS
    axesHandlesACC(i) = subplot(4, 4, i);
    hold on
    plotHandlesACC(i*3-2) = plot(axesHandlesACC(i), 0, '-y', 'LineWidth', 1);    
    plotHandlesACC(i*3-1) = plot(axesHandlesACC(i), 0, '-y', 'LineWidth', 1);   
    plotHandlesACC(i*3) = plot(axesHandlesACC(i), 0, '-y', 'LineWidth', 1);
    hold off 
    
    set(plotHandlesACC(i*3-2), 'Color', 'r')
    set(plotHandlesACC(i*3-1), 'Color', 'b')
    set(plotHandlesACC(i*3), 'Color', 'g')    
    set(axesHandlesACC(i),'YGrid','on');
    %set(axesHandlesACC(i),'YColor',[0.9725 0.9725 0.9725]);
    set(axesHandlesACC(i),'XGrid','on');
    %set(axesHandlesACC(i),'XColor',[0.9725 0.9725 0.9725]);
    set(axesHandlesACC(i),'Color',[.15 .15 .15]);
    set(axesHandlesACC(i),'YLim', [-8 8]);
    set(axesHandlesACC(i),'YLimMode', 'manual');
    set(axesHandlesACC(i),'XLim', [0 2000/13.5]);
    set(axesHandlesACC(i),'XLimMode', 'manual');
    
    if(i > 12)
        xlabel(axesHandlesACC(i),'Samples');
    else
        set(axesHandlesACC(i), 'XTickLabel', '');
    end
    
    if(mod(i, 4) == 1)
        ylabel(axesHandlesACC(i),'g');
    else
        set(axesHandlesACC(i) ,'YTickLabel', '')
    end
    
    title(sprintf('ACC %i', i)) 

end


%% Setup interface object to read chunks of data
% Define a callback function to be executed when desired number of bytes
% are available in the input buffer
 bytesToReadEMG = 1728;
 interfaceObjectEMG.BytesAvailableFcn = {@localReadAndPlotMultiplexedEMG,plotHandlesEMG,bytesToReadEMG};
 interfaceObjectEMG.BytesAvailableFcnMode = 'byte';
 interfaceObjectEMG.BytesAvailableFcnCount = bytesToReadEMG;
 
 bytesToReadACC = 384;
interfaceObjectACC.BytesAvailableFcn = {@localReadAnPlotMultiplexedACC, plotHandlesACC, bytesToReadACC};
interfaceObjectACC.BytesAvailableFcnMode = 'byte';
interfaceObjectACC.BytesAvailableFcnCount = bytesToReadACC;

drawnow
start(t);

%pause(1);
%% 
% Open the interface object
try
    fopen(interfaceObjectEMG);
    fopen(interfaceObjectACC);
    fopen(commObject);
catch
    localCloseFigure(figureHandleACC,1 ,interfaceObjectACC, interfaceObjectEMG, commObject, t);
    delete(figureHandleEMG);
    error('CONNECTION ERROR: Please start the Delsys Trigno Control Application and try again');
end



%%
% Send the commands to start data streaming
% s = serial('COM10');
% fopen(s);
% ask type of classifier
graspstring = native2unicode([255 2 1 0 0 0 0 0 0 0 0 0 0 0 2]);
reststring = native2unicode([255 2 2 0 0 0 0 0 0 0 0 0 0 0 3]);
displaytask = figure;
fprintf(commObject, sprintf(('START\r\n\r')));
[b, a] = butter(5, [50 1000]/2000,'bandpass'); % Initialize bandpass filter settings

%% Start Training
    if(strcmp(task,'Train')) 
        disp('Rest and press any key'); %Display 'Rest and press any key'
        pause; %wait for key press
        %feat1 = zeros(500,1);
        %feat2 = zeros(500,1);
        %feat3 = zeros(500,1);
        %feat4 = zeros(500,1);
        %feat5 = zeros(500,1);
        %feat6 = zeros(500,1);
        while(count < 51) %take a few seconds of data
            for i=1:numSensorsUsed
                %bindata(:,i) = data_arrayEMG(i:16:end)'
                bindata(:,i) = [bindata(:,i) ; filtfilt(b,a,double(data_arrayEMG(i:16:end)'))];
            end
            %bin(:, 1) = filtfilt(b,a,double(bindata'));
            %bin2(:,1) = filtfilt(b,a,double(bindata2'));
            %feat1(count, 1) = MAV(bin);
            %feat3(count, 1) = MAV(bin2);
            count = count+1;
            pause(.01);
        end
        %% Extract and Label Features for Resting
        
        for i = 1:numSensorsUsed %%%fix this up
            bin = bin_emg(bindata(:,i));
            feat1(:,i) = MAV(bin);
            feat2(:,i) = WL(bin);
        end
        restfeat = [feat1, feat2];
        count = 1;%extract features
        restlabel = ones(length(feat1),1);    %array of 1's corresponds to training data

        %% Collect Training Data for Grasping
        
        disp('Grasp and press any key');%Display 'Grasp and press any key'
        pause;%wait for key press
        while(count < 51)
            for i=1:numSensorsUsed
                bindata(:,i) = [bindata(:,i) ; filtfilt(b,a,double(data_arrayEMG(i:16:end)'))];
            end
            count = count+1;
            pause(.01);
        end
        
        %% Extract and Label Features for Grasping
        for i = 1:numSensorsUsed %%%fix this up
            bin = bin_emg(bindata(:,i));
            feat1(:,i) = MAV(bin);
            feat2(:,i) = WL(bin);
        end
        graspfeat = [feat1;feat2];
        count = 1;
        grasplabel = 2*ones(length(feat2),1);%array of 2's or G's corresponds to training data
        
        %% Collect Training Data for Pinching
        
        disp('Pinch and press any key');
        pause;
        while(count < 51)
%             bindata = data_arrayEMG(1:16:end);
%             bindata2 = data_arrayEMG(2:16:end);
%             bin(:, 1) = filtfilt(b,a,double(bindata'));
%             bin2(:,1) = filtfilt(b,a,double(bindata2'));
%             feat5(count, 1) = MAV(bin);
%             feat6(count,1) = MAV(bin2);
%             count = count+1;
%             pause(.0005);
            for i=1:numSensorsUsed
                %bindata(:,i) = data_arrayEMG(i:16:end)'
                bindata(:,i) = [bindata(:,i) ; filtfilt(b,a,double(data_arrayEMG(i:16:end)'))];
            end
            count = count + 1;
            pause(.01);
        end
        
        %% Extract and Label Features for Pinching
        
        for i = 1:numSensorsUsed %%%fix this up
                bin = bin_emg(bindata(:,i));
                feat1(:,i) = MAV(bin);
                feat2(:,i) = WL(bin);
        end
        pinchlabel = 3*ones(length(feat5),1);
        
        %% Organize Training Data and Labels for All Postures
        
%        TRAINDATA = [feat1, feat3; feat2, feat4; feat5, feat6]; %append data and labels
%        TRAINDATA = [feat1;feat2;feat5];
%        TRAINDATA = [feat1;feat2]
%        TRAINLABEL = [restlabel; grasplabel; pinchlabel];

        TRAINDATA = [restfeat; graspfeat];
        TRAINLABEL = [restlabel;grasplabel];
         
         %% Save Training Configuration
         
         saveToken = input('Save Training Configuration? Y or N?\n', 's');
         if(strcmp(saveToken, 'Y')) %Save Training Configuration to .mat
             fileName = input('Enter filename:\n','s');
             save(fileName + '.mat', 'numSensorsUsed', 'TRAINDATA', 'TRAINLABEL');
             disp('Press any key to run');
             pause;
             task = 'Run';             
        else
             disp('Press any key to run');
             pause;
             task = 'Run';
         end
    end
    
    %% Load Training Configuration to Run
    
    if(strcmp(task,'Load'))
        fileToLoad = input('Enter name of Training Config to Load:\n','s');
        load(fileToLoad + '.mat', 'numSensorsUsed', 'TRAINDATA', 'TRAINLABEL');
        disp('Make sure ' + numSensorsUsed + 'electrodes are connected and press any key to run');
        pause;
        task = 'Run';
    end
    
    %% Run Real-Time Classification
    while(strcmp(task,'Run'))
        count = 1;
        runfeat = zeros(50,1);
        while(count < 51) %FIX THIS SECTION!!
            bindata = data_arrayEMG(1:16:end);
            bindata2 = data_arrayEMG(2:16:end);
            bin(:, 1) = filtfilt(b,a,double(bindata'));
            bin2(:,1) = filtfilt(b,a,double(bindata2'));
            runfeat(count, 1) = MAV(bin);
            %runfeat(count, 2) = iEMG(bin2);
            count = count+1;
            pause(.01);
        end % Take 1 bin of data
        result = classify(runfeat, TRAINDATA, TRAINLABEL, 'quadratic'); %Classify bin
        
        %% Handle Serial output and Display
        if(result == 1)
%             while(comcount < 20)
                 str = 'REST';
%                 fwrite(s, reststring);
%                 pause(.001);
%                 comcount = comcount +1;
%             end
%             comcount = 0;
        elseif(result == 2)
%             while(comcount < 20)
                 str = 'GRASP';
%                 fwrite(s, graspstring);
%                 pause(.001);
%                 comcount = comcount+1;
%             end
%             comcount = 0;
            %sim('simtest'); %????
        %else
        %    str = 'PINCH';
        end
        %result = multisvm(TRAINDATA, TRAINLABEL, runfeat);
        %result = ''; %output result
        %disp(result);
        clf
        text(.5,.5,str, 'FontSize', 36);
    end
%%
% Display the plot

%snapnow;


%% Implement the bytes available callback
%The localReadandPlotMultiplexed functions check the input buffers for the
%amount of available data, mod this amount to be a suitable multiple.

%Because of differences in sampling frequency between EMG and ACC data, the
%ratio of EMG samples to ACC samples is 13.5:1

%We use a ratio of 27:2 in order to keep a whole number of samples.  
%The EMG buffer is read in numbers of bytes that are divisible by 1728 by the
%formula (27 samples)*(4 bytes/sample)*(16 channels)
%The ACC buffer is read in numbers of bytes that are divisible by 384 by
%the formula (2 samples)*(4 bytes/sample)*(48 channels)
%Reading data in these amounts ensures that full packets are read.  The 
%size limits on the dataArray buffers is to ensure that there is always one second of
%data for all 16 sensors (EMG and ACC) in the dataArray buffers
function localReadAndPlotMultiplexedEMG(interfaceObjectEMG, ~,~,~, ~)

bytesReady = interfaceObjectEMG.BytesAvailable;
bytesReady = bytesReady - mod(bytesReady, 1728);

if (bytesReady == 0)
    return
end
global data_arrayEMG
data = cast(fread(interfaceObjectEMG,bytesReady), 'uint8');
data = typecast(data, 'single');




if(size(data_arrayEMG, 1) < 32832)
    data_arrayEMG = [data_arrayEMG; data];
else
    data_arrayEMG = [data_arrayEMG(size(data,1) + 1:size(data_arrayEMG, 1));data];
end


function localReadAnPlotMultiplexedACC(interfaceObjectACC, ~, ~, ~, ~)

bytesReady = interfaceObjectACC.BytesAvailable;
bytesReady = bytesReady - mod(bytesReady, 384);

if(bytesReady == 0)
    return
end
global data_arrayACC
data = cast(fread(interfaceObjectACC, bytesReady), 'uint8');
data = typecast(data, 'single');





if(size(data_arrayACC, 1) < 7296)
    data_arrayACC = [data_arrayACC; data];
else
    data_arrayACC = [data_arrayACC(size(data, 1) + 1:size(data_arrayACC, 1)); data];
end


%% Update the plots
%This timer callback function is called on every tick of the timer t.  It
%demuxes the dataArray buffers and assigns that channel to its respective
%plot.
function updatePlots(obj, Event,  tmp)
global data_arrayEMG
global plotHandlesEMG
global count
for i = 1:size(plotHandlesEMG, 1) 
    data_ch = data_arrayEMG(i:16:end);
    set(plotHandlesEMG(i), 'Ydata', data_ch)
end
%bindata = data_arrayEMG(1:16:end);
%bindata2 = data_arrayEMG(2:16:end);
%if(count == 21)
%    count = 1;
%end
%if(count <= 20)
%    bin(count, :) = bindata;
%    bin2(count,:) = bindata2;
    %if(count == 20)
    %    if(iEMG(bin(:,1)) > .000009)
    %        type = 'G'
    %    else
    %        iEMG(bin(:,1))
    %        type = 'R'
    %    end
    %end
%    count = count+1;
%end
global data_arrayACC
global plotHandlesACC
for i = 1:size(plotHandlesACC, 1)
    data_ch = data_arrayACC(i:48:end);
    set(plotHandlesACC(i), 'Ydata', data_ch)
end
drawnow

%function RUN()

%% Implementation of Real Time SVM Training
% prelabels needs to be globally defined as 10 sec worth of R, 10 sec of PG
% and 10 sec of WHG
% trainbool will come from some button that decides if training is
% happening or not
% data will be the raw emg data from all channels
%function updateTrain(trainbool, data, prelabels)
%this for loop gets 1 set of data, needs to iterate 200x for .1 second bin
%j=1;
%while(j<=200)
%    for i = 1:size(plotHandlesEMG,1)
%        bin(:,i) = [bin(:,i); data_arrayEMG(i:16:end)];
%    end
%    j = j+1;
%end
%trainfeat = featextract(bin)
%train(trainfeat,prelabels) or append trainfeat to previous feat and append
%prelabels to previous labels   
%% Implement the close figure callback
%This function is called whenever either figure is closed in order to close
%off all open connections.  It will close the EMG interface, ACC interface,
%commands interface, and timer object
function localCloseFigure(figureHandle,~,interfaceObject1, interfaceObject2, commObject, t)
%% 
% Clean up the network objects
if isvalid(interfaceObject1)
    fclose(interfaceObject1);
    delete(interfaceObject1);
    clear interfaceObject1;
end
if isvalid(interfaceObject2)
    fclose(interfaceObject2);
    delete(interfaceObject2);
    clear interfaceObject2;
end



if isvalid(t)
   stop(t);
   delete(t);
end

if isvalid(commObject)
    fclose(commObject);
    delete(commObject);
    clear commObject;
end

%% 
% Close the figure window
delete(figureHandle);
