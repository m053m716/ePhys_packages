function data = getStreamsFromIndexing(obj,idx)
%GETSTREAMSFROMINDEXING  Return data based on indexing
%
%  data = getStreamsFromIndexing(obj,idx,iCol);
%
%  obj : nigeLab.libs.DiskData object
%  idx : Indexing vector (numeric)
%
%  data : Data read from diskfile

data = [];
if nargin < 2
   idx = inf;
elseif isempty(idx) % If no rows requested, then return empty double
   return;
elseif islogical(idx)
   idx = find(idx);
end

% Make sure that idx and iCol are numeric
N = obj.size_(2); % Length
if isinf(idx)
   idx = 1:N;
end

% First step: make a list of "chunks" to read
starts = idx([true, diff(idx) > 1]); % All "starts" of included indices
stops = idx([diff(idx) > 1, true]);  % All "stops" of runs of consecutive
counts = stops - starts + 1;         % Lengths of each "run"

% Second step: read out data in "chunks"
varname_ = ['/' obj.name_];
data = nan(1,numel(idx));
iCur = 1;
for i = 1:numel(starts)
   cur = iCur:(iCur+counts(i)-1);
   iCur = cur(end)+1;
   data(1,cur)=h5read(obj.diskfile_,varname_,[1 starts(i)],[1 counts(i)]);
end

end
