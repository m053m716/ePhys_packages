function flag = checkForWorker(nigelObj,checkMode)
% CHECKFORWORKER  Checks for worker to determine if this is being run on
%                 local machine or remote server. Also uses the settings in
%                 nigeLab.defaults.Queue as a heuristic if no input
%                 arguments are provided.
%
%  flag = nigeLab.utils.checkForWorker();  Return true if on REMOTE
%
%  flag = nigeLab.utils.checkForWorker(nigelObj);
%
%  flag = nigeLab.utils.checkForWorker('config');
%  --> Runs procedurally generated configuration script, configW
%
%  flag = nigeLab.utils.checkForWorker(nigelObj,'config');
%  --> Does less checks based on nigelObj.UseParallel property flag
%  
%  See Also:
%  NIGELAB.LIBS.DASHBOARD/QOPERATIONS, NIGELAB.DEFAULTS.QUEUE

%% If no inputs, use struct directly from nigeLab.defaults.Queue
if nargin < 1
   flag = false;
   qParams = nigeLab.defaults.Queue;
   if ~qParams.UseParallel && ~qParams.UseRemote
      flag = false;
      return;
   end
   
   if    qParams.UseParallel...              check user preference
         && license('test','Distrib_Computing_Toolbox')... check if toolbox is licensed
         && ~isempty(ver('distcomp'))...           and check if it's installed
         
      job = getCurrentJob;
      
      % if job is empty, we are running locally.
      % Or at least not on a worker.
      flag = ~isempty(job);
      
   elseif   (~license('test','Distrib_Computing_Toolbox')...
         || isempty(ver('distcomp')))...
         && qParams.UseParallel
      
      % Prompt the user to install the correct toolboxes
      nigeLab.utils.cprintf('SystemCommands','Parallel computing toolbox might be uninstalled or unlicensed on this machine.\n');
      nigeLab.utils.cprintf('Comments','But no worries: your code will still be executed serially.\n');
      nigeLab.utils.cprintf('Comments','However, depending on recording size, this can take substantially longer.\n');
   end
   return;
end

%% If more than one input is given
switch class(nigelObj)
   case 'char'
      checkMode = nigelObj;
      if strcmpi(checkMode,'config')  % nargin > 0
         %% in config mode checkForWorker and run the config script
         flag = false;
         if nigeLab.utils.checkForWorker()
            configW;     % run the programmatically generated configuration script; this is generated in qOperations
            flag = true;
         end

      end
   case {'nigeLab.Block','nigeLab.Animal','nigeLab.Tank'}
      if ~isempty(nigelObj.UseParallel)
         compat_flag = nigelObj.UseParallel;
      else
         compat_flag = nigelObj.checkParallelCompatibility();
      end
      
      config_flag = nigelObj.Pars.Queue.UseParallel || ...
                    nigelObj.Pars.Queue.UseRemote;
      if compat_flag ~= config_flag
         nigeLab.utils.cprintf('SystemCommands',['Mismatch between parsed '...
            'parallel configuration and default parameters. \n']);
         str = nigeLab.utils.getNigeLink(class(nigelObj),...
            'checkParallelCompatibility');
         fprintf(1,'Consider re-running %s\n',str);
      end
      
      if compat_flag
         job = getCurrentJob;

         % if job is empty, we are running locally.
         % Or at least not on a worker.
         flag = ~isempty(job);
      else
         flag = false;
      end                  
      
      if nargin > 1
         switch lower(checkMode)
            case 'config'
               if flag
                  configW;
               end

            otherwise
               
         end
      end
      
   otherwise
      
end


end