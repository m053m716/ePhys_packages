function flag = linkChannelsField(blockObj,field,fileType)
%LINKCHANNELSFIELD  Connect the data saved on the disk to Channels
%
%  b = nigeLab.Block;
%  field = 'Spikes';       % field = 'Raw'
%  fileType = 'Event';   % filetype = 'Hybrid'
%  flag = LINKCHANNELSFIELD(b,field,fileType);
%
% Note: This is useful when you already have formatted data,
%       or when the processing stops for some reason while in progress

flag = false;
% updateFlag is for the total number of channels
updateFlag = false(size(blockObj.Mask));
if ~isfield(blockObj.Status,field)
   blockObj.Status.(field) = updateFlag;
end

str = nigeLab.utils.printLinkFieldString(blockObj.getFieldType(field),field);
blockObj.reportProgress(str,0);

% Only iterate on the channels we care about (don't update status for
% others, either).
curCh = 0;
for iCh = blockObj.Mask
   curCh = curCh + 1;
   % Make sure block "key" is linked
   if ~isfield(blockObj.Channels(iCh),'Key')
      blockObj.Channels(iCh).Key = blockObj.getKey();
   elseif isempty(blockObj.Channels(iCh).Key)
      blockObj.Channels(iCh).Key = blockObj.getKey();
   end
   
   % Get file name
   pNum  = num2str(blockObj.Channels(iCh).probe);
   fName = sprintf(strrep(blockObj.Paths.(field).file,'\','/'), ...
      pNum,blockObj.Channels(iCh).chStr);
   fName = fullfile(fName);
   
   % If file is not detected
   updateFlag(curCh) = exist(fullfile(fName),'file')~=0;
   if ~updateFlag(curCh)
      flag = true;
   else
      switch fileType
         case 'Event' % If it's a 'spikes' file
            try % Channels can also have channel events
               blockObj.Channels(iCh).(field) = ...
                  nigeLab.libs.DiskData('Event',fName);
               status = blockObj.Channels(iCh).(field).Complete;
               if isempty(status)
                  setAttr(blockObj.Channels(iCh).(field),'Complete',...
                     int8(updateFlag(curCh)));
               else
                  updateFlag(curCh) = logical(status);
               end
            catch % If spikes exist but in "bad format", fix that
               updateFlag(curCh) = checkSpikeFile(blockObj,fName);
            end
         otherwise
            % Each element of Channels will have different kinds of data
            % (e.g. 'Raw', 'Filt', etc...)
            blockObj.Channels(iCh).(field) = ...
               nigeLab.libs.DiskData('MatFile',fName);
            
            status = blockObj.Channels(iCh).(field).Complete;
            if isempty(status)
               setAttr(blockObj.Channels(iCh).(field),'Complete',...
                  int8(updateFlag(curCh)));
            else
               updateFlag(curCh) = logical(status);
            end
      end
   end
   
   pct = 100 * (curCh / numel(blockObj.Mask));
   reportProgress(blockObj,str,pct,'toWindow','Linking-Channels');
end
updateStatus(blockObj,field,updateFlag,blockObj.Mask);
% Only update status of unmasked channels. The other ones shouldn't matter
% when are looking at 'doAction dependencies' later.


end