function init(animalObj)
[~,NAME] = fileparts(animalObj.DIR);
animalObj.Name = NAME;

if isempty(animalObj.SaveLoc)
   animalObj.SaveLoc = fullfile(animalObj.DIR);
   animalObj.setSaveLocation;
end
animalObj.SaveLoc=fullfile(animalObj.SaveLoc,animalObj.Name);
if exist(animalObj.SaveLoc,'dir')==0
    mkdir(animalObj.SaveLoc);
    animalObj.ExtractFlag = true;
else
    animalObj.ExtractFlag = false;
end



Recordings = dir(animalObj.DIR);

Recordings=Recordings(~ismember({Recordings.name},{'.','..'}));
Recordings=Recordings(~[Recordings.isdir]);

for bb=1:numel(Recordings)
    RecFile=fullfile(Recordings(bb).folder,Recordings(bb).name);
    animalObj.addBlock(RecFile);
end

end
