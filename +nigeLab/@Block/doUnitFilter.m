function flag = doUnitFilter(blockObj)
%% DOUNITFILTER   Filter raw data using spike bandpass filter
%
%  blockObj = nigeLab.Block;
%  doUnitFilter(blockObj);
%
% By: MAECI 2018 collaboration (Federico Barban & Max Murphy)

%% GET DEFAULT PARAMETERS
flag = false;
if blockObj.UseParallel
   [~,nPars] = blockObj.updateParams('Notifications');
   p_db = nPars.DBLoc; 
   if exist(p_db,'dir')==0
      mkdir(p_db);
   end
   db_fname = fullfile(p_db,nPars.DBFile);
   db_id = fopen(db_fname,'a');
   fprintf(db_id,'(%s) Begin %s\n',char(datetime),mfilename);
   fclose(db_id);
else
   db_fname = '';
end
blockObj.checkActionIsValid();
if ~isempty(db_fname)
   db_id = fopen(db_fname);
   fprintf(db_id,'(%s) %s :: passed checkActionIsValid\n',...
      char(datetime),mfilename);
   fclose(db_id);
end

[~,pars] = blockObj.updateParams('Filt');
reportProgress(blockObj,'Filtering.',0,'toWindow','Filtering');
fType = blockObj.FileType{strcmpi(blockObj.Fields,'Filt')};

%% ENSURE MASK IS ACCURATE
blockObj.checkMask;

%% DESIGN FILTER
[b,a,zi,nfact,L] = pars.getFilterCoeff(blockObj.SampleRate);

%% DO FILTERING AND SAVE
str = nigeLab.utils.getNigeLink('nigeLab.Block','doUnitFilter',...
   'Unit Bandpass Filter');
str = sprintf('Applying %s',str);

blockObj.reportProgress(str,0,'toWindow','Filtering');

for iCh = blockObj.Mask

   if ~isempty(db_fname)
      db_id = fopen(db_fname);
      fprintf(db_id,'(%s) %s :: begin Filtering Channel %03g\n',...
         char(datetime),mfilename,iCh);
      fclose(db_id);
   end
   
   if blockObj.Channels(iCh).Raw.length <= nfact
      continue; % It should leave the updateFlag as false for this channel
   end
   if ~pars.STIM_SUPPRESS
      % Filter and and save amplifier_data by probe/channel
      pNum  = num2str(blockObj.Channels(iCh).probe);
      chNum = blockObj.Channels(iCh).chStr;   
      fName = sprintf(strrep(blockObj.Paths.Filt.file,'\','/'), ...
         pNum, chNum);
      
      % bank of filters. This is necessary when the designed filter is high
      % order SOS. Otherwise L should be one. See the filter definition
      % params in default.Filt
      data = blockObj.Channels(iCh).Raw(:);
      for ii=1:L
         data = (ff(b,a,data,nfact,zi));
      end
      
      blockObj.Channels(iCh).Filt = nigeLab.libs.DiskData(...
         fType,fName,data,...
         'access','w',...
         'size',size(data),...
         'class',class(data));
      
      blockObj.Channels(iCh).Filt = lockData(blockObj.Channels(iCh).Filt);
   else
      warning('STIM SUPPRESSION method not yet available.');
      return;
   end
   
   blockObj.updateStatus('Filt',true,iCh);
   curCh = find(blockObj.Mask == iCh,1,'first');
   pct = round(curCh/numel(blockObj.Mask) * 100);
   blockObj.reportProgress(str,pct,'toWindow','Filtering');
   blockObj.reportProgress('Filtering.',pct,'toEvent');
end

flag = true;
blockObj.linkToData('Filt');
blockObj.save;

end

function Y = ff(b,a,X,nEdge,IC)

%%
% nedge dimension of the edge effect
% IC initial condition. can usually be computed as
% K       = eye(Order - 1);
% K(:, 1) = a(2:Order);
% K(1)    = K(1) + 1;
% K(Order:Order:numel(K)) = -1.0;
% IC      = K \ (b(2:Order) - a(2:Order) * b(1));
% where order is the filter order as 
% Order = max(nb, na);

import nigeLab.utils.FilterX.*;

% User Interface: --------------------------------------------------------------
% Do the work: =================================================================
% Create initial conditions to treat offsets at beginning and end:
if ~iscolumn(X),X=X(:);end
% Use a reflection to extrapolate signal at beginning and end to reduce edge
% effects (BSXFUN would be some micro-seconds faster, but it is not available in
% Matlab 6.5):
Xi   = 2 * X(1) - X(2:(nEdge + 1));

Xf   = 2 * X(end) - X((end - nEdge):(end - 1));

% Use the faster C-mex filter function: -------------------------
% Filter initial reflected signal:
[~, Zi] = FilterX(b, a, Xi, IC * Xi(end),true);   

% Use the final conditions of the initial part for the actual signal:
[Ys, Zs]  = FilterX(b, a, X,  Zi);                    % "s"teady state
Yf        = FilterX(b, a, Xf, Zs, true);              % "f"inal conditions

% Filter signal again in reverse order:
[~, Zf] = FilterX(b, a, Yf, IC * Yf(1));  
Y         = FilterX(b, a, Ys, Zf, true);
Y = Y';
end