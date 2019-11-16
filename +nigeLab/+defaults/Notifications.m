function pars = Notifications(paramName)
%% NOTIFICATIONS     Default notifications parameters for nigeLab
%
%  pars = nigeLab.defaults.NOTIFICATIONS(); % returns full struct
%  pars = nigeLab.defaults.NOTIFICATIONS(paramName); % returns single param
%
% By: Max Murphy  v1.0  2019-07-11  Original version (R2017a)

%%
pars = struct;
pars.NMaxNameChars = 15;  % If less than this, uses full name on notifications

% For below, see nigeLab.utils.jobTag2Pct(), as well as Block method
% notifyUser():
pars.TagDelim = '||'; % This should separate TagString between naming and % complete
pars.TagString.String = ['%s.%s %s' pars.TagDelim '%.3d%%']; % regexp for Tag updates
pars.TagString.Vars = {'blockObj.Meta.AnimalID',...
                          'blockObj.Meta.RecID'};
%               Animal.Block operation TagDelim progress



pars.NotifyString.String = '\t%s.%s -> %s: %.3d%%'; % regexp for command window updates
pars.NotifyString.Vars = {'blockObj.Meta.AnimalID',...
                          'blockObj.Meta.RecID'};
%                 Animal.Block -> operation : progress
pars.NotifyTimer = 0.5; % timer period (seconds) for remote monitor checks
pars.UseParallel=0;
pars.MinIncrement = 5;







%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin > 0
   if isfield(pars,paramName)
      pars = pars.(paramName);
   else
      warning('%s is not a field. Returning full parameters struct.',paramName);
   end
end

end

