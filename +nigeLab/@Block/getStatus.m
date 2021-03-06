function status = getStatus(blockObj,field,channel)
% GETSTATUS  Returns the operations performed on the block to date
%
%  status = GETSTATUS(blockObj);
%  status = GETSTATUS(blockObj,field);
%  status = GETSTATUS(blockObj,field,channel);
%
%  --------
%   INPUTS
%  --------
%  blockObj       :     nigeLab.Block class object.
%
%    field        :     (Char vector) Name of processing stage:
%                       -> 'Raw'          || Has raw data been extracted
%                       -> 'Dig'          || Were digital streams parsed
%                       -> 'Filt'         || Has bandpass filter been done
%                       -> 'CAR'          || Has CAR been done
%                       -> 'LFP'          || Has LFP been extracted
%                       -> 'Spikes'       || Has spike detection been done
%                       -> 'Sorted'       || Has manual sorting been done
%                       -> 'Clusters'     || Has SPC been performed
%                       -> 'Meta'         || Has metadata been parsed
%
%  channel       :     (optional) Default: Set as a channel or array of
%                          channels, which must all return a true value for
%                          the selected operation Status in order for the
%                          output of getStatus() to return as true.
%
%  --------
%   OUTPUT
%  --------
%   status        :     Returns false if stage is incomplete, or true if
%                          it's complete. If stage is invalid, Status is
%                          returned as empty.

% Handle array of block objects
if ~isscalar(blockObj)
   switch nargin
      case 1
         status = cell(size(blockObj));
         keepvec = true(numel(status),1);
         for i = 1:numel(blockObj)
            if isvalid(blockObj(i))
               status{i} = blockObj(i).getStatus;
            else
               keepvec(i) = false;
            end
         end
         status = status(keepvec);
         if isempty(status)
            status = [];
         end
         return;
      case 2
         if isempty(field)
            status = [];
            for i = 1:numel(blockObj)
               if isvalid(blockObj(i))
                  status = getStatus(blockObj,blockObj(i).Fields);
                  break;
               end
            end
            return;
         end
         thisObj = nigeLab.nigelObj.getValidObj(blockObj,1);
         fieldType = getFieldType(thisObj,field);
         if isempty(fieldType)
            status = false(1,numel(field));
            return;
         end
         switch fieldType
            case {'Channels','Streams'}
               if iscell(field)
                  status = false(numel(blockObj),numel(field));
                  if numel(field) > 1
                     % "Expanded" representation for channels
                     for k = 1:numel(blockObj)
                        if isvalid(blockObj(k))
                           status(k,:) = blockObj(k).getStatus(field);
                        end
                     end
                  else
                     % "Condensed" representation for channels
                     for k = 1:numel(blockObj)
                        if isvalid(blockObj(k))
                           status(k) = all(blockObj(k).getStatus(field));
                        end
                     end
                  end
               else
                  status = true(numel(blockObj),1);
                  for k = 1:numel(blockObj)
                     if isvalid(blockObj(k))
                        status(k) = all(blockObj(k).getStatus(field));
                     end
                  end
               end               
            case 'Meta' % 'Time'
               status = false(numel(blockObj),1);
               if strcmpi(field,'Time') % Special case
                  for k = 1:numel(blockObj)
                     if isvalid(blockObj(k))
                        status(k) = ~isempty(blockObj(k).Time);
                     end
                  end
               else
                  nigeLab.utils.cprintf('Errors*',...
                     '\t\t->\t[GETSTATUS]: Not configured for .Probes yet\n');
               end
            otherwise
               if ~iscell(field)
                  status = false(numel(blockObj),1);
                  for k = 1:numel(blockObj)
                     if isvalid(blockObj(k))
                        if isfield(blockObj(k).Status,field)
                           status(k) = all(blockObj(k).Status.(field));
                        end
                     end
                  end
               else
                  status = false(numel(blockObj),numel(field));
                  for k = 1:numel(blockObj)
                     if isvalid(blockObj(k))
                        for i = 1:numel(field)
                           if isfield(blockObj(k).Status,field{i})
                              status(k) = all(blockObj(k).Status.(field{i}));
                           end
                        end
                     end
                  end
               end
         end
      case 3
         if iscell(field)
            status = false(numel(blockObj),numel(field));
         else
            status = false(numel(blockObj),1);
         end
         for i = 1:numel(blockObj)
            status(i,:) = blockObj(i).getStatus(field,channel);
         end
      otherwise
         error(['nigeLab:' mfilename ':tooManyInputArgs'],...
            'Too many input arguments (%d; max: 3).',nargin);
   end
   
   return;
end

%% Behavior depends on total number of inputs
switch nargin
   case 1 % Only blockObj is given (1 input)
      f = fieldnames(blockObj.Status);
      stat = false(size(f));
      for i = 1:numel(f)
         stat(i) = ~any(~blockObj.Status.(f{i}));
      end
      
      % Give names of all completed operations
      if any(stat)
         status = blockObj.Fields(stat)';
      else
         status={'none'};
      end
      
   case 2 % field is given (2 inputs, including blockObj)
      
      % If given [] field input, return all fields
      if isempty(field)
         status = getStatus(blockObj,blockObj.Fields);
         return;         
      end
      
      status = parseStatus(blockObj,field);
      
   case 3 % If channel is given (3 inputs, including blockObj)
      status = parseStatus(blockObj,field);
      status = ~any(~status(channel));
      
   otherwise
      error(['nigeLab:' mfilename ':tooManyInputArgs'],...
         'Too many input arguments (%d; max: 3).',nargin);
end

   function status = parseStatus(blockObj,stage)
      % PARSESTATUS  Check that it is a valid stage and return the output
      %
      %  status = parseStatus(blockObj,stage);
      %
      %  stage  --  Char array or cell of char arrays
      
      % Ensure that stage is a cell so that checks return correct number of
      % elements (one per "word")
      if ~iscell(stage)
         stage = {stage};
      end
      opInd=ismember(blockObj.Fields,stage);
      
      % If "stage" doesn't belong, throw an error.
      if sum(opInd) < numel(stage)
         warning('No Field with that name (%s).',stage{:});
         status = false;
         
      % Otherwise, if there are too many matches, that is also not good.
      elseif (sum(opInd) > numel(stage))
         warning('Stage name is ambiguous (%s).',stage{:});
         status = false;
         
      else
         maskExists = ~isempty(blockObj.Mask);
         % If only one stage, return all channel status
         if numel(stage) == 1 
            status = blockObj.Status.(stage{:});
            channelStage = strcmp(blockObj.getFieldType(stage{:}),'Channels');
            if maskExists && channelStage
               vec = 1:numel(status);
               % Masked channels are automatically true
               status(setdiff(vec,blockObj.Mask)) = true;
            end
         else
            status = false(size(stage));
            status = reshape(status,1,numel(status));
            % Otherwise, just get whether stages are complete
            for ii = 1:numel(stage) 
               channelStage = strcmp(blockObj.getFieldType(stage{ii}),...
                                     'Channels');
               if isfield(blockObj.Status,stage{ii})
                  flags = blockObj.Status.(stage{ii});
               elseif channelStage
                  flags = false(1,blockObj.NumChannels); 
               else
                  flags = false;
               end
               % If this is a 'Channels' FieldType Stage AND there is a
               % Channel Mask specified, then require ALL elements to be
               % true; otherwise, just require 'Any' element to be true
               if channelStage && maskExists
                  status(ii) = all(flags(blockObj.Mask));
               else
                  status(ii) = all(flags);
               end
               
            end
         end
      end
   end
end
