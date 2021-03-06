function clusterIndex = getSort(blockObj,ch,suppressText)
%GETSORT     Retrieve list of spike Sorted class indices for each spike
%
%  clusterIndex = GETSORT(blockObj,ch);
%
%  --------
%   INPUTS
%  --------
%  blockObj    :     nigeLab.Block class object.
%
%    ch        :     Channel index for retrieving spikes.
%                    -> If not specified, returns a cell array with spike
%                          indices for each channel.
%                    -> Can be given as a vector.
%
%  suppressText:     Default: false; set to true to turn off print to
%                       command window when a channel is initialized.
%
%  --------
%   OUTPUT
%  --------
% clusterIndex :     Vector of spike classes (integers)
%                    -> If ch is a vector, returns a cell array of
%                       corresponding spike classes.

%% PARSE INPUT
if nargin < 2
    ch = 1:blockObj(1).NumChannels;
end

if nargin < 3
    suppressText =  ~blockObj.Verbose;
end

%% USE RECURSION TO ITERATE ON MULTIPLE CHANNELS
if (numel(ch) > 1)
    clusterIndex = cell(size(ch));
    for ii = 1:numel(ch)
        clusterIndex{ii} = getSort(blockObj,ch(ii));
    end
    return;
end

%% USE RECURSION TO ITERATE ON MULTIPLE BLOCKS
if (numel(blockObj) > 1)
    clusterIndex = [];
    for ii = 1:numel(blockObj)
        clusterIndex = [clusterIndex; getSort(blockObj(ii),ch)]; %#ok<AGROW>
    end
    return;
end

%% CHECK TO BE SURE THAT THIS BLOCK/CHANNEL HAS BEEN SORTED
fType = blockObj.getFileType('Sorted');
fName = fullfile(sprintf(strrep(blockObj.Paths.Sorted.file,'\','/'),...
            num2str(blockObj.Channels(ch).probe),...
            blockObj.Channels(ch).chStr));
    
if getStatus(blockObj,'Sorted',ch) % If sorting already exists, use those
    clusterIndex = getCIFromExistingFile(blockObj,ch);
    if ~any(clusterIndex) % if all indexes are zero
        clusterIndex = blockObj.getClus(ch);
    end
elseif exist(fName,'file')~=0       % Technically, files could exist but Status not updated...
    load(fName,'data');
    clusterIndex = data(:,2);
    if ~any(clusterIndex) % if all indexes are zero
        clusterIndex = blockObj.getClus(ch);
        ts = getSpikeTimes(blockObj,ch);
        n = numel(ts);
        data = [zeros(n,2) clusterIndex ts zeros(n,1)];
        if exist(blockObj.Paths.Sorted.dir,'dir')==0
            mkdir(blockObj.Paths.Sorted.dir);
        end
        blockObj.Channels(ch).Sorted = nigeLab.libs.DiskData(fType,...
            fName,data,'overwrite', true);
        if ~suppressText
            fprintf(1,'Initialized Sorted file for P%d: Ch-%s\n',...
                blockObj.Channels(ch).probe,blockObj.Channels(ch).chStr);
            
        end
    else
         blockObj.Channels(ch).Sorted = nigeLab.libs.DiskData(fType,...
            fName);
    end
    updateStatus(blockObj,'Sorted',true,ch);

else
    nigeLab.utils.cprintf('*SystemCommands',true,'*Sorted* data were not found. Using *Clusters* instead.\n');
    clusterIndex = blockObj.getClus(ch);
    if ~isempty(clusterIndex)
        ts = getSpikeTimes(blockObj,ch);
        n = numel(ts);
        data = [zeros(n,2) clusterIndex ts zeros(n,1)];
        if exist(blockObj.Paths.Sorted.dir,'dir')==0
            mkdir(blockObj.Paths.Sorted.dir);
        end
        blockObj.Channels(ch).Sorted = nigeLab.libs.DiskData(fType,...
            fName,data,'access','w');
        if ~suppressText
            fprintf(1,'Initialized Sorted file for P%d: Ch-%s\n',...
                blockObj.Channels(ch).probe,blockObj.Channels(ch).chStr);
            
        end
    end
% elseif getStatus(blockObj,'Spikes',ch) % but spikes do
%     % initialize the 'Sorted' DiskData file
%     
%     
%     
%     ts = getSpikeTimes(blockObj,ch);
%     n = numel(ts);
%     clusterIndex = zeros(n,1);
%     data = [zeros(n,2) clusterIndex ts zeros(n,1)];
%     if exist(blockObj.Paths.Sorted.dir,'dir')==0
%         mkdir(blockObj.Paths.Sorted.dir);
%     end
%     blockObj.Channels(ch).Sorted = nigeLab.libs.DiskData(fType,...
%         fName,data,'access','w');
%     if ~suppressText
%         fprintf(1,'Initialized Sorted file for P%d: Ch-%s\n',...
%             blockObj.Channels(ch).probe,blockObj.Channels(ch).chStr);
%         
%     end
% else
%     clusterIndex = [];
end
end

function clusterIndex = getCIFromExistingFile(blockObj,ch)
%%GETCIFROMEXISTINGFILE    Get cluster index from existing file
% For backwards compatibility, make sure "tags" is not a cell

ftype = getFileType(blockObj,'Sorted');
info = getInfo(blockObj.Channels(ch).Sorted);
names = {info.Name};
tagIdx = find(strcmpi(names,'tag'),1,'first');

if isempty(tagIdx) % Everything is fine, return it the normal way
    clusterIndex = blockObj.Channels(ch).Sorted.value;
elseif strcmp(info(tagIdx).class,'cell')
    tag = blockObj.Channels(ch).Sorted.tag(:);
    tag = parseSpikeTagIdx(blockObj,tag);
    fname = getPath(blockObj.Channels(ch).Sorted);
    
    sorted = zeros(numel(tag),5);
    sorted(:,2) = blockObj.Channels(ch).Sorted.class(:);
    sorted(:,3) = tag;
    sorted(:,4) = getSpikeTimes(blockObj,ch);
    
    blockObj.Channels(ch).Sorted = ...
        nigeLab.libs.DiskData(ftype,fullfile(fname),...
        sorted,'access','w');
    clusterIndex = sorted(:,2);
    
elseif numel(info) > 1
    fname = getPath(blockObj.Channels(ch).Sorted);
    
    sorted = zeros(numel(info(1).size(1)),5);
    sorted(:,2) = blockObj.Channels(ch).Sorted.class(:);
    sorted(:,3) = blockObj.Channels(ch).Sorted.tag(:);
    sorted(:,4) = getSpikeTimes(blockObj,ch);
    
    blockObj.Channels(ch).Sorted = ...
        nigeLab.libs.DiskData(ftype,fullfile(fname),...
        sorted,'access','w');
    clusterIndex = sorted(:,2);
    
else % Everything is fine, return it the normal way
    clusterIndex = blockObj.Channels(ch).Sorted.value;
end
end

