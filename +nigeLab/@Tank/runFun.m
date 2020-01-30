function runFun(tankObj,f,varargin)
% RUNFUN   Run function f on all child Blocks in tank
%
%  example:
%  runFun(myTank,'checkMask'); Runs the function 'checkMask' of all child
%                              Blocks in the Tank.
%
%  runFun(myTank,'fcn_handle',arg1,arg2,...);
%  --> As long as input arg is same for all block cases this works

%% Check if it is a valid method
clc;
fprintf(1,' \n');
nigeLab.utils.cprintf('*Blue','%s: ',tankObj.Name);
mc = ?nigeLab.Block;
m = {mc.MethodList.Name};
if ismember(f,m)
   nigeLab.utils.cprintf('*Magenta','%s method\n',f);
else
   nigeLab.utils.cprintf([0.3 0.3 0.3],'%s is not a ',f);
   nigeLab.utils.cprintf('*Red', 'BLOCK');
   nigeLab.utils.cprintf([0.3 0.3 0.3],' method\n\n',f);
   return;
end

%% Iterate on all Blocks, of all Animals
for iA = 1:numel(tankObj.Children)
   nigeLab.utils.cprintf('Comment-','->\t%s\n',tankObj.Children(iA).Name);
   for iB = 1:numel(tankObj.Children(iA).Children)
      nigeLab.utils.cprintf('Text','\t->\t%s\n',...
         tankObj.Children(iA).Children(iB).Name);
      try
         tankObj.Children(iA).Children(iB).(f)(varargin{:});
         nigeLab.utils.cprintf('*Blue', '\t\t\t\t\t\t\t->\tsuccessful\n');
      catch
         nigeLab.utils.cprintf('*Red', '\t\t\t\t\t\t\t->\tunsuccessful\n');
      end
   end
   fprintf(1,' \n');
end

end