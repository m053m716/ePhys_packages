function pars = Filt(varargin)
=======
%% defaults.Filt  Initialize filter parameters for bandpass filter
%
%  pars = defaults.Filt('NAME',value,...);
%
%  --------
%   INPUTS
%  --------
%  varargin    :     (Optional) 'NAME', value input argument pairs.
%
%                    -> 'FSTOP1' [def: 250 Hz] // 1st stopband frequency
%
%                    -> 'FPASS1' [def: 300 Hz] // 1st passband frequency
%
%                    -> 'FPASS2' [def: 3000 Hz] // 2nd passband frequency
%
%                    -> 'FSTOP2' [def: 3050 Hz] // 2nd stopband frequency
%
%                    -> 'ASTOP1' [def: 70 dB] // 1st stopband attenuation
%
%                    -> 'APASS' [def: 0.001 dB] // passband ripple
%
%                    -> 'ASTOP2' [def: 70 dB] // 2nd stopband attenuation
%
%                    -> 'METHOD' [def: 'ellip'] // IIR filter design method
%
%                    -> 'STIM_SUPPRESS' [def: false] // do stim suppression
%
%                    -> 'STIM_BLANK' [def: [1,3] ms] // prior and post stim
%                                                        blanking period
%
%  --------
%   OUTPUT
%  --------
%    pars      :     Parameters struct with filter parameters.
%
% By: MAECI 2018 collaboration (Federico Barban & Max Murphy)

%% DEFAULTS
FSTOP1 = 250;        % First Stopband Frequency
FPASS1 = 300;        % First Passband Frequency
FPASS2 = 3000;       % Second Passband Frequency
FSTOP2 = 3050;       % Second Stopband Frequency
ASTOP1 = 70;         % First Stopband Attenuation (dB)
APASS  = 0.001;      % Passband Ripple (dB)
ASTOP2 = 70;         % Second Stopband Attenuation (dB)
METHOD = 'ellip';    % filter type

STIM_SUPPRESS = false;  % set true to do stimulus artifact suppression
STIM_BLANK = [1 3];     % milliseconds prior and after to blank on stims
STIM_P_CH = [nan, nan]; % [probe #, channel #] for channel delivering stims

%% PARSE VARARGIN
if numel(varargin)==1
    varargin = varargin{1};
    if numel(varargin) ==1
        varargin = varargin{1};
    end
end

for iV = 1:2:length(varargin)
    eval([upper(varargin{iV}) '=varargin{iV+1};']);
end


%% INITIALIZE PARAMETERS STRUCTURE OUTPUT
pars=struct;
pars.FSTOP1 =FSTOP1;

pars.FSTOP1 = FSTOP1;      
pars.FPASS1 = FPASS1;      
pars.FPASS2 = FPASS2;    
pars.FSTOP2 = FSTOP2;      
pars.ASTOP1 = ASTOP1;         
pars.APASS  = APASS;      
pars.ASTOP2 = ASTOP2; 
pars.METHOD = METHOD;

pars.STIM_SUPPRESS = STIM_SUPPRESS;
pars.STIM_BLANK = STIM_BLANK;
pars.STIM_P_CH = STIM_P_CH;

end