function flag = doRawExtraction(blockObj)
%DORAWEXTRACTION  Extract matfiles from binary recording files
%
%  b = nigeLab.Block;
%  flag = doRawExtraction(b);
%
%  --------
%   OUTPUT
%  --------
%   flag       :     Returns true if conversion was successful.

% PARSE EXTRACTION DEPENDING ON RECORDING TYPE AND FILE EXTENSION
% If returns before completion, indicate failure to complete with flag
if numel(blockObj) > 1
   flag = true;
   for i = 1:numel(blockObj)
      if ~isempty(blockObj(i))
         if isvalid(blockObj(i))
            flag = flag && doRawExtraction(blockObj(i));
         end
      end
   end
   return;
else
   flag = false;
end
blockObj.checkActionIsValid();

if ~genPaths(blockObj)
   warning('Something went wrong when generating paths for extraction.');
   return;
end

% extraction
switch blockObj.RecType
   case 'Intan'
      % Intan extraction should be compatible for both the *.rhd and *.rhs
      % binary file formats.
      flag = blockObj.intan2Block;
      
   case 'TDT'
      % TDT raw data already has a sort of "BLOCK" structure that should be
      % parsed to get this information.
      fprintf(1,' \n');
      if ~blockObj.OnRemote
         nigeLab.utils.cprintf('*Red','\t%s extraction is still ',blockObj.RecType);
         nigeLab.utils.cprintf('Magenta-', 'WIP\n');
         nigeLab.utils.cprintf('*Comment','\tIt might take a while...\n\n');
      end
      flag = tdt2Block(blockObj);
      
   case 'Matfile' % "FLEX" format wherein source is an "_info.mat" file
      % -- Primarily for backwards-compatibility, or for if the extraction
      %     has already been performed, but some error or something
      %     happened and you no longer have the 'Block' object, but you
      %     would like to associate the 'Block' with that file structure
      
      flag = blockObj.MatFileWorkflow.ExtractFcn(blockObj);
      %
   otherwise
      % Currently only working with TDT and Intan, the two types of
      % acquisition hardware that are in place at Nudo Lab at KUMC, and at
      % Chiappalone Lab at IIT.
      %
      % To add in the future (?):
      %  
      %  * All formats listed on open-ephys "data formats"
        
      warning('%s is not a supported data format (case-sensitive)',...
         blockObj.RecType);
      return;
end

% Update status and save
if blockObj.OnRemote
   str = 'Saving-Block';
   blockObj.reportProgress(str,100,'toWindow',str);
else
   blockObj.save;
   linkStr = blockObj.getLink('Raw');
   str = sprintf('<strong>Raw extraction</strong> complete: %s\n',linkStr);
   blockObj.reportProgress(str,100,'toWindow','Done');
   blockObj.reportProgress('Done',100,'toEvent');
end

end