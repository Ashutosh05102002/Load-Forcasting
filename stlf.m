clear
clc
load Data\DBLoadData.mat


%% Import list of holidays
% A list of New England holidays that span the historical date range is
% imported from an Excel spreadsheet

[num, text] = xlsread('..\Data\Holidays.xls'); 
holidays = text(2:end,1);

% Select forecast horizon
term = 'short';

[X, dates, labels] = genPredictors(data, term, holidays);

%% Split the dataset to create a Training and Test set
% The dataset is divided into two sets, a _training_ set which includes 
% data from 2004 to 2007 and a _test_ set with data from 2008. The training
% set is used for building the model (estimating its parameters). The test
% set is used only for forecasting to test the performance of the model on 
% out-of-sample data. 



% Create training set
trainInd = data.NumDate < datenum('2008-01-01');
trainX = X(trainInd,:);
trainY = data.SYSLoad(trainInd);

% Create test set
testInd = data.NumDate >= datenum('2008-01-01');
testX = X(testInd,:);
testY = data.SYSLoad(testInd);
testDates = dates(testInd);


%Model / Construct Neural Network

N = length(testY);

neurons = 20;
net_nn_1 = fitnet(neurons,'trainlm');

% Training, Validation, Testin Ratios
net.divideParam.trainRatio = 70/100;
net.divideParam.valRatio = 15/100;
net.divideParam.testRatio = 15/100;

net_nn_1 = train(net_nn_1, trainX', trainY');

%Prediction

forecastLoad = sim (net_nn_1,testX')';




%% Compare Forecast Load and Actual Load
% Create a plot to compare the actual load and the predicted load as well
% as compute the forecast error. In addition to the visualization, quantify
% the performance of the forecaster using metrics such as mean absolute
% error (MAE), mean absolute percent error (MAPE) and daily peak forecast
% error.

err = testY-forecastLoad;
fitPlot(testDates, [testY forecastLoad], err);

errpct = abs(err)./testY*100;

fL = reshape(forecastLoad, 24, length(forecastLoad)/24)';
tY = reshape(testY, 24, length(testY)/24)';
peakerrpct = abs(max(tY,[],2) - max(fL,[],2))./max(tY,[],2) * 100;

MAE = mean(abs(err));
MAPE = mean(errpct(~isinf(errpct)));

fprintf('Mean Absolute Percent Error (MAPE): %0.2f%% \nMean Absolute Error (MAE): %0.2f MWh\nDaily Peak MAPE: %0.2f%%\n',...
    MAPE, MAE, mean(peakerrpct))


%% Examine Distribution of Errors
% In addition to reporting scalar error metrics such as MAE and MAPE, the
% plot of the distribution of the error and absolute error can help build
% intuition around the performance of the forecaster

figure;
subplot(3,1,1); hist(err,100); title('Error distribution');
subplot(3,1,2); hist(abs(err),100); title('Absolute error distribution');
line([MAE MAE], ylim); legend('Errors', 'MAE');
subplot(3,1,3); hist(errpct,100); title('Absolute percent error distribution');
line([MAPE MAPE], ylim); legend('Errors', 'MAPE');

%% Group Analysis of Errors
% To get further insight into the performance of the forecaster, we can
% visualize the percent forecast errors by hour of day, day of week and
% month of the year

[yr, mo, da, hr] = datevec(testDates);

% By Hour
clf;
boxplot(errpct, hr+1);
xlabel('Hour'); ylabel('Percent Error Statistics');
title('Breakdown of forecast error statistics by hour');

% By Weekday
figure
boxplot(errpct, weekday(floor(testDates)), 'labels', {'Sun','Mon','Tue','Wed','Thu','Fri','Sat'});
ylabel('Percent Error Statistics');
title('Breakdown of forecast error statistics by weekday');

% By Month
figure
boxplot(errpct, datestr(testDates,'mmm'));
ylabel('Percent Error Statistics');
title('Breakdown of forecast error statistics by month');


%% Generate Weekly Charts
% Create a comparison of forecast and actual load for every week in the
% test set.
generateCharts = true;
if generateCharts
    step = 168*2;
    for i = 0:step:length(testDates)-step
        clf;
        fitPlot(testDates(i+1:i+step), [testY(i+1:i+step) forecastLoad(i+1:i+step)], err(i+1:i+step));
        title(sprintf('MAPE: %0.2f%%', mean(errpct(i+1:i+step))));
        snapnow
        
    end
end
