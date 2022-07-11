% Program to stack phase velocity maps from each event

clear;

isrecalulatealpha = 0;
fixalpha = 1;
demoip = 4;
isfigure = 1;

setup_parameters

% phase_v_path = './helmholtz/'
workingdir = parameters.workingdir;
phase_v_path = [workingdir,'helmholtz/'];

r = 0.05;

comp = parameters.component;
periods = parameters.periods;
lalim = parameters.lalim;
lolim = parameters.lolim;
gridsize = parameters.gridsize;
min_csgoodratio = parameters.min_csgoodratio;
min_phv_tol = parameters.min_phv_tol;
max_phv_tol = parameters.max_phv_tol;
is_raydense_weight = parameters.is_raydense_weight;
err_std_tol = parameters.err_std_tol;
min_event_num = parameters.min_event_num;
issmoothmap = parameters.issmoothmap;
smooth_wavelength = parameters.smooth_wavelength;
event_bias_tol = parameters.event_bias_tol;

xnode=lalim(1):gridsize:lalim(2);
ynode=lolim(1):gridsize:lolim(2);
Nx=length(xnode);
Ny=length(ynode);
[xi yi]=ndgrid(xnode,ynode);

phvmatfiles = dir([phase_v_path,'/*_helmholtz_',comp,'.mat']);

GV_cor_mat = zeros(Nx,Ny,length(phvmatfiles),length(periods));
GV_mat = zeros(Nx,Ny,length(phvmatfiles),length(periods));
raydense_mat = zeros(Nx,Ny,length(phvmatfiles),length(periods));

for ie = 1:length(phvmatfiles)
	temp = load([phase_v_path,phvmatfiles(ie).name]);
	helmholtz = temp.helmholtz;
	if isrecalulatealpha
		for ip=1:length(periods)
			helmholtz(ip).GV_cor = ((helmholtz(ip).GV).^-2 + fixalpha.*helmholtz(ip).amp_term').^-.5;
		end
	end
	event_ids(ie) = {helmholtz(1).id};
			
	disp(helmholtz(1).id);
	for ip=1:length(periods)
        ind = find(helmholtz(ip).GV_cor < min_phv_tol);
        helmholtz(ip).GV_cor(ind) = NaN;
        ind = find(helmholtz(ip).GV_cor > max_phv_tol);
        helmholtz(ip).GV_cor(ind) = NaN;
        ind = find(helmholtz(ip).GV < min_phv_tol);
        helmholtz(ip).GV(ind) = NaN;
        ind = find(helmholtz(ip).GV > max_phv_tol);
        helmholtz(ip).GV(ind) = NaN;
		if helmholtz(ip).goodnum./helmholtz(ip).badnum < min_csgoodratio(ip)
			disp('not enough good cs measurement');
			helmholtz(ip).GV_cor(:) = NaN;
			helmholtz(ip).GV(:) = NaN;
        end
		
        GV_cor_mat(:,:,ie,ip) = helmholtz(ip).GV_cor;
        GV_mat(:,:,ie,ip) = helmholtz(ip).GV;

        raydense_mat(:,:,ie,ip) = helmholtz(ip).raydense;
	end
end

avgphv = average_GV_mat(GV_cor_mat, raydense_mat, parameters);
temp = average_GV_mat(GV_mat, raydense_mat, parameters);
for ip=1:length(avgphv)
	avgphv(ip).GV_cor = avgphv(ip).GV;
	avgphv(ip).GV = temp(ip).GV;
end

% Calculate std, remove the outliers
GV_mat = 1./GV_mat;
GV_cor_mat = 1./GV_cor_mat;
for ip=1:length(periods)
	for i = 1:Nx
		for j=1:Ny
			avgphv(ip).GV_std(i,j) = nanstd(GV_mat(i,j,:,ip));
			avgphv(ip).GV_cor_std(i,j) = nanstd(GV_cor_mat(i,j,:,ip));
			ind = find( abs(GV_mat(i,j,:,ip) - 1./avgphv(ip).GV(i,j)) > err_std_tol*avgphv(ip).GV_std(i,j));
			GV_mat(i,j,ind,ip) = NaN;
			ind = find( abs(GV_cor_mat(i,j,:,ip) - 1./avgphv(ip).GV_cor(i,j)) > err_std_tol*avgphv(ip).GV_cor_std(i,j));
			GV_cor_mat(i,j,ind,ip) = NaN;
		end
	end
end
GV_mat = 1./GV_mat;
GV_cor_mat = 1./GV_cor_mat;

% calculate the averaged phase velocity again
avgphv = average_GV_mat(GV_cor_mat, raydense_mat, parameters);
temp = average_GV_mat(GV_mat, raydense_mat, parameters);
for ip=1:length(avgphv)
	avgphv(ip).GV_cor = avgphv(ip).GV;
	avgphv(ip).GV = temp(ip).GV;
end

% remove bias events
for ip=1:length(periods)
avg_GV = avgphv(ip).GV_cor;
mean_phv = nanmean(avg_GV(:));
badnum = 0;
for ie=1:length(event_ids)
	GV = GV_cor_mat(:,:,ie,ip);
	diff_phv = GV-avg_GV;
	diff_percent = nanmean(diff_phv(:))/mean_phv*100;
	if abs(diff_percent) > event_bias_tol;
% 		matfile = dir(fullfile('helmholtz',[char(event_ids(ie)),'*.mat']));
% 		load(fullfile('helmholtz',matfile(1).name));
        matfile = dir(fullfile(workingdir,'helmholtz',[char(event_ids(ie)),'*.mat']));
		load(fullfile(workingdir,'helmholtz',matfile(1).name));
		evla = helmholtz(1).evla;
		evlo = helmholtz(1).evlo;
		epi_dist = distance(evla,evlo,mean(lalim),mean(lolim));
		badnum = badnum+1;
		ind = find(~isnan(GV(:)));
		stemp = sprintf('remove %s: id %d, ip %d, dist %f, bias: %f percent, good pixels: %d', char(event_ids(ie)),ie,ip,epi_dist, diff_percent,length(ind));
		disp(stemp)
		GV_cor_mat(:,:,ie,ip) = NaN;
		GV_mat(:,:,ie,ip) = NaN;
	end
end
end

% calculate the averaged phase velocity again
avgphv = average_GV_mat(GV_cor_mat, raydense_mat, parameters);
temp = average_GV_mat(GV_mat, raydense_mat, parameters);
for ip=1:length(avgphv)
	avgphv(ip).GV_cor = avgphv(ip).GV;
	avgphv(ip).GV = temp(ip).GV;
end

% re-Calculate std
for ip=1:length(periods)
	for i = 1:Nx
		for j=1:Ny
			avgphv(ip).GV_std(i,j) = nanstd(GV_mat(i,j,:,ip));
			avgphv(ip).GV_cor_std(i,j) = nanstd(GV_cor_mat(i,j,:,ip));
		end
	end
end

% fill in information
for ip=1:length(periods)
	avgphv(ip).xi = xi;
	avgphv(ip).yi = yi;
	avgphv(ip).xnode = xnode;
	avgphv(ip).ynode = ynode;
	avgphv(ip).period = periods(ip);
end

if issmoothmap
	disp(['Smoothing map based on wavelength']);
	for ip=1:length(periods)
		disp(ip);
		D = smooth_wavelength*nanmean(avgphv(ip).GV(:))*periods(ip);
		GV = smoothmap(xi,yi,avgphv(ip).GV,D);
		GV(find(isnan(avgphv(ip).GV))) = NaN;
		avgphv(ip).GV = GV;
		GV_cor = smoothmap(xi,yi,avgphv(ip).GV_cor,D);
		GV_cor(find(isnan(avgphv(ip).GV_cor))) = NaN;
		avgphv(ip).GV_cor = GV_cor;
	end	
end


save([workingdir,'helmholtz_stack_',comp,'.mat'],'avgphv','GV_mat','GV_cor_mat','raydense_mat','event_ids');


% plot section

if isfigure
figure(71)
clf
%for ip = 1:length(periods)
ip = demoip
	subplot(2,2,2)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
	h1=surfacem(xi,yi,avgphv(ip).GV_cor);
	% set(h1,'facecolor','interp');
	title(['stack for corrected phv,','Periods: ',num2str(periods(ip))],'fontsize',15)
	avgv = nanmean(avgphv(ip).GV(:));
	if isnan(avgv)
% 		continue;
	end
	caxis([avgv*(1-r) avgv*(1+r)])
	colorbar
	load seiscmap
	colormap(seiscmap)
	subplot(2,2,1)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
	h1=surfacem(xi,yi,avgphv(ip).GV);
	% set(h1,'facecolor','interp');
	title(['stack for dynamics phv,','Periods: ',num2str(periods(ip))],'fontsize',15)
	avgv = nanmean(avgphv(ip).GV(:));
	if isnan(avgv)
% 		continue;
	end
	caxis([avgv*(1-r) avgv*(1+r)])
	colorbar
	load seiscmap
	colormap(seiscmap)

	subplot(2,2,3)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
	h1=surfacem(xi,yi,avgphv(ip).GV_std);
	title(['Original STD,','Periods: ',num2str(periods(ip))],'fontsize',15)
	meanstd = nanmean(avgphv(ip).GV_std(:));
	if ~isnan(meanstd)
		caxis([0 2*meanstd])
	end
	colorbar
	load seiscmap
	colormap(seiscmap)

	subplot(2,2,4)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
	h1=surfacem(xi,yi,avgphv(ip).GV_cor_std);
	title(['corrected STD,','Periods: ',num2str(periods(ip))],'fontsize',15)
	if ~isnan(meanstd)
		caxis([0 2*meanstd])
	end
	colorbar
	load seiscmap
	colormap(seiscmap)

%%
N=3; M = floor(length(periods)/N)+1;
figure(89)
clf
sgtitle('stack for dynamic phv','fontweight','bold','fontsize',18)
for ip = 1:length(periods)
	subplot(M,N,ip)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
	h1=surfacem(xi,yi,avgphv(ip).GV);
	% set(h1,'facecolor','interp');
	title(['Periods: ',num2str(periods(ip))],'fontsize',15)
	avgv = nanmean(avgphv(ip).GV(:));
	if isnan(avgv)
		continue;
	end
	caxis([avgv*(1-r) avgv*(1+r)])
	colorbar
	load seiscmap
	colormap(seiscmap)
end
drawnow;

%%
figure(90)
clf
sgtitle('Std for dynamic phv','fontweight','bold','fontsize',18)
for ip = 1:length(periods)
	subplot(M,N,ip)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
	h1=surfacem(xi,yi,avgphv(ip).GV_std);
	% set(h1,'facecolor','interp');
	title(['Periods: ',num2str(periods(ip))],'fontsize',15)
	colorbar
	load seiscmap
	colormap(seiscmap)
	meanstd = nanmean(avgphv(ip).GV_std(:));
	if ~isnan(meanstd)
		caxis([0 2*meanstd])
	end
end
drawnow;

%%
figure(91)
clf
sgtitle('stack for structure phv','fontweight','bold','fontsize',18)
for ip = 1:length(periods)
	subplot(M,N,ip)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
	h1=surfacem(xi,yi,avgphv(ip).GV_cor);
	% set(h1,'facecolor','interp');
	title(['Periods: ',num2str(periods(ip))],'fontsize',15)
	avgv = nanmean(avgphv(ip).GV(:));
	if isnan(avgv)
		continue;
	end
	caxis([avgv*(1-r) avgv*(1+r)])
	colorbar
	load seiscmap
	colormap(seiscmap)
end
drawnow;

%%
figure(92)
clf
sgtitle('Std for structure phv','fontweight','bold','fontsize',18)
for ip = 1:length(periods)
	subplot(M,N,ip)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
	h1=surfacem(xi,yi,avgphv(ip).GV_cor_std);
	% set(h1,'facecolor','interp');
	title(['Periods: ',num2str(periods(ip))],'fontsize',15)
	colorbar
	load seiscmap
	colormap(seiscmap)
	meanstd = nanmean(avgphv(ip).GV_std(:));
	if ~isnan(meanstd)
		caxis([0 2*meanstd])
	end
%	caxis([0 0.5])
end
drawnow;

%%
figure(93)
clf
sgtitle('diff phv','fontweight','bold','fontsize',18)
for ip = 1:length(periods)
	subplot(M,N,ip)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
    phvdiff = (avgphv(ip).GV_cor-avgphv(ip).GV)./avgphv(ip).GV*100;
    h1=surfacem(xi,yi,phvdiff);
% 	h1=surfacem(xi,yi,avgphv(ip).GV_cor-avgphv(ip).GV);
	% set(h1,'facecolor','interp');
	title(['Periods: ',num2str(periods(ip))],'fontsize',15)
	colorbar
	load seiscmap
	colormap(seiscmap)
%	caxis([0 0.5])
    caxis(max(abs(phvdiff(:)))*[-1 1])
end
drawnow;

%%
figure(95)
clf
sgtitle('Ray density','fontweight','bold','fontsize',18)
for ip = 1:length(periods)
	subplot(M,N,ip)
	ax = worldmap(lalim, lolim);
	set(ax, 'Visible', 'off')
	h1=surfacem(xi,yi,avgphv(ip).sumweight);
	% set(h1,'facecolor','interp');
	title(['Periods: ',num2str(periods(ip))],'fontsize',15)
	colorbar
	load seiscmap
	colormap(seiscmap)
end
drawnow;

%% 1-D Average
figure(96)
clf;

% Phase velocity
subplot(1,2,1); axis square; hold on;
GV_1d = [];
GV_std_1d = [];
GV_cor_1d = [];
GV_cor_std_1d = [];
for ip = 1:length(periods)
    GV_1d(ip) = nanmean(avgphv(ip).GV(:));
    GV_std_1d(ip) = nanmean(avgphv(ip).GV_std(:));
    GV_cor_1d(ip) = nanmean(avgphv(ip).GV_cor(:));
    GV_cor_std_1d(ip) = nanmean(avgphv(ip).GV_cor_std(:));
end
title('1-D Phase Velocity','fontweight','bold','fontsize',18)
errorbar(periods,GV_1d,GV_std_1d,'o-b','linewidth',2);
errorbar(periods-1,GV_cor_1d,GV_cor_std_1d,'o-r','linewidth',2);
xlabel('Period (s)');
ylabel('Phase Velocity (km/s)');
legend('Dynamic','Structural','location','southeast');
set(gca,'linewidth',1.5,'fontsize',15,'box','on');

% Uncertainty
subplot(1,2,2); axis square;  hold on;
title('Average Standard Deviation','fontweight','bold','fontsize',18)
plot(periods,GV_std_1d,'o-b','linewidth',2);
plot(periods-1,GV_cor_std_1d,'o-r','linewidth',2);
xlabel('Period (s)');
ylabel('Standard Deviation (km/s)');
legend('Dynamic','Structural','location','southeast');
set(gca,'linewidth',1.5,'fontsize',15,'box','on');

end
