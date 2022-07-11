%plot all average phase velocity
%period domain form 20 -150 set in parameter
clear;
clc;
clf;
figurepath = './figure/avgph_plot/';
% workingdir = parameters.workingdir;
% eventmatpath = [workingdir,'eventmat/'];
% outwinpath = [workingdir,'winpara/'];

if ~exist(figurepath,'dir')
	mkdir(figurepath)
end
eventmat_files = dir('CSmeasure/*.mat');
setup_parameters;
for ie=1:length(eventmat_files)
	load(fullfile('CSmeasure',eventmat_files(ie).name));
    
	if isfield(eventcs,'avgphv')
		h=figure(1);
        set(gcf,'Position',[0,0,1000,500])
        
        plot(parameters.periods,eventcs.avgphv,'r-*')
        title([eventcs.id,' average phase velocity'])
        xlim([20,150])
        xlabel ('');
        xlabel('Period (s)');
        ylabel('Phase Velocity')
        figfile=[figurepath,eventcs.id,'.fig'];
        savefig(gcf,figfile);
	end
    
end

