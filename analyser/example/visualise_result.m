clear all
close all

method = 6
filename = "result_single_tool_22222.mat";
locs = [0,-0.05,0.05,-0.1,0.1];
locs = locs+0.05;
figure
subplot(2,1,1)
[std_resultx, mean_resultx] = visualise_optical_check(filename,locs,method,true)
ylim([-125,200])
subplot(2,1,2)
[std_resulty, mean_resulty] = visualise_optical_check(filename,locs,method,false)

leg = legend('Measured offset', 'Set offset');
leg.Position = [0.654635402636077,0.44988888698154,0.25044484312424,0.088333335240682];

ylim([-100,200])

set(gcf,'Position',[0,100,450,600])
%export_fig('optical_calibration.png', '-dpng', '-transparent', '-r600');

filename = "result_multi_tool_12345.mat";
locs = [0,0,0,0,0];
figure
subplot(2,1,1)
[std_resultx, mean_resultx] = visualise_optical_vs_inductive(filename,'data/xcal2.mat', locs,method,true)
subplot(2,1,2)
[std_resulty, mean_resulty] = visualise_optical_vs_inductive(filename,'data/ycal2.mat',locs,method,false)

leg = legend('Optical', 'Inductive');
leg.Position = [0.654635402636077,0.44988888698154,0.25044484312424,0.088333335240682];
set(gcf,'Position',[0,100,450,600])
%export_fig('optical_vs_inductive_without_offsets.png', '-dpng', '-transparent', '-r600');
