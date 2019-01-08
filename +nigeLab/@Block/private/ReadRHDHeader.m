function header=ReadRHDHeader(varargin)
%% PARSE VARARGIN
if nargin >0
   VERBOSE = false;
else
   VERBOSE = true;
end

for iV = 1:2:length(varargin)
   eval([upper(varargin{iV}) '=varargin{iV+1};']);
end

if exist('FID','var')
   
   [NAME,~,~,~] = fopen(FID); %#ok<NODEF>
   if isempty(NAME)
      error('Must provide a valid file pointer.');
   end
elseif exist('NAME', 'var')
   
   % If a pre-specified path exists, must be a valid path.
   if exist(NAME,'file')==0 %#ok<NODEF>
      error('Must provide a valid RHD2000 Data File and Path.');
   else
      FID = fopen(NAME, 'r');
   end
else    % Must select a directory and a file
   
   
   [file, path] = ...
      uigetfile('*.rhd', 'Select an RHD2000 Data File', ...
      'MultiSelect', 'off');
   
   if file == 0 % Must select a file
      error('Must select a valid RHD2000 Data File.');
   end
   
   NAME = [path, file];
   FID = fopen(NAME, 'r');
   
   
end

[path,file,~] = fileparts(NAME);
s = dir(NAME);
filesize = s.bytes;

% Check 'magic number' at beginning of file to make sure this is an Intan
% Technologies RHD2000 data file.
magic_number = fread(FID, 1, 'uint32');
if magic_number ~= hex2dec('c6912702')
   error('Unrecognized file type.');
end

% Read version number.
data_file_main_version_number = fread(FID, 1, 'int16');
data_file_secondary_version_number = fread(FID, 1, 'int16');

if VERBOSE
   fprintf(1, '\n');
   fprintf(1, 'Reading Intan Technologies RHD2000 Data File, Version %d.%d\n', ...
      data_file_main_version_number, data_file_secondary_version_number);
   fprintf(1, '\n');
end

if (data_file_main_version_number == 1)
   num_samples_per_data_block = 60;
else
   num_samples_per_data_block = 128;
end

% Read information of sampling rate and amplifier frequency settings.
sample_rate = fread(FID, 1, 'single');
dsp_enabled = fread(FID, 1, 'int16');
actual_dsp_cutoff_frequency = fread(FID, 1, 'single');
actual_lower_bandwidth = fread(FID, 1, 'single');
actual_upper_bandwidth = fread(FID, 1, 'single');

desired_dsp_cutoff_frequency = fread(FID, 1, 'single');
desired_lower_bandwidth = fread(FID, 1, 'single');
desired_upper_bandwidth = fread(FID, 1, 'single');

% This tells us if a software 50/60 Hz notch filter was enabled during
% the data acquisition.
notch_filter_mode = fread(FID, 1, 'int16');
notch_filter_frequency = 0;
if (notch_filter_mode == 1)
   notch_filter_frequency = 50;
elseif (notch_filter_mode == 2)
   notch_filter_frequency = 60;
end

desired_impedance_test_frequency = fread(FID, 1, 'single');
actual_impedance_test_frequency = fread(FID, 1, 'single');

% Place notes in data strucure
notes = struct( ...
   'note1', fread_QString(FID), ...
   'note2', fread_QString(FID), ...
   'note3', fread_QString(FID) );

% If data file is from GUI v1.1 or later, see if temperature sensor data
% was saved.
num_temp_sensor_channels = 0;
if ((data_file_main_version_number == 1 && data_file_secondary_version_number >= 1) ...
      || (data_file_main_version_number > 1))
   num_temp_sensor_channels = fread(FID, 1, 'int16');
end

% If data file is from GUI v1.3 or later, load eval board mode.
eval_board_mode = 0;
if ((data_file_main_version_number == 1 && data_file_secondary_version_number >= 3) ...
      || (data_file_main_version_number > 1))
   eval_board_mode = fread(FID, 1, 'int16');
end

% If data file is from v2.0 or later (Intan Recording Controller),
% load name of digital reference channel.
if (data_file_main_version_number > 1)
   reference_channel = fread_QString(fid);
end

% Place frequency-related information in data structure.
frequency_parameters = struct( ...
   'amplifier_sample_rate', sample_rate, ...
   'aux_input_sample_rate', sample_rate / 4, ...
   'supply_voltage_sample_rate', sample_rate / num_samples_per_data_block, ...
   'board_adc_sample_rate', sample_rate, ...
   'board_dig_in_sample_rate', sample_rate, ...
   'desired_dsp_cutoff_frequency', desired_dsp_cutoff_frequency, ...
   'actual_dsp_cutoff_frequency', actual_dsp_cutoff_frequency, ...
   'dsp_enabled', dsp_enabled, ...
   'desired_lower_bandwidth', desired_lower_bandwidth, ...
   'actual_lower_bandwidth', actual_lower_bandwidth, ...
   'desired_upper_bandwidth', desired_upper_bandwidth, ...
   'actual_upper_bandwidth', actual_upper_bandwidth, ...
   'notch_filter_frequency', notch_filter_frequency, ...
   'desired_impedance_test_frequency', desired_impedance_test_frequency, ...
   'actual_impedance_test_frequency', actual_impedance_test_frequency );

% spike_trigger_struct is defined below in its function
new_trigger_channel = spike_trigger_struct;
spike_triggers = spike_trigger_struct;

% channel_structt is defined below in its function
new_channel = channel_struct;

% Create structure arrays for each type of data channel.
amplifier_channels = channel_struct;
aux_input_channels = channel_struct;
supply_voltage_channels = channel_struct;
board_adc_channels = channel_struct;
board_dig_in_channels = channel_struct;
board_dig_out_channels = channel_struct;

amplifier_index = 1;
aux_input_index = 1;
supply_voltage_index = 1;
board_adc_index = 1;
board_dig_in_index = 1;
board_dig_out_index = 1;

% Read signal summary from data file header.

number_of_signal_groups = fread(FID, 1, 'int16');

for signal_group = 1:number_of_signal_groups
   signal_group_name = fread_QString(FID);
   signal_group_prefix = fread_QString(FID);
   signal_group_enabled = fread(FID, 1, 'int16');
   signal_group_num_channels = fread(FID, 1, 'int16');
   signal_group_num_amp_channels = fread(FID, 1, 'int16');
   
   if (signal_group_num_channels > 0 && signal_group_enabled > 0)
      new_channel(1).port_name = signal_group_name;
      new_channel(1).port_prefix = signal_group_prefix;
      new_channel(1).port_number = signal_group;
      for signal_channel = 1:signal_group_num_channels
         new_channel(1).native_channel_name = fread_QString(FID);
         new_channel(1).custom_channel_name = fread_QString(FID);
         new_channel(1).native_order = fread(FID, 1, 'int16');
         new_channel(1).custom_order = fread(FID, 1, 'int16');
         signal_type = fread(FID, 1, 'int16');
         channel_enabled = fread(FID, 1, 'int16');
         new_channel(1).chip_channel = fread(FID, 1, 'int16');
         new_channel(1).board_stream = fread(FID, 1, 'int16');
         new_trigger_channel(1).voltage_trigger_mode = fread(FID, 1, 'int16');
         new_trigger_channel(1).voltage_threshold = fread(FID, 1, 'int16');
         new_trigger_channel(1).digital_trigger_channel = fread(FID, 1, 'int16');
         new_trigger_channel(1).digital_edge_polarity = fread(FID, 1, 'int16');
         new_channel(1).electrode_impedance_magnitude = fread(FID, 1, 'single');
         new_channel(1).electrode_impedance_phase = fread(FID, 1, 'single');
         new_channel(1).custom_channel_name = strrep(new_channel(1).custom_channel_name,' ','');
         new_channel(1).custom_channel_name = strrep(new_channel(1).custom_channel_name,'-','');
         
         if (channel_enabled)
            switch (signal_type)
               case 0
                  amplifier_channels(amplifier_index) = new_channel;
                  spike_triggers(amplifier_index) = new_trigger_channel;
                  amplifier_index = amplifier_index + 1;
               case 1
                  aux_input_channels(aux_input_index) = new_channel;
                  aux_input_index = aux_input_index + 1;
               case 2
                  supply_voltage_channels(supply_voltage_index) = new_channel;
                  supply_voltage_index = supply_voltage_index + 1;
               case 3
                  board_adc_channels(board_adc_index) = new_channel;
                  board_adc_index = board_adc_index + 1;
               case 4
                  board_dig_in_channels(board_dig_in_index) = new_channel;
                  board_dig_in_index = board_dig_in_index + 1;
               case 5
                  board_dig_out_channels(board_dig_out_index) = new_channel;
                  board_dig_out_index = board_dig_out_index + 1;
               otherwise
                  error('Unknown channel type');
            end
         end
         
      end
   end
end

% Summarize contents of data file.
num_amplifier_channels = amplifier_index - 1;
num_aux_input_channels = aux_input_index - 1;
num_supply_voltage_channels = supply_voltage_index - 1;
num_board_adc_channels = board_adc_index - 1;
num_board_dig_in_channels = board_dig_in_index - 1;
num_board_dig_out_channels = board_dig_out_index - 1;

fprintf(1, 'Found %d amplifier channel%s.\n', ...
   num_amplifier_channels, plural(num_amplifier_channels));
fprintf(1, 'Found %d auxiliary input channel%s.\n', ...
   num_aux_input_channels, plural(num_aux_input_channels));
fprintf(1, 'Found %d supply voltage channel%s.\n', ...
   num_supply_voltage_channels, plural(num_supply_voltage_channels));
fprintf(1, 'Found %d board ADC channel%s.\n', ...
   num_board_adc_channels, plural(num_board_adc_channels));
fprintf(1, 'Found %d board digital input channel%s.\n', ...
   num_board_dig_in_channels, plural(num_board_dig_in_channels));
fprintf(1, 'Found %d board digital output channel%s.\n', ...
   num_board_dig_out_channels, plural(num_board_dig_out_channels));
fprintf(1, 'Found %d temperature sensors channel%s.\n', ...
   num_temp_sensor_channels, plural(num_temp_sensor_channels));
fprintf(1, '\n');


% Determine how many samples the data file contains.

% Each data block contains num_samples_per_data_block amplifier samples.
bytes_per_block = num_samples_per_data_block * 4;  % timestamp data
bytes_per_block = bytes_per_block + num_samples_per_data_block * 2 * num_amplifier_channels;
% Auxiliary inputs are sampled 4x slower than amplifiers
bytes_per_block = bytes_per_block + (num_samples_per_data_block / 4) * 2 * num_aux_input_channels;
% Supply voltage is sampled once per data block
bytes_per_block = bytes_per_block + 1 * 2 * num_supply_voltage_channels;
% Board analog inputs are sampled at same rate as amplifiers
bytes_per_block = bytes_per_block + num_samples_per_data_block * 2 * num_board_adc_channels;
% Board digital inputs are sampled at same rate as amplifiers
if (num_board_dig_in_channels > 0)
   bytes_per_block = bytes_per_block + num_samples_per_data_block * 2;
end
% Board digital outputs are sampled at same rate as amplifiers
if (num_board_dig_out_channels > 0)
   bytes_per_block = bytes_per_block + num_samples_per_data_block * 2;
end
% Temp sensor is sampled once per data block
if (num_temp_sensor_channels > 0)
   bytes_per_block = bytes_per_block + 1 * 2 * num_temp_sensor_channels;
end

% How many data blocks remain in this file?
data_present = 0;
bytes_remaining = filesize - ftell(FID);
if (bytes_remaining > 0)
   data_present = 1;
end

num_data_blocks = bytes_remaining / bytes_per_block;

num_amplifier_samples = num_samples_per_data_block * num_data_blocks;
num_aux_input_samples = (num_samples_per_data_block / 4) * num_data_blocks;
num_supply_voltage_samples = 1 * num_data_blocks;
num_temp_sensor_samples = 1 * num_data_blocks;
num_board_adc_samples = num_samples_per_data_block * num_data_blocks;
num_board_dig_in_samples = num_samples_per_data_block * num_data_blocks;
num_board_dig_out_samples = num_samples_per_data_block * num_data_blocks;

record_time = num_amplifier_samples / sample_rate;


% if num_amplifier_samples < 60
%     fprintf(1, 'No stream data: %s\n', [Animal '_' Rec]);
%     fprintf(1, 'File not extracted.\n');
%     fprintf(1, '\n');
%     return;
% end


if VERBOSE
   if (data_present)
      fprintf(1, 'File contains %0.3f seconds of data.  Amplifiers were sampled at %0.2f kS/s, for a total of %d samples.\n',...
         record_time, sample_rate / 1000, num_amplifier_samples);
      fprintf(1, '\n');
   else
      fprintf(1, 'Header file contains no data.  Amplifiers were sampled at %0.2f kS/s.\n', ...
         sample_rate / 1000);
      fprintf(1, '\n');
   end
end
header_size=ftell(FID);
% Determine how many probes and channels per probe

nPort   = [amplifier_channels(:).port_number];
probes = unique(nPort);
num_probes = numel(unique(nPort));

for iN = 1:num_probes
   eval(['numArray' num2str(iN) 'Chans = sum(nPort == iN);']);
end
for ii=DesiredOutputs' %  DesiredOutputs defined below
   header.(ii{:})=eval(ii{:});
end

return
end

function a = fread_QString(FID)

% a = read_QString(FID)
%
% Read Qt style QString.  The first 32-bit unsigned number indicates
% the length of the string (in bytes).  If this number equals 0xFFFFFFFF,
% the string is null.

a = '';
length = fread(FID, 1, 'uint32');
if length == hex2num('ffffffff')
   return;
end
% convert length from bytes to 16-bit Unicode words
length = length / 2;

for i=1:length
   a(i) = fread(FID, 1, 'uint16');
end

return
end

function s = plural(n)

% s = plural(n)
%
% Utility function to optionally plurailze words based on the value
% of n.

if (n == 1)
   s = '';
else
   s = 's';
end

return
end

function DesiredOutputs=DesiredOutputs()
DesiredOutputs = {
   'data_present';
   'eval_board_mode';
   'sample_rate';
   'frequency_parameters';
   'amplifier_channels';
   'aux_input_channels';
   'supply_voltage_channels';
   'board_adc_channels';
   'board_dig_in_channels';
   'board_dig_out_channels';
   'spike_triggers';
   'num_amplifier_channels';
   'num_aux_input_channels';
   'num_supply_voltage_channels'
   'num_board_adc_channels';
   'num_temp_sensor_channels';
   'num_board_dig_in_channels';
   'num_board_dig_out_channels';
   'probes';
   'num_probes';
   'num_data_blocks';
   'num_samples_per_data_block';
   'num_amplifier_samples';
   'num_aux_input_samples';
   'num_supply_voltage_samples';
   'num_temp_sensor_samples';
   'num_board_adc_samples';
   'num_board_dig_in_samples';
   'num_board_dig_out_samples';
   'header_size';
   'filesize';
   'bytes_per_block';
   'data_file_main_version_number';
   };
end

function spike_trigger_struct_=spike_trigger_struct()
spike_trigger_struct_ = struct( ...
   'voltage_trigger_mode', {}, ...
   'voltage_threshold', {}, ...
   'digital_trigger_channel', {}, ...
   'digital_edge_polarity', {} );
return
end

function channel_struct_=channel_struct()
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
   'electrode_impedance_phase', {} );
return
end