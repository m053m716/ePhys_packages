function flag = initStreams(blockObj)
%% INITSTREAMS Initialize Streams struct for nigeLab.Block class object
%
%  flag = INITSTREAMS(blockObj);
%
% By: Max Murphy  v1.0  2019/01/11  Original version (R2017a)

%%
flag = false;
fieldIdx = ismember(blockObj.FieldType,'Streams');
nStreamTypes = sum(fieldIdx);
if sum(fieldIdx) == 0
   flag = true;
   disp('No STREAMS to initialize.');
   return;
end

fieldIdx = find(fieldIdx);
blockObj.Streams = struct;

headerFields = fieldnames(blockObj.Meta.Header);

for ii = 1:nStreamTypes
   name = blockObj.Fields{fieldIdx(ii)};
   
   headerStructName = [name 'Channels'];
   if ismember(headerStructName,headerFields)
      blockObj.Streams.(name) = blockObj.Meta.Header.(headerStructName);
   else
      blockObj.Streams.(name) = channel_struct;
   end
end
flag = true;

   function channel_struct_= channel_struct()
      channel_struct_ = struct( ...
         'native_channel_name', {}, ...
         'custom_channel_name', {}, ...
         'native_order', {}, ...
         'custom_order', {}, ...
         'board_stream', {}, ...
         'chip_channel', {}, ...
         'port_name', {}, ...
         'port_prefix', {}, ...
         'port_number', {}, ...
         'probe', {}, ...
         'electrode_impedance_magnitude', {}, ...
         'electrode_impedance_phase', {}, ...
         'signal_type', {});
      return
   end

end