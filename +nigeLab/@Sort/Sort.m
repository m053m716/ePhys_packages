classdef Sort < handle
%% SORT  User interface for "cluster-cutting" to manually classify spikes
%
%  nigeLab.Sort;
%  sortObj = nigeLab.Sort;
%  sortObj = nigeLab.Sort(nigelObj);
%
%   --------
%    INPUTS
%   --------
%   nigelObj  :     (Optional) If not provided, a UI for generation or
%                       loading of the correct orgExpObj pops up.
%                       Otherwise, the Sort class object parses which
%                       orgExpObj is given (based on object class), and
%                       presents the Sort interface based on that.
%
%   --------
%    OUTPUT
%   --------
%   Provides a graphical interface to combine and/or restrict spikes
%   included in each cluster. Works with spikes that have been extracted
%   using the NIGELAB workflow.
   
   %% PROPERTIES
   properties (SetAccess = public, GetAccess = public)
      Blocks      % Array of orgExp block objects
      Channels    % Struct containing channels info
   end
   
   properties (SetAccess = private, GetAccess = public)
      spk      % Contains spike snippets
      UI       % UI controller variable
   end
   
   properties (SetAccess = private, GetAccess = private)
      pars     % Parameters
      orig     % Original assignments
      prev     % Previous assignments
      
      progCatPars = struct(...
         'imgStrDef','Nigel_%03g.jpg',...
         'nImg',11,...
         'pawsInterval',0.05,...
         'progPctThresh',4);
   end
   
   events
      channelUpdated
      
   end
   
   %% METHODS
   methods (Access = public)
      function sortObj = Sort(nigelObj)
         %% SORT  Sort class object constructor
         %
         %  nigeLab.Sort;
         %  sortObj = nigeLab.Sort;
         %  sortObj = nigeLab.Sort(nigelObj);                       
         
         %% INITIALIZE PARAMETERS
         if ~initParams(sortObj)
            error(['nigeLab:' mfilename ':BadInit'],...
                  'Could not set parameters for sortObj.');
         end
         
         %% INITIALIZE INPUT DATA
         if nargin > 0
            if ~initData(sortObj,nigelObj)
               error(['nigeLab:' mfilename ':BadInit'],...
                  'sortObj array not created successfully.');
            end
         else
            if ~initData(sortObj)
               error(['nigeLab:' mfilename ':BadInit'],...
                  'sortObj array not created successfully.');
            end
         end
         
         %% INITIALIZE GRAPHICAL INTERFACE
         if ~initUI(sortObj)
            error('Error constructing graphical interface for sorting.');
         end
         
         if nargout == 0
            clear sortObj
         end

      end
      
      function flag = set(sortObj,name,value)
         %% SET   Overloaded set method for the nigeLab.Sort class object
         
         flag = false;
         switch lower(name)
            case 'channel'
               if ~isnumeric(value) || (value < 1)
                  warning('Channel value must be a positive integer.');
                  return;
               end
               
               if (value > sortObj.Channels.N)
                  warning('Only %d channels detected. %d is too large.',...
                     sortObj.Channels.N,value);
                  return;
               end
               
               sortObj.UI.ch = value;
               
            case 'cluster'
               if ~isnumeric(value) || (value < 1)
                  warning('Channel value must be a positive integer.');
                  return;
               end
               
               if (value > sortObj.pars.NCLUS_MAX)
                  warning('Only %d clusters allowed. %d is too large.',...
                     sortObj.pars.NCLUS_MAX,value);
                  return;
               end
               
               sortObj.UI.cl = value;
            
            otherwise
               builtin('set',sortObj,name,value);
         end
         flag = true;
               
         
      end
      
      function value = get(sortObj,name)
         %% GET   Overloaded get method for the nigeLab.Sort class object
         switch lower(name)
            case 'channel'
               value = sortObj.UI.ch;
               
            case 'cluster'              
               value = sortObj.UI.cl;
            
            otherwise
               builtin('get',sortObj,name);
         end
               
         
      end
      
      setChannel(sortObj,~,~) % Set the current channel in the UI
      setClass(sortObj,class) % Set the current sort class
      saveData(sortObj)       % Save the sorting
   end
   
   methods (Access = private)
      
      function exitScoring(sortObj)
         %% EXITSCORING    Exit the scoring interface
         
         % Remove the channel selector UI, if it exists
         if isvalid(sortObj.UI.ChannelSelector.Figure)
            close(sortObj.UI.ChannelSelector.Figure);
            clear sortObj.UI.ChannelSelector
         end
         
         % Remove the spike interface, if it exists
         if isvalid(sortObj.UI.SpikeImage.Figure)
            delete(sortObj.UI.SpikeImage.Figure);
            clear sortObj.UI.SpikeImage
         end
         
         % Delete the Sort object
         delete(sortObj);
         clear sortObj
      end
      
      flag = initParams(sortObj); % Initialize general parameters
      flag = initData(sortObj,nigelObj); % Initialize data structures
      flag = initUI(sortObj); % Initializes spike scoring UI parameters
      
      [spikes,feat,class,tag,ts,blockIdx] = getAllSpikeData(sortObj,ch); % Get spike info from all channels
      
      flag = parseBlocks(sortObj,nigelObj);  % Assigns Blocks property
      flag = parseAnimals(sortObj,nigelObj); % Assigns Blocks from Animals
      
      flag = setAxesPositions(sortObj); % Draw axes positions
      
      channelName = parseChannelName(sortObj); % Get all channel names
      
   end
   
end