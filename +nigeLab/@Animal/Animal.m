classdef Animal < handle
   %% ANIMAL   Class for handling each nigeLab.Block for one animal
   
   %% PUBLIC PROPERTIES
      properties (GetAccess = public, SetAccess = public,SetObservable)
      Name         % Animal identification code

      end
   
   properties (GetAccess = public, SetAccess = public)
      Blocks       % Children (nigeLab.Block objects)
      Probes       % Electrode configuration structure
   end
   
   properties (SetAccess = private, GetAccess = public)
       Paths         % Path to Animal folder
   
   end
   
   
   properties (GetAccess = public, SetAccess = private, Hidden = true)
      Pars              % parameters struct for templates from nigeLab.defaults
      
      TankLoc           % directory for saving Animal
      RecDir            % directory with raw binary data in intan format
      ExtractFlag       % flag status of extraction for each block
   end
   
   properties  (SetAccess = private, GetAccess = private) 
       RecLocDefault     % Default location of raw binary recording
       TankLocDefault  % Default location of BLOCK
   end
   %% PUBLIC METHODS
   methods (Access = public)
      function animalObj = Animal(varargin)
         %% Creates an animal object with the related Blocks
         
%          animalObj = def_params(animalObj);
         animalObj.updateParams('Animal');
         animalObj.updateParams('all');
         
        addlistener(animalObj,'Name','PostSet',@animalObj.updateAnimalNameInChlildBlocks);
         
         %% PARSE VARARGIN
         for iV = 1:2:numel(varargin) % Can specify properties on construct
            if ~ischar(varargin{iV})
               continue
            end
            p = findprop(animalObj,varargin{iV});
            if isempty(p)
               continue
            end
            animalObj.(varargin{iV}) = varargin{iV+1};
         end
         
         %% LOOK FOR ANIMAL DIRECTORY
         if isempty(animalObj.RecDir)
            animalObj.RecDir = uigetdir(animalObj.Pars.DefaultRecLoc,...
               'Select directory with the the recordings');
            if animalObj.RecDir == 0
               error('No animal selected. Object not created.');
            end
         else
            if exist(animalObj.RecDir,'dir')==0
               error('%s is not a valid block directory.',animalObj.RecDir);
            end
         end
         
         %% INITIALIZE ANIMAL OBJECT
         animalObj.init;
       
      end
      
      
      function addBlock(animalObj,BlockPath)
      %% ADDBLOCK  Add Block to Blocks property   
         newBlock= nigeLab.Block('RecFile',BlockPath,...
             'AnimalLoc',animalObj.Paths.SaveLoc);
         animalObj.Blocks = [animalObj.Blocks newBlock];
      end
      
      function save(animalObj)
         B=animalObj.Blocks;
         for ii=1:numel(B)
            B(ii).save;
         end
         save(fullfile([animalObj.Paths.SaveLoc '_Animal.mat']),'animalObj','-v7');
         animalObj.Blocks = B;
      end
      
      function animalobj = saveobj(animalobj)
         animalobj.Blocks = [];         
      end
      
      function Status = getStatus(animalObj,Operation)
         if nargin <2
            Status(1,:) = animalObj.Blocks(1).getStatus();
            for ii=2:numel(animalObj.Blocks)
               Status(ii,:) = animalObj.Blocks(ii).getStatus();
            end
         else
            Status(1,:) = animalObj.Blocks(1).getStatus(Operation);
            for ii=2:numel(animalObj.Blocks)
               Status(ii,:) = animalObj.Blocks(ii).getStatus(Operation);
            end
         end
      end
      
      %       updateID(blockObj,name,type,value)    % Update the file or folder identifier
      table = list(animalObj)                % List of recordings currently associated with the animal
      out = animalGet(animalObj,prop)       % Get a specific BLOCK property
      flag = animalSet(animalObj,prop)      % Set a specific BLOCK property
      
      mergeBlocks(animalObj,ind,varargin) % Concatenate two Blocks together
      removeBlocks(animalObj,ind)         % Disassociate a Block from Animal
      
      % Extraction methods
      flag = doUnitFilter(animalObj)      % Apply Unit Bandpass filter to all raw data in Blocks of Animal
      flag = doReReference(animalObj)     % Re-reference all filtered data in Blocks of Animal
      flag = doRawExtraction(animalObj)   % Extract Raw Data for all Blocks in Animal
      flag = doLFPExtraction(animalObj)   % Extract LFP for all Blocks in Animal
      flag = doSD(animalObj)              % Extract spikes for all Blocks in Animal
      
      % Utility
      flag = updateParams(animalObj,paramType) % Update parameters of Animal and Blocks
      flag = updatePaths(animalObj,SaveLoc)     % Update folder tree of all Blocks
      linkToData(animalObj)                    % Link disk data of all Blocks in Animal
   end
   
   methods (Access = public, Hidden = true)
      clearSpace(animalObj,ask,usrchoice)
      updateNotes(blockObj,str) % Update notes for a recording
      
      flag = genPaths(animalObj,tankPath) % Generate paths property struct
      flag = findCorrectPath(animalObj,paths)   % Find correct Animal path
      flag = getSaveLocation(animalObj,saveLoc) % Prompt to set save dir
      flag = doAutoClustering(animalObj,chan,unit)
      
      N = getNumBlocks(animalObj); % Gets total number of blocks (useful interchangeably with Tank method)
   end
   
   %% PRIVATE METHODS
   methods (Access = 'private')
      init(animalObj) % Initializes the ANIMAL object
      def_params(animalObj)
      
      function updateAnimalNameInChlildBlocks(animalObj,~,~)
          for bb=1:numel(animalObj.Blocks)
             animalObj.Blocks(bb).Meta.AnimalID = animalObj.Name;
          end
      end
   end
   
   methods (Static)
      function animalObj = loadobj(animalObj)
         BL = dir(fullfile(animalObj.Paths.SaveLoc,'*_Block.mat'));
         load(fullfile(BL(1).folder,BL(1).name),'blockObj');
            animalObj.Blocks = blockObj;
         for ii=2:numel(BL)
            load(fullfile(BL(ii).folder,BL(ii).name),'blockObj');
            animalObj.Blocks(ii) = blockObj;
         end
      end
      
      
   end
   
end