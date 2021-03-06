classdef Block < nigeLab.nigelObj
   % BLOCK    Creates datastore for an electrophysiology recording.
   %
   %  blockObj = nigeLab.Block();
   %     --> select Block path information from UI
   %  blockObj = nigeLab.Block(blockPath);
   %     --> blockPath can be set as [] or char array with location
   %  blockObj = nigeLab.Block(blockPath,animalPath);
   %     --> animalPath can be [] or char array with location
   %  blockObj = nigeLab.Block(__,'PropName1',propVal1,...);
   %     --> allows specification of properties in constructor
   %
   %  ex:
   %  blockObj = nigeLab.Block([],'P:\Your\Recording\Directory\Here');
   %
   %  BLOCK Properties:
   %     Name - Name of recording BLOCK.
   %
   %     Animal - "Parent" nigeLab.Animal object
   %
   %     Graphics - Struct that contains pointers to graphics files.
   %
   %     Status - Completion status for each element of BLOCK/FIELDS.
   %
   %     Channels - Struct that contains data fields.
   %                 -> blockObj.Channels(7).Raw(1:10) First 10 samples of
   %                                                    channel 7 from the
   %                                                    raw waveform.
   %                 -> blockObj.Channels(1).Spikes.peak_train  Spike
   %                                                           peak_train
   %                                                           for chan 1.
   %
   %     Meta - Struct containing metadata info about recording BLOCK.
   %
   %  BLOCK Methods:
   %     Block - Class constructor. Call as blockObj = BLOCK(varargin)
   %
   %     doRawExtraction - Convert from raw data binaries to BLOCK format.
   %
   %     doUnitFilter - Apply bandpass filter for unit activity.
   %
   %     doReReference - Apply common average re-reference for de-noising.
   %
   %     doSD - Run spike detection and feature extraction.
   %
   %     doLFPExtraction - Use cascaded lowpass filter to decimate raw data
   %                       to a rate more suitable for LFP analyses.
   %
   %     doVidInfoExtraction - Get video metadata if there are related
   %                           behavioral videos associated with a
   %                           recording.
   %
   %     doVidSyncExtraction - Get time-series of "digital HIGH" times
   %                           based on detection of ON/OFF state of a
   %                           video element, such as a flashing LED.
   %
   %     doBehaviorSync - Get synchronization signal from digital inputs.
   %
   %     plotWaves -    Make a preview of the filtered waveform for all
   %                    channels, and include any sorted, clustered, or
   %                    detected spikes for those channels as highlighted
   %                    marks at the appropriate time stamp.
   %
   %     plotSpikes -   Display all spikes for a particular channel as a
   %                    SPIKEIMAGE object.
   %
   %     linkToData - Link block object to existing data structure.
   %
   %     clearSpace - Remove extracted RAW data, and extracted FILTERED
   %                  data if CAR channels are present.
   %
   %     analyzeRMS - Get RMS for all channels of a desired type of stream.
   %
   %     Empty - Create an Empty BLOCK object or array
   
   % % % PROPERTIES % % % % % % % % % %   
   % HIDDEN,TRANSIENT,PUBLIC
   properties (Hidden,Transient,Access=public)
      CurrentJob                % parallel.job.MJSCommunicatingJob
   end
   
   % HIDDEN,TRANSIENT,DEPENDENT,PUBLIC
   properties (Hidden,Transient,Dependent,Access=public)
      ChannelID            double   % [NumChannels x 2] array of channel and probe numbers
      EventTimes           double   % Timestamps of different scored events
      HasROI      (1,1)    logical = false   % Do all the video cameras have ROI set?
      NumChannels (1,1)    double   % Total number of channels 
      NumProbes   (1,1)    double   % Total number of Probes
      ScoringField         char   = 'ScoredEvents'   % blockObj.Pars.Video.ScoringEventFieldName
      Shortcut             struct   % nigeLab.defaults.Shortcuts() output (transient)
      Trial                double   % Timestamp list of trials
      TrialField           char   = 'trial-running'  % blockObj.Pars.Event.TrialDetectionInfo.Name
      TrialMask                     % Logical vector of masking for trials (if applicable)
      TrialVideoOffset     double   % Matrix where rows are video cameras and columns are trials. Each value is a trial/camera-specific offset.
      VideoHeader          double   % "Header" for Video/Event data
   end
   
   % HIDDEN,ABORTSET,SETOBSERVABLE,PUBLIC
   properties (AbortSet,Hidden,SetObservable,Access=public)
      CurNeuralTime  (1,1) double = 0  % Current "Neural Time" for analyses
   end
   
   % HIDDEN,ABORTSET,DEPENDENT,TRANSIENT,PUBLIC
   properties (AbortSet,Hidden,Dependent,Transient,Access=public)
      TrialIndex     (1,1) double = 1  % Current "Trial Index" for analyses
      VideoIndex     (1,1) double = 1  % Current "Video Index" for analyses
   end
   
   % HIDDEN,TRANSIENT,PROTECTED
   properties (Hidden,Access=protected)
      TrialIndex_          double = 1  % Initialized as empty container
      TrialMask_           logical     % Initialized as empty container
      VideoIndex_          double = 1  % Initialized as empty container
   end
   
   % HIDDEN,PUBLIC (flags)
   properties (Hidden,Access=public)
      HasVideoTrials   (1,1) logical = false   % Does the Block have extracted trials?
   end
   
   % PUBLIC
   properties (Access=public)
      Channels struct                        % Struct array of neurophysiological stream data
      Events   struct                        % Struct array of asynchronous events
      Streams  struct                        % Struct array of non-electrode data streams
      Videos                                 % Array of nigeLab.libs.VideosFieldType
   end
   
   % RESTRICTED:nigelObj/PUBLIC
   properties (GetAccess = public,SetAccess=?nigeLab.nigelObj)
      FileType       cell  =  nigeLab.nigelObj.Default('FileType','Block')  % Indicates DiskData file type for each Field
      Mask           {logical,double}        % Vector of indices of included elements of Channels
      Notes          struct                  % Notes from text file
      Probes         struct                  % Probe configurations associated with saved recording
      RMS            table                   % RMS noise table for different waveforms
      SampleRate     double                  % Recording sample rate
      Samples        double                  % Total number of samples in original record
      Scoring (1,1)  struct                  % Metadata about any scoring done
      Status  (1,1)  struct                  % Completion status for each element of BLOCK/FIELDS
      Time           nigeLab.libs.DiskData   % DiskFile reference to neural time record
   end
   
   % RESTRICTED:nigelObj
   properties (Access=?nigeLab.nigelObj)
      MultiAnimals = 0      % Flag for many animals contained in one block
      % Handles ad hoc workflows
      MatFileWorkflow struct = nigeLab.Block.Default('MatFileWorkflow');   
      %                           Struct with fields below:
      %                            --> ReadFcn     function handle to external
      %                                            matfile header loading function
      %                            --> ConvertFcn  function handle to "convert"
      %                                            old (pre-extracted) blocks to
      %                                            nigeLab format
      %                            --> ExtractFcn  function handle to use for
      %                                            'do' extraction methods
      %                             --> Pars   struct with misc. loaded
      %                                        parameters. Must include:
      %                                         * .NumChannels
   end
   
   % TRANSIENT,PROTECTED
   properties (Transient,Access=protected)
      ChannelID_        % (Transient) store for .ChannelID property
      NumChannels_      % (Transient) store for .NumChannels property
      NumProbes_        % (Transient) store for .NumProbes property
      ScoringField_     % (Transient) store for .ScoringField property
      Shortcut_         % (Transient) store for .Shortcut property
      TrialField_       % (Transient) store for .TrialField property
      TrialVideoOffset_ % (Transient) store for .TrialVideoOffset property
      VideoHeader_      % (Transient) store for .VideoHeader property
   end
   
   % TRANSIENT,RESTRICTED:nigelObj
   properties (Transient,Access=?nigeLab.nigelObj)
      MultiAnimalsLinkedBlocks nigeLab.Block  % Pointer to blocks from same recording
   end
   % % % % % % % % % % END PROPERTIES %
   
   % % % METHODS% % % % % % % % % % % %
   % NO ATTRIBUTES (overloaded methods)
   methods
      % BLOCK class constructor
      function blockObj = Block(blockPath,blockSavePath,varargin)
         % BLOCK    Creates datastore for an electrophysiology recording.
         %
         %  blockObj = nigeLab.Block();
         %     --> select Block path information from UI
         %  blockObj = nigeLab.Block(blockPath);
         %     --> blockPath can be set as [] or char array with location
         %  blockObj = nigeLab.Block(blockPath,animalPath);
         %     --> blockSavePath can be [] or char array with location
         %        where block will be saved ( the folder containing the
         %        block folder hierarchy )
         %  blockObj = nigeLab.Block(__,'PropName1',propVal1,...);
         %     --> allows specification of properties in constructor
         %  blockObj = nigeLab.Block(__,'$ParsField.ParamName',paramVal);
         %     --> sets value of blockObj.Pars.(ParsField).(ParamName)
         %           equal to paramVal by default.
         %
         %  ex:
         %  blockObj = nigeLab.Block([],'P:\Your\Rec\Directory\Here');
         
         if nargin < 1
            blockPath = '';
         end
         if nargin < 2
            blockSavePath = '';
         end
         blockObj@nigeLab.nigelObj('Block',blockPath,blockSavePath,varargin{:}); 
         if isempty(blockObj) % Handle empty init case
            return;
         end
         if isstruct(blockPath) % Handle loadobj case
            return;
         end
         blockObj.addPropListeners();
         if ~blockObj.init()
            error(['nigeLab:' mfilename ':BadInit'],...
               'Block object construction unsuccessful.');
         end
         blockObj.Key = nigeLab.nigelObj.InitKey;
      end
      
      % % % (DEPENDENT) GET/SET.PROPERTY METHODS % % % % % % % % % % % %
      % [DEPENDENT] Returns .ChannelID property
      function value = get.ChannelID(blockObj)
         %GET.CHANNELID  Returns .ChannelID property
         %
         %  value = get(blockObj,'ChannelID');
         %  --> Returns [NumChannels x 2] array of [probe, channel]
         %      numeric ID (e.g. 1 2 corresponds to probe 1 channel 2)
         
         if ~isempty(blockObj.ChannelID_)
            value = blockObj.ChannelID_;
            return;
         end
         
         value = zeros(0,2);
         if isempty(blockObj.Channels)
            return;
         end
         
         % Get Probe index of each recording channel
         probeNum = [blockObj.Channels.probe].';
         if numel(probeNum) < blockObj.NumChannels
            % Parse and check that parsing worked
            if ~blockObj.parseProbeNumbers  
               return;
            else
               probeNum = [blockObj.Channels.probe].';
            end
         end
         
         % Get index of each channel within a probe
         channelNum = [blockObj.Channels.chNum].'; % Parsed with .probe
         
         % Combine into output matrix
         value = [probeNum, channelNum];
         blockObj.ChannelID_ = value;
      end
      function set.ChannelID(obj,value)
         % Does nothing
         obj.ChannelID_ = value;
      end
           
      % [DEPENDENT]  Returns .EventTimes property (write to DiskData)
      function value = get.EventTimes(blockObj)
         %GET.EVENTTIMES  Returns .EventTimes property
         %
         %  value = get(obj,'EventTimes');
         
         v = blockObj.Pars.Video.VarsToScore(blockObj.Pars.Video.VarType == 1);
         value = nan(numel(blockObj.Trial),numel(v));
         for iV = 1:numel(v)
            value(:,iV) = getEventData(blockObj,blockObj.ScoringField,...
               'ts',v{iV});
         end
      end
      function set.EventTimes(blockObj,value)
         %SET.EVENTTIMES  Assigns .EventTimes property
         %
         %  set(blockObj,'EventTimes',__);
         
         v = blockObj.Pars.Video.VarsToScore(...
            blockObj.Pars.Video.VarType == 1);  
         for iV = 1:numel(v)
            setEventData(blockObj,blockObj.ScoringField,...
               'ts',v{iV},value(:,iV));
         end
      end
      
      % [DEPENDENT]  Returns .HasROI property: are all Videos ROI set?
      function value = get.HasROI(blockObj)
         %GET.HASROI  Returns .HasROI property: are all Videos ROI set?
         value = false;
         if isempty(blockObj)
            return;
         elseif isempty(blockObj.Videos)
            return;
         end
         ROI = {blockObj.Videos.ROI};
         value = true;
         for i = 1:numel(ROI)
            if ~blockObj.Videos(i).Masked
               continue;
            end
            flag = ~ischar(ROI{i}{1}) && ~ischar(ROI{i}{2});
            value = value && flag;
         end
      end
      function set.HasROI(~,~)
         %SET.HASROI  Cannot set READ-ONLY property
         warning('Cannot set READ-ONLY property: <strong>HASROI</strong>');
      end
      
      % [DEPENDENT] Returns .NumChannels property
      function value = get.NumChannels(blockObj)
         %GET.NUMCHANNELS  Returns total number of Channels
         %
         %  value = get(blockObj,'NumChannels');
         %  --> Returns number of elements in .Channels array
         if isempty(blockObj.NumChannels_)
            value = numel(blockObj.Channels);
            blockObj.NumChannels_ = value;
         else
            value = blockObj.NumChannels_;
         end
      end
      function set.NumChannels(blockObj,value)
         % Does nothing
         blockObj.NumChannels_ = value;
      end
      
      % [DEPENDENT] Returns .NumProbes property
      function value = get.NumProbes(blockObj)
         %GET.NUMPROBES  Returns total number of Probes
         %
         %  value = get(blockObj,'NumProbes');
         %  --> Returns number of probes
         
         if ~isempty(blockObj.NumProbes_)
            value = blockObj.NumProbes_;
            return;
         end
         
         value = 0;
         switch blockObj.RecType
            case {'Intan','TDT','nigelBlock'}
               C = blockObj.ChannelID;
               value = numel(unique(C(:,1)));
            case 'Matfile'
               value = blockObj.MatFileWorkflow.Pars.NumProbes;
            otherwise
               error(['nigeLab:' mfilename ':UnsupportedRecType'],...
                  '''%s'' is not a supported RecType.',blockObj.RecType);
         end
         blockObj.NumProbes_ = value;
      end
      function set.NumProbes(blockObj,value)
         %SET.NUMPROBES  Assigns .NumProbes property
         blockObj.NumProbes_ = value;
      end
      
      % [DEPENDENT] Returns .ScoringField property
      function value = get.ScoringField(blockObj)
         %GET.SCORINGFIELD  Returns .ScoringField 
         %
         %  value = get(blockObj,'ScoringField');
         %  --> Returns blockObj.Pars.Video.ScoringEventFieldName, or empty
         %      char 'ScoredEvents' if that parameter has not yet 
         %      been initialized.
         if isempty(blockObj.ScoringField_)
            value = blockObj.Pars.Video.ScoringEventFieldName;
            blockObj.ScoringField_ = value;
         else
            value = blockObj.ScoringField_;
         end         
      end
      function set.ScoringField(blockObj,value)
         %SET.SCORINGFIELD  Assigns .ScoringField
         blockObj.ScoringField_ = value;
      end
      
      % [DEPENDENT] Returns .Shortcut property
      function value = get.Shortcut(blockObj)
         %GET.SHORTCUT  Returns .Shortcut_
         if isempty(blockObj.Shortcut_)
            blockObj.Shortcut_ = nigeLab.defaults.Shortcuts();
         end
         value = blockObj.Shortcut_;
      end
      function set.Shortcut(blockObj,value)
         %SET.SHORTCUT  Assigns .Shortcut (nigeLab.defaults.Shortcuts())
         %
         %  set(blockObj,'Shortcut',value);
         blockObj.Shortcut_ = value;
      end
      
      % [DEPENDENT] Returns .Trial property
      function value = get.Trial(blockObj)
         %GET.TRIAL  Returns .Trial property
         %
         %  value = get(blockObj,'Trial');
         %  --> Returns vector of time stamps of trial onsets
         
         if isempty(blockObj.Events)
            value = [];
            return;
         end
         value = getEventData(blockObj,blockObj.ScoringField,'ts','Trial');
      end
      function set.Trial(blockObj,value)
         %SET.Trial  Assigns .Trial property
         setEventData(blockObj,blockObj.ScoringField,'ts','Trial',value);
      end
      
      % [DEPENDENT] Returns .TrialField property
      function value = get.TrialField(blockObj)
         %GET.TRIALFIELD  Returns .TrialField
         %
         %  value = get(blockObj,'TrialField');
         %  --> Returns blockObj.Pars.Event.TrialDetectionInfo.Name, or 
         %        'trial-running' otherwise
         if isempty(blockObj.TrialField_)
            value = blockObj.Pars.Event.TrialDetectionInfo.Name;
            blockObj.TrialField_ = value;
         else
            value = blockObj.TrialField_;
         end
      end
      function set.TrialField(blockObj,value)
         %SET.TRIALFIELD  Assigns .TrialField property
         blockObj.TrialField_ = value;
      end
      
      % [DEPENDENT]  Interact with "Trial" Event file to get "Index" attr
      function value = get.TrialIndex(blockObj)
         %GET.TRIALINDEX  Interact with "Trial" file to get "Index" attr
         %
         %  value = get(blockObj,'TrialIndex');
         %  --> Returns 'Trials' attribute: Index
         
         if isempty(blockObj.TrialIndex_)
            if isempty(blockObj.Events)
               value = 1;
               blockObj.TrialIndex_ = 1;
               return;
            end
            tIdx = getEventsIndex(blockObj,blockObj.ScoringField,'Trial');
            value = getAttr(...
               blockObj.Events.(blockObj.ScoringField)(tIdx).data,...
               'Index');
            blockObj.TrialIndex_ = value;
         else
            value = blockObj.TrialIndex_;
         end
      end
      function set.TrialIndex(blockObj,value)
         %SET.TRIALINDEX  Interact with "Trial" file to set "Index" attr
         %
         %  set(blockObj,'TrialIndex',value);
         tIdx = getEventsIndex(blockObj,blockObj.ScoringField,'Trial');
         s = setAttr(blockObj.Events.(blockObj.ScoringField)(tIdx).data,...
            'Index',int8(value));
         if s
            blockObj.TrialIndex_ = value;
         end
      end
      
      % [DEPENDENT]  Interact with "Trial" event file to get "Mask"
      function value = get.TrialMask(blockObj)
         %GET.TRIALMASK  Returns "Trial" event file Mask vector
         %
         %  get(blockObj,'TrialMask');
         
         if isempty(blockObj.TrialMask_)
            if isempty(blockObj.Events)
               value = [];
               return;
            end
            f = blockObj.ScoringField;
            mask = getEventData(blockObj,f,'tag','Trial');
            mask(isnan(mask)) = true; % "NaN" masked trials are included
            value = logical(mask);
            blockObj.TrialMask_ = value;
         else
            value = blockObj.TrialMask_;
         end
      end
      function set.TrialMask(blockObj,value)
         %SET.TRIALMASK  Assign "Trial" event file Mask vector
         %
         %  set(blockObj,'TrialMask',value);
         
         value(isnan(value)) = 1; % Update "NaN" mask to true
         f = blockObj.ScoringField;
         setEventData(blockObj,f,'tag','Trial',value);
         blockObj.TrialMask_ = value;
         
         % If "Trial-Segmented Videos" have been extracted
         if blockObj.HasVideoTrials
            % If there are equivalent # of videos to # of trials
            if numel(blockObj.Videos) == numel(blockObj.TrialMask_)
               % Then assign "Trial" Mask to Videos as well
               blockObj.Videos(blockObj.TrialIndex).Masked = ...
                  blockObj.TrialMask_(blockObj.TrialIndex);
            end
         end
      end
      
      % [DEPENDENT] Returns .TrialVideoOffset property
      function value = get.TrialVideoOffset(blockObj)
         %GET.TRIALVIDEOOFFSET  Returns .TrialVideoOffset property
         %
         %  value = get(blockObj,'TrialVideoOffset');
         %  --> Returns a matrix of times (seconds) in double precision.
         %      * Rows are video cameras (indexed as in VideoHeader and .Videos)
         %      * Columns are trials 
         %  --> Each value is a trial/camera-specific offset
         %  --> The Neural time can be recovered from any _Events timestamp
         %      if _Events timestamp == tEvent
         %      if neural time == tNeu
         %      if offset in header file (column 4) == videoOffset
         %      and if the trial/camera specific matrix element == specific
         %     ("specific" is returned by get(blockObj,'TrialVideoOffset'))
         %
         %        >> tNeu = tEvent + videoOffset + specific;
         %
         %  If the value cannot be accessed or is not initialized, returns
         %  zero.
         
         if ~isempty(blockObj.TrialVideoOffset_)
            value = blockObj.TrialVideoOffset_;
            return;
         end

         header = blockObj.VideoHeader;
         nMeta = header(1,2);
         if size(header,2) >= (5+nMeta)
            value = header(:,(5+nMeta):end);
            value(isnan(value)) = 0;
         else
            value = zeros(size(header,1),1);
         end
         blockObj.TrialVideoOffset_ = value;
      end
      function set.TrialVideoOffset(blockObj,value)
         %SET.TRIALVIDEOOFFSET  Returns .TrialVideoOffset property
         %
         %  set(blockObj,'TrialVideoOffset');
         %  --> Set a matrix of times (seconds) in double precision.
         %      * Rows are video cameras (indexed as in VideoHeader and .Videos)
         %      * Columns are trials 
         %  --> Each value is a trial/camera-specific offset
         %  --> The Neural time can be recovered from any _Events timestamp
         %      if _Events timestamp == tEvent
         %      if neural time == tNeu
         %      if offset in header file (column 4) == videoOffset
         %      and if the trial/camera specific matrix element == specific
         %     ("specific" is returned by get(blockObj,'TrialVideoOffset'))
         %
         %        >> tNeu = tEvent + videoOffset + specific;
         %
         %  If the value cannot be accessed or is not initialized, returns
         %  zero.
         
         blockObj.TrialVideoOffset_ = value;
         header = blockObj.VideoHeader;
         nMeta = header(1,2);
         nSpecific = size(value,2);
         if size(header,2) == (4+nMeta+nSpecific)
            header(:,(5+nMeta):end) = value;
            blockObj.VideoHeader = header;
         else
            if blockObj.Verbose
               dbstack();
               [fmt,idt] = getDescriptiveFormatting(blockObj);
               nigeLab.sounds.play('pop',0.5);
               nigeLab.utils.cprintf('Errors*','%s[BLOCK.SET]: ',idt);
               nigeLab.utils.cprintf(fmt,...
                  ['Wrong dimensions: Header has %g columns but ' ...
                  'should have %g columns\n'],size(header,2),...
                  4+nMeta+nSpecific);
            end
            return; % Otherwise dimensions aren't correct
         end
      end
      
      % [DEPENDENT]  Returns .VideoHeader property
      function value = get.VideoHeader(blockObj)
         %GET.VIDEOHEADER  Returns .VideoHeader property
         %
         %  value = get(obj,'VideoHeader');
         %  * Rows of `value` correspond to each `Videos` element of
         %     blockObj.
         %  * value(:,1) := Type (2, for each row)
         %  * value(:,2) := # of 'Meta' columns in `'snippet'` of diskfile_
         %  * value(:,3) := 1 (mask/enabled) or 0 (unmask/disabled)
         %  * value(:,4) := neural offset (seconds)
         %     --> This is "GrossOffset - VideoOffset"; see .Videos for
         %     more details.
         %  * value(:,5+) := first <value(:,2)> columns are 'VarType'
         %    + (see ~/+nigeLab/+workflow/defaultHotkeyFcn.m)
         %    + Remaining columns correspond to 'TrialOffset' (seconds),
         %      where neural time for a trial would be 
         %        >> tNeuTrial = tTrialVid - GrossOffset - TrialOffset;
         %        --> TrialOffset corresponds to camera/trial specific
         %            offsets that may vary over the recording duration
         %            depending on framerate jitter etc.
         
         if isempty(blockObj.VideoHeader_)
            if isempty(blockObj.Events)
               value = [];
               return;
            end
            value = getEventData(blockObj,blockObj.ScoringField,...
               'data','Header');
            blockObj.VideoHeader_ = value;
         else
            value = blockObj.VideoHeader_;
         end
      end
      function set.VideoHeader(blockObj,value)
         %SET.VIDEOHEADER  Assigns .VideoHeader property
         % 
         %  set(blockObj,'VideoHeader',value);
         %  * Sets blockObj.VideoHeader_ transient store
         %  * Sets 'Header' diskfile_ using 'data' property (full file)
         
         blockObj.VideoHeader_ = value;
         setEventData(blockObj,blockObj.ScoringField,'data','Header',value);
      end
      
      % [DEPENDENT]  Interact with "Header" Event file to get "Index" attr
      function value = get.VideoIndex(blockObj)
         %GET.VIDEOINDEX  Interact with "Header" file to get "Index" attr
         %
         %  value = get(blockObj,'VideoIndex');
         %  --> Returns 'Trials' attribute: Index
         
         if isempty(blockObj.VideoIndex_)
            tIdx = getEventsIndex(blockObj,blockObj.ScoringField,'Header');
            value = getAttr(...
               blockObj.Events.(blockObj.ScoringField)(tIdx).data,...
               'Index');
            blockObj.VideoIndex_ = value;
         else
            value = blockObj.VideoIndex_;
         end
      end
      function set.VideoIndex(blockObj,value)
         %SET.VIDEOINDEX  Interact with "Header" file to set "Index" attr
         %
         %  set(blockObj,'VideoIndex',value);
         tIdx = getEventsIndex(blockObj,blockObj.ScoringField,'Header');
         s = setAttr(blockObj.Events.(blockObj.ScoringField)(tIdx).data,...
            'Index',int8(value));
         if s
            blockObj.VideoIndex_ = value;
         end
      end
      % % % % % % % % % % END (DEPENDENT) GET/SET.PROPERTY METHODS % % %

      % Overloaded method to get 'end' indexing
      function ind = end(obj,k,n)
          if n>2
              % called by {}
              warning(['nigeLab:' mfilename 'unsupportedOperator'],...
                  '""end"" operator not supported in this context.\nThis may lead to unexpexted behavior.');
              ind = builtin('end',obj,k,n);
          else
              ind = builtin('end',obj,k,n);
          end
      end
      
      % Overloaded NUMARGUMENTSFROMSUBSCRIPT method for parsing indexing.
      function n = numArgumentsFromSubscriptUNUSED(blockObj,s,indexingContext)
         % NUMARGUMENTSFROMSUBSCRIPT  Parse # args based on subscript type
         %
         %  n = blockObj.numArgumentsFromSubscript(s,indexingContext);
         %
         %  s  --  struct from SUBSTRUCT method for indexing
         %  indexingContext  --  matlab.mixin.util.IndexingContext Context
         %                       in which the result applies.
         
         dot = strcmp({s(1:min(length(s),2)).type}, '.');
         if sum(dot) < 2
            isValidForArgsOut = ...
               (indexingContext == matlab.mixin.util.IndexingContext.Statement) || ...
               (indexingContext == matlab.mixin.util.IndexingContext.Expression);
            if  isValidForArgsOut &&...
                  any(dot) && any(strcmp(s(dot).subs,methods(blockObj)))
               
               mc = metaclass(blockObj);
               calledmethod=(strcmp(s(dot).subs,{mc.MethodList.Name}));
               n = numel(mc.MethodList(calledmethod).OutputNames);
            else
               n = builtin('numArgumentsFromSubscript',...
                  blockObj,s,indexingContext);
            end
         else
            n = builtin('numArgumentsFromSubscript',...
               blockObj,s,indexingContext);
         end
      end
   end
   
   % SEALED,PUBLIC
   methods (Sealed,Access=public)
      % Returns colormaps for different things
      function C = getColorMap(obj,type,N)
         %GETCOLORMAP  Returns colormaps for different things
         %
         %  C = getColorMap(obj,type,N);
         %
         %  obj  : nigelObj object
         %
         %  type : 'Trial' or 'EventTimes' or 'Meta' etc. (case-based)
         %     * If not specified, 'Trial' is the default
         %
         %  N    : Number of colormap rows to return
         %     * If not specified, depends on 'type' argument
         
         if nargin < 2
            type = 'Trial';
         end
         
         switch type
            case 'Trial'
               if nargin < 3
                  N = numel(obj.Trial);
               end
               C = nigeLab.utils.cubehelix(max(N,1),0.25,N/5,...
                  3.0,0.6,[0.3 0.7],[0.25 0.75]);
            case 'EventTimes'
               if nargin < 3
                  N = sum(obj.Pars.Video.VarType == 1);
               end
               C = nigeLab.utils.cubehelix(N,2.0,1.5,...
                  3.0,0.6,[0.3 0.7],[0.25 0.75]);
            case 'Meta'
               if nargin < 3
                  N = sum(obj.Pars.Video.VarType > 1);
               end
               C = nigeLab.utils.cubehelix(N,1.0,1.5,...
                  3.0,0.6,[0.3 0.7],[0.25 0.75]);
         end
      end
   end
   
   % PROTECTED
   methods (Access=protected)
      % Modify inherited superclass name parsing method
      function meta = parseNamingMetadata(blockObj,fName,pars)
         %PARSENAMINGMETADATA  Parse metadata from file or folder name
         %
         %  name = PARSENAMINGMETADATA(obj);
         %
         %  --------
         %   INPUTS
         %  --------
         %     obj      :     nigeLab.Block class object
         %
         %   fName      :     (char array) Full filename of Input
         %
         %    pars      :     Pars struct with following fields:
         %                    --> 'VarExprDelimiter' (splits fName into 
         %                          chunks used for parsing variables)
         %                    --> 'DynamicVarExp' (char regular expression
         %                          that uses IncludeChar and ExcludeChar
         %                          to get the dynamic variable tokens to
         %                          keep or exclude)
         %                    --> 'IncludeChar' (char indicating you keep
         %                          that dynamically parsed variable)
         %                    --> 'ExcludeChar' (char indicating to discard
         %                          that dynamically parsed variable)
         %                    --> 'SpecialMeta' (struct containing a "list"
         %                          field, 'SpecialVars', which is a cell
         %                          array of other fieldnames. These are
         %                          all structs with the fields 'vars' and
         %                          'cat', which indicate which variables
         %                          should be stuck together and what
         %                          character to stick them together with)
         %                    --> 'NamingConvention' (cell array of char
         %                          arrays indicating how the parsed
         %                          dynamic variables should be stuck back
         %                          together in order to create Block name)
         %                    --> 'Concatenater' char used to concatenate
         %                          elements indicated by NamingConvention
         %
         %  --------
         %   OUTPUT
         %  --------
         %    name         :     Name of the obj
         %
         %    meta         :     Metadata struct parsed from name
         
         if nargin < 2
            fName = blockObj.RecFile;
         end
         
         if nargin < 3
            pars = blockObj.getParams('Block');
            if isempty(pars)
               blockObj.updateParams('Block');
               pars = blockObj.Pars.Block;
            end
         end
         
         if isdir(fName)
            fName = blockObj.Input;
         end
         
         % Make sure that 'AnimalID' and 'RecID' are in SpecialMeta
         if isfield(pars.SpecialMeta,'SpecialVars')
            pars.SpecialMeta.SpecialVars = union(...
               pars.SpecialMeta.SpecialVars,{'AnimalID','RecID'});  
         else
            pars = nigeLab.defaults.Block;
            pars.SpecialMeta.SpecialVars = union(...
               pars.SpecialMeta.SpecialVars,{'AnimalID','RecID'});
         end
         
         % % % % Run supermethod@superclass % % % % %
         meta = parseNamingMetadata@nigeLab.nigelObj(...
            blockObj,fName,pars);
         
         % % % % Parse additional parameters for BLOCK % % % % 
         
         % If RecordingDate isn't one of the specified "template" 
         % variables from .Pars.(obj.Type).NamingConvention property, then 
         % parse it from Year, Month, and Day (meta variables). 
         % This will be helpful for handling file names for TDT recording 
         % blocks, which don't automatically append RecDate and RecTime
         f = fieldnames(meta);
         if sum(ismember(f,{'RecDate'})) < 1
            if isfield(meta,'Year') && ...
                  isfield(meta,'Month') && ...
                  isfield(meta,'Day')
               YY = meta.Year((end-1):end);
               MM = meta.Month;
               DD = sprintf('%.2d',str2double(meta.Day));
               meta.RecDate = [YY MM DD];
            else
               meta.RecDate = 'YYMMDD';
               if obj.Verbose
                  [fmt,idt] = getDescriptiveFormatting(blockObj);
                  nigeLab.utils.cprintf('Errors*','%s[BLOCK/PARSE]: ',idt);
                  nigeLab.utils.cprintf(fmt,...
                     'Unable to parse date from %s name (%s).\n',...
                     upper(obj.Type),fName);
               end
            end
         end
         % Also needs `RecTime` for DashBoard
         if ~isfield(meta,'RecTime')
            meta.RecTime = 'hhmmss';
         end
         % Also needs `RecTime` for DashBoard
         if ~isfield(meta,'RecTime')
            meta.RecTime = 'hhmmss';
         end
         % Get `FileExt` if it was parsed
         blockObj.FileExt = meta.FileExt;
         blockObj.Meta = nigeLab.nigelObj.MergeStructs(blockObj.Meta,meta);
      end
      
      % Modify inherited ID file saving method
      function flag = saveIDFile(blockObj)
         %SAVEIDFILE  Save small folder identifier file
         %
         %  flag = blockObj.saveIDFile();
         %  --> Returns true if save was successful
         %
         %  Adds the following fields to .nigelBlock file via `propList`:
         %     * 'FileExt'
         %     * 'RecType'
         %     * 'RecFile'
         %     * 'HasVideoTrials'
         
         BLOCK_PROPS = {'FileExt', 'RecType', 'RecFile', 'HasVideoTrials'};
         flag = saveIDFile@nigeLab.nigelObj(blockObj,BLOCK_PROPS);
         if ~flag
            % Missing RecFile or IDFile
            return;
         end
         
      end
   end
   
   % RESTRICTED:{?nigeLab.nigelObj,?nigeLab.Tank,?nigeLab.Animal}
   methods (Access={?nigeLab.nigelObj,?nigeLab.Tank,?nigeLab.Animal})
      function updateVideosFolder(blockObj,newFolderPath)
         %UPDATEVIDEOSFOLDER  Updates all Videos.fname with newFolderPath
         %
         %  updateVideosFolder(blockObj);
         %  blockObj : nigeLab.Block object
         %
         %  * When only given one input argument, it automatically directly
         %     uses the value in ~/+nigeLab/+defaults/Video.m as the value
         %     of `newFolderPath` (pars.VidFilePath)
         %     --> If there are more than one element, it automatically
         %         chooses the first cell array element.
         %
         %  updateVideosFolder(blockObj,newFolderPath);
         %  
         %  newFolderPath : Char array of new video folder path.
         %  * This path should contain all the "full" videos that had been
         %     associated with .Videos elements. Use this method if you
         %     moved the folder containing Videos for some reason.
         %
         %  * To update all Videos in a Tank, call as:
         %    `runFun(tankObj,'updateVideosFolder',newFolderPath);`
         %
         %     e.g.
         %     >> runFun(tankObj,'updateVideosFolder','new/videos/folder');
         
         if nargin < 2
            newFolderPath = [];
         end
         
         if numel(blockObj) > 1
            for i = 1:numel(blockObj)
               updateVideosFolder(blockObj(i),newFolderPath);
            end
            return;
         end
         
         if isempty(newFolderPath)
            updateParams(blockObj,'Video','Direct');
            newFolderPath = blockObj.Pars.Video.VidFilePath{1};
         end
         
         updateVideoFileLocation(blockObj.Videos,newFolderPath);
      end
   end
   
   % RESTRICTED:nigeLab.libs.VideosFieldType
   methods (Access=?nigeLab.libs.VideosFieldType)
      s = parseVidFileExpr(blockObj,ext)        % Get expression to match for video files and wipe Block.Meta.Video table
      index = parseVidFileName(blockObj,fName,keyIndex,forceTrials)  % Add to Block.Meta.Video table and return corresponding index
   end
   
   % PUBLIC
   methods (Access=public)
% Start Deprecated % % % % % % % % % % % % % % % % % % % % % % % % % % % %
%       setProp(blockObj,varargin) % Set property for all blocks in array
%       --> Deprecated (inherited from `nigelObj`)
%       [blockObj,idx] = findByKey(blockObjArray,keyStr,keyType); % Find block from block array based on public or private hash
%       --> Deprecated (inherited from `nigelObj`)
%       flag = updatePaths(blockObj,SaveLoc)     % updates the path tree and moves all the files
%       --> Deprecated (inherited from `nigelObj`)
%       [flag,p] = updateParams(blockObj,paramType,forceFromDefaults) % Update parameters
%       --> Deprecated (inherited from `nigelObj`)
%       fieldIdx = checkCompatibility(blockObj,requiredFields) % Checks if this block is compatible with required field names
%       --> Deprecated (inherited from `nigelObj`)
%       flag = checkParallelCompatibility(blockObj,isUpdated) % Check if parallel can be run
%       --> Deprecated (inherited from `nigelObj`)
%       flag = linkToData(blockObj,suppressWarning) % Link to existing data
%       --> Deprecated (inherited from `nigelObj`) 
%       fileType = getFileType(blockObj,field) % Get file type corresponding to field
%       --> Deprecated (inherited from `nigelObj`) 
%       [fieldType,n] = getFieldType(blockObj,field) % Get type corresponding to field
%       --> Deprecated (inherited from `nigelObj`) 
%       [fieldIdx,n] = getFieldTypeIndex(blockObj,fieldType) % Get index of all fields of a given type
%       --> Deprecated (inherited from `nigelObj`) 
% % % % % % % % % % % % % % % % % % % % % % % % % % End Deprecated % % % %

      % Scoring videos:
      fig = scoreVideo(blockObj) % Score videos manually to get behavioral alignment points
      fig = alignVideoManual(blockObj,digStreams,vidStreams); % Manually obtain alignment offset between video and digital records
      offset = guessVidStreamAlignment(blockObj,digStreamInfo,vidStreamInfo);
      addScoringMetadata(blockObj,fieldName,info); % Add scoring metadata to table for tracking scoring on a video for example
      clearScoringMetadata(blockObj,fieldName);  % Erase "empty" scoring metadata for a given tracking field
      info = getScoringMetadata(blockObj,fieldName,scoringID); % Retrieve row of metadata scoring
      [tStart,tStop] = getTrialStartStopTimes(blockObj,optStart,optStop); % Returns neural times of "trial" start and stop times
      [csvFullName,metaName,formatSpec] = getVideoFileList(blockObj,trialVideoStatus); % Returns name of .csv table file and the corresponding table field of blockObj.Meta
      
      % Methods for data extraction:
      flag = checkActionIsValid(blockObj,nDBstackSkip);     % Throw error if appropriate processing not yet complete
      flag = doAutoClustering(blockObj,chan,unit,useSort)   % Do automatic spike clustiring
      flag = doBehaviorSync(blockObj)                       % Get sync from neural data for external triggers
      flag = doEventDetection(blockObj,behaviorData,vidOffset,forceHeaderExtraction)         % Detect "Trials" for candidate behavioral Events
      flag = doEventHeaderExtraction(blockObj,behaviorData,vidOffset,forceHeaderExtraction)  % Create "Header" for behavioral Events
      flag = doLFPExtraction(blockObj)       % Extract LFP decimated streams
      flag = doRawExtraction(blockObj)       % Extract raw data to Matlab BLOCK
      flag = doReReference(blockObj)         % Do virtual common-average re-reference
      flag = doSD(blockObj)                  % Do spike detection for extracellular field
      flag = doTrialVidExtraction(blockObj)  % Extract "chunks" of video frames as trial videos
      flag = doUnitFilter(blockObj)          % Apply multi-unit activity bandpass filter
      flag = doVidInfoExtraction(blockObj,vidFileName,forceParamsUpdate) % Get video information
      flag = doVidSyncExtraction(blockObj)   % Get sync info from video

      % Methods for streams info
      stream = getStream(blockObj,streamName,scaleOpts); % Returns stream data corresponding to streamName
      
      % Methods for parsing channel info
      flag = parseProbeNumbers(blockObj) % Get numeric probe identifier
      flag = setChannelMask(blockObj,includedChannelIndices) % Set "mask" to look at
      
      % Methods for parsing spike info:
      tagIdx = parseSpikeTagIdx(blockObj,tagArray) % Get tag ID vector
      ts = getSpikeTimes(blockObj,ch,class)    % Get spike times (sec)
      idx = getSpikeTrain(blockObj,ch,class)   % Get spike sample indices
      spikes = getSpikes(blockObj,ch,class,type)   % Get spike waveforms
      features = getSpikeFeatures(blockObj,ch,class) % Get extracted features
      sortIdx = getSort(blockObj,ch,suppress)  % Get spike sorted classes
      clusIdx = getClus(blockObj,ch,suppress)  % Get spike cluster classes
      [tag,str] = getTag(blockObj,ch)          % Get spike sorted tags
      flag = saveChannelSpikingEvents(blockObj,ch,spk,feat,art) % Save spikes for a channel
      flag = checkSpikeFile(blockObj,ch) % Check a spike file for compatibility
      
      % Method for accessing event info:
      [idx,field] = getEventsIndex(blockObj,field,eventName); % Returns index to Events field as well as name of Events.(field)
      [data,blockIdx] = getEventData(blockObj,field,prop,ch,matchValue,matchField) % Retrieve event data
      [flag,idx] = setEventData(blockObj,fieldName,eventName,propName,value,rowIdx,colIdx);
      
      % Computational methods:
      [tf_map,times_in_ms] = analyzeERS(blockObj,options) % Event-related synchronization (ERS)
      analyzeLFPSyncIndex(blockObj)  % LFP synchronization index
      rms_out = analyzeRMS(blockObj,type,sampleIndices)  % Compute RMS for channels
      
      % Methods for visualizing data:
      flag = plotWaves(blockObj,ax,field,idx,computeRMS)          % Plot stream snippets
      flag = plotSpikes(blockObj,ch)      % Show spike clusters for a single channel
      flag = plotOverlay(blockObj)        % Plot overlay of values on skull
      
      % Methods for associating/displaying info about blocks:
      L = list(blockObj,keyIdx) % List of current associated files for field or fields
      flag = linkField(blockObj,fieldIndex)     % Link field to data
      flag = linkChannelsField(blockObj,field,fType)  % Link Channels field data
      flag = linkEventsField(blockObj,field)    % Link Events field data
      flag = linkStreamsField(blockObj,field)   % Link Streams field data
      flag = linkVideosField(blockObj,field)    % Link Videos field data
      flag = linkTime(blockObj)     % Link Time stream
      flag = linkNotes(blockObj)    % Link notes metadata
      flag = linkProbe(blockObj)    % Link probe metadata
      
      % Methods for storing & parsing metadata:
      h = takeNotes(blockObj)             % View or update notes on current recording
      parseNotes(blockObj,str)            % Update notes for a recording
      header = parseHeader(blockObj,fid)  % Parse header depending on structure
      
      % Methods for parsing Fields info:
      [fieldIdx,n] = getStreamsFieldIndex(blockObj,field,type) % Get index into Streams for a given Field
      notifyStatus(blockObj,field,status,channel) % Triggers event notification to blockObj
      opOut = updateStatus(blockObj,operation,value,channel) % Indicate completion of phase
      status = getStatus(blockObj,operation,channel)  % Retrieve task/phase status
      
      % Miscellaneous utilities:
      N = getNumBlocks(blockObj) % This is just to make it easier to count total # blocks
      str = reportProgress(blockObj,str_expr,pct,notification_mode,tag_str) % Update the user of progress
      checkMask(blockObj) % Just to double-check that empty channels are masked appropriately
      idx = matchProbeChannel(blockObj,channel,probe); % Match Channels struct index to channel/probe combo
   end
   
   % HIDDEN,PUBLIC
   methods (Hidden,Access=public)
% Start Deprecated % % % % % % % % % % % % % % % % % % % % % % % % % % % %
%       flag = genPaths(blockObj,tankPath,useRemote) % Generate paths property struct
%       --> Deprecated (inherited from `nigelObj`)
%       flag = getSaveLocation(blockObj,saveLoc) % Prompt to set save dir
%       --> Deprecated (inherited from `nigelObj`)
%       paths = getFolderTree(blockObj,paths,useRemote) % returns a populated path struct
%       --> Deprecated (inherited from `nigelObj`)
%       [name,meta] = parseNamingMetadata(blockObj); % Get metadata struct from recording name
%       --> Deprecated (inherited from `nigelObj`)
%       parseRecType(blockObj)              % Parse the recording type
%       --> Deprecated (inherited from `nigelObj`)
% % % % % % % % % % % % % % % % % % % % % % % % % % End Deprecated % % % %

      flag = intan2Block(blockObj,fields,paths) % Convert Intan to BLOCK
      flag = tdt2Block(blockObj) % Convert TDT to BLOCK
      flag = rhd2Block(blockObj,recFile,saveLoc) % Convert *.rhd to BLOCK
      flag = rhs2Block(blockObj,recFile,saveLoc) % Convert *.rhs to BLOCK
      flag = init(blockObj) % Initializes the BLOCK object
      flag = initChannels(blockObj,header);   % Initialize Channels property
      flag = initEvents(blockObj);     % Initialize Events property
      flag = initStreams(blockObj,header);    % Initialize Streams property
      flag = initVideos(blockObj,forceNewParams);     % Initialize Videos property
      masterIdx = matchChannelID(blockObj,masterID); % Match unique channel ID
      header = parseHierarchy(blockObj)   % Parse header from file hierarchy
      blocks = splitMultiAnimals(blockObj,varargin)  % splits block with multiple animals in it
   
      function formatTrialVideosForExtraction(blockObj)
         %FORMATTRIALVIDEOSFOREXTRACTION  Moves videos to correct place
         %
         %  formatTrialVideosForExtraction(blockObj);
         
         if numel(blockObj) > 1
            for i = 1:numel(blockObj)
               formatTrialVideosForExtraction(blockObj(i));
            end
            return;
         end
         
         if ~blockObj.HasVideoTrials
            return;
         end
         
         
      end
      
      function lockData(blockObj,fieldType)
         %LOCKDATA  Lock all data of a given fieldType
         %
         %  lockData(blockObj,fieldType);
         %
         %  --> default `fieldType` (if not specified) is 'Events'
         
         if nargin < 2
            fieldType = 'Events';
         end
         
         if numel(blockObj) > 1
            for i = 1:numel(blockObj)
               lockData(blockObj(i),fieldType);
            end
            return;
         end
         
         idx = getFieldTypeIndex(blockObj,fieldType);
         idx = find(idx);
         if isempty(idx)
            return;
         end
         for i = 1:numel(idx)
            f = blockObj.Fields{idx(i)};
            if ~isfield(blockObj.(fieldType),f)
               continue;
            end
            for j = 1:numel(blockObj.(fieldType).(f))
               if isempty(blockObj.(fieldType).(f)(j).data)
                  continue;
               end
               lockData(blockObj.(fieldType).(f)(j).data);
            end
         end
      end
      
      function unlockData(blockObj,fieldType)
         %UNLOCKDATA  Unlock all data of a given fieldType
         %
         %  unlockData(blockObj,fieldType)
         %
         %  --> default `fieldType` (if not specified) is 'Events'
         
         if nargin < 2
            fieldType = 'Events';
         end
         
         if numel(blockObj) > 1
            for i = 1:numel(blockObj)
               unlockData(blockObj(i),fieldType);
            end
            return;
         end
         
         idx = getFieldTypeIndex(blockObj,fieldType);
         idx = find(idx);
         if isempty(idx)
            return;
         end
         for i = 1:numel(idx)
            f = blockObj.Fields{idx(i)};
            if ~isfield(blockObj.(fieldType),f)
               continue;
            end
            for j = 1:numel(blockObj.(fieldType).(f))
               if isempty(blockObj.(fieldType).(f)(j).data)
                  continue;
               end
               unlockData(blockObj.(fieldType).(f)(j).data);
            end
         end
      end
   end
   
   % HIDDEN,PRIVATE
   methods (Hidden,Access=private)
      eventData = getStreamsEventData(blockObj,field,prop,eventName,matchProp,matchValue)
      eventData = getChannelsEventData(blockObj,field,prop,ch,matchProp,matchValue)
      flag = updateVidInfo(blockObj,forceExtraction) % Update video info
   end
   
   % STATIC,PUBLIC
   methods (Static,Access=public)
      % Overloaded method to instantiate "Empty" Blocks from constructor
      function blockObj = Empty(n)
         % EMPTY  Creates "empty" block or block array
         %
         %  blockObj = nigeLab.Block.Empty();  % Makes a scalar
         %  blockObj = nigeLab.Block.Empty(n); % Make n-element array Block
         
         if nargin < 1
            n = [0, 0];
         else
            n = nanmax(n,0);
            if isscalar(n)
               n = [0, n];
            end
         end
         
         blockObj = nigeLab.Block(n);
      end
   end
   
   % STATIC,SEALED,PUBLIC
   methods (Static,Sealed,Access=public)
      field = getOperationField(operation); % Get field associated with operation
      blockObj = loadRemote(targetBlockFile); % Load block on remote worker
   end
   
   % SEALED,HIDDEN,PUBLIC
   methods (Sealed,Hidden,Access=public)
      varargout = testbench(blockObj,varargin); % Testbench with access to protected methods
      
      function SDargsout = testSD(blockobj,SDFun,data,SDPars)
          SDargsout = cell(1,nargout(SDFun));
          [SDargsout{:}] = feval(SDFun,data,SDPars);
      end
   end
   % % % % % % % % % % END METHODS% % %
end