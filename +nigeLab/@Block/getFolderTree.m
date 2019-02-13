function paths = getFolderTree(blockObj,paths)
if nargin < 2
   paths = struct(); 
end
F = fieldnames(blockObj.BlockPars);
for iF = 1:numel(F) % For each field, update field type
   p = blockObj.BlockPars.(F{iF});
   
   if contains(p.Folder,'%s') % Parse for spikes stuff
      p.Folder = sprintf(strrep(p.Folder,'\','/'),...
         blockObj.SDPars.ID.(F{iF}));
   end
   
   % Set folder name for this particular Field
   paths.(F{iF}).dir = fullfile(paths.SaveLoc.dir,...
      [blockObj.Name,blockObj.Delimiter,p.Folder]);
   
   % Parse for both old and new versions of file naming convention
   paths.(F{iF}).file = fullfile(paths.(F{iF}).dir,[blockObj.Name p.File]);
   paths.(F{iF}).old = getOldFiles(p,paths.(F{iF}));
   paths.(F{iF}).info = fullfile(paths.(F{iF}).dir,[blockObj.Name p.Info]);
end
end

  function old = getOldFiles(p,fieldPath)
      %% GETOLDFILES  Get struct with file info for possible old files
      old = struct;
      for iO = 1:numel(p.OldFile)
         f = strsplit(p.OldFile{iO},'.');
         f = deblank(strrep(f{1},'*',''));
         O = dir(fullfile(fieldPath.dir,p.OldFile{iO}));
         if isempty(O)
            old.(f) = O;
         else
            if O(1).isdir
               old.(f) = dir(fullfile(O(1).folder,O(1).name,...
                  p.OldFile{iO}));
            else
               old.(f) = O;
            end
         end
      end
   end