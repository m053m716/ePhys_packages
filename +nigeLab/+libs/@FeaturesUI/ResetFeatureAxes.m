function ResetFeatureAxes(obj)
%% CRC_RESETFEATUREAXES Reset the feature axes with manual limits for speed

%% 3D
% Reset the manual properties of 3D axis
set(obj.Features3D,...
   'xlimmode','manual',...
   'xlim',[-obj.sdMax,obj.sdMax],...
   'ylimmode','manual',...
   'ylim',[-obj.sdMax,obj.sdMax],...
   'zlimmode','manual',...
   'zlim',[0 obj.zMax], ...
   'ztick',obj.zTickLoc,...
   'zticklabels',obj.zTickLab,...
   'alimmode','manual',...
   'alim',[0 1], ...
   'climmode','manual',...
   'clim',[0 1],...
   'View',obj.FEAT_VIEW);

%% 2D
% Reset manual properties of 2D axis
set(obj.Features2D,...
   'xlimmode','manual',...
   'xlim',[-obj.sdMax obj.sdMax],...
   'ylimmode','manual',...
   'ylim',[-obj.sdMax obj.sdMax],...
   'zlimmode','manual',...
   'zlim',[0 1], ...
   'alimmode','manual',...
   'alim',[0 1], ...
   'climmode','manual',...
   'clim',[0 1]);

obj.CountExclusions(obj.ChannelSelector.Channel);


end