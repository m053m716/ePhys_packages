function pars = Queue(paramName)
%% QUEUE  Template for initializing parameters for submitting jobs to queue
%
%  pars = nigeLab.defaults.Queue;
%  pars = nigeLab.defaults.Queue(paramName);  % returns a single parameter
%
% By: MAECI 2018 collaboration (Federico Barban & Max Murphy)

%%
pars = struct;

% Only specify this field if you want to force use of a single cluster
% pars.Cluster = 'CPLMJS'; 
pars.UseParallel = true; % set to false to switch to serial processing mode
% pars.UseRemote = false; % set false to use local machine
pars.UseRemote = true;

% UNC path and cluster list for Matlab Distributed Computing Toolbox
pars.UNCPath.RecDir = '\\kumc.edu\data\research\SOM RSCH\NUDOLAB\Recorded_Data\'; 
pars.UNCPath.SaveLoc = '\\kumc.edu\data\research\SOM RSCH\NUDOLAB\Processed_Data\';
                
pars.ClusterList = {'CPLMJS'; 'CPLMJS2'; 'CPLMJS3'};
pars.NWorkerMinMax = [1,1]; % Min & Max # workers to assign to a job
pars.WaitTimeSec = 1; % Time to wait between checking for new cluster
pars.InitTimeSec = 5; % Time to wait when initializing cluster

if nargin > 0
   if isfield(pars,paramName)
      pars = pars.(paramName);
   else
      warning('%s is not a field. Returning full parameters struct.',paramName);
   end
end


end

