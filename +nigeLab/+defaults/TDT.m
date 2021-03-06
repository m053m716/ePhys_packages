function varargout = TDT(varargin)
%TDT  Initialize TDT custom variables names

%% Waveform, stream
% specify here all the streams name you want to extract from the TDT datafile
% Our convention is to have one broadband datastream per probe and named
% Wave# where # is the probe number.
pars = struct;
pars.WaveformName = {'Wave'};

%% Other streams
% define here the names of the other streams you would like to extract and
% the variable where you would like to store them.
% Remember to modify the generate paths file to add the additionals folders
% you might want to save your data to!

pars.streamsName = {};
pars.streamsSource = {};             
pars.streamsTarget = {};
pars.streamsTargetFileName = {};

%% Events Data
% here you can define how to build the events structure. The structure will
% be build from the epocs data in the TDT data file.
% evsVar defines which epocs field you're intrested in. Every different
% field should ideally correspond to a different type of event. Here eg we
% are intrested in the stimulation events. Remember, you define the name of
% the epocs fields when you program the TDT executable!
% evsSource and evsTarget define where to get the data from the epocs
% structure and where to put it.
pars.evsVar = {'STIM','STyp'};
pars.evsSource = {{'STIM.name', 'STIM.onset',  'STIM.offset',  'TrCh.data',  'StCh.data',  'Curr.data'  };
                  {'STyp.name', 'STyp.onset',  'STyp.data'} };
                    
pars.evsTarget = {{'lbl',       'onset',       'offset',       'trigger',    'target',     'value'      };
                  {'lbl',       'onset',       'value'}};
                    
%% Parse output
if nargin < 1
   varargout = {pars};
else
   varargout = cell(1,nargin);
   f = fieldnames(pars);
   for i = 1:nargin
      idx = ismember(lower(f),lower(varargin{i}));
      if sum(idx) == 1
         varargout{i} = pars.(f{idx});
      end
   end
end
end
